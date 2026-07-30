"""End-to-end: a child's access to color themes and the AI coach must follow the
parent's PRO Family subscription.

Run:  python3 e2e/test_child_pro_family.py
Exit code 0 = all scenarios passed.
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from playwright.async_api import async_playwright  # noqa: E402

from supabase_stub import (  # noqa: E402
    BASE_URL,
    child_row,
    install_backend_stub,
    profile_row,
    settings_row,
    sign_in,
)

SCREENSHOTS = Path(__file__).parent / "screenshots"
CHILD_LOCK_COPY = "Your parent needs to upgrade to SetGoals PRO Family"
INDIVIDUAL_LOCK_COPY = "Unlock with PRO"
THEME_UNLOCKED_COPY = "Recolor the whole app"
COACH_LOCKED_TITLE = "AI Coach is a PRO feature"

failures: list[str] = []
checks = 0


def check(label: str, condition: bool, detail: str = ""):
    global checks
    checks += 1
    print(("  PASS  " if condition else "  FAIL  ") + label + (f"  [{detail}]" if detail and not condition else ""))
    if not condition:
        failures.append(label)


async def open_as(playwright, *, role, family_pro, own_pro=False, theme="rose"):
    browser = await playwright.chromium.launch(headless=True)
    context = await browser.new_context(viewport={"width": 1280, "height": 1800})
    linked = child_row() if role == "child" else None
    await install_backend_stub(
        context,
        profile=profile_row(role),
        settings=settings_row(is_pro=own_pro, theme_color=theme),
        children=[],
        linked_child=linked,
        family_pro=family_pro,
    )
    page = await context.new_page()
    await sign_in(page)
    return browser, page


async def wait_for_any(page, needles, selector=None, timeout_ms=15000):
    """The app shows a splash screen for ~2.5s, so poll until the page settles."""
    deadline = timeout_ms
    while deadline > 0:
        body = await page.inner_text("body")
        if any(n in body for n in needles):
            return body
        if selector and await page.locator(selector).count():
            return body
        await page.wait_for_timeout(250)
        deadline -= 250
    return await page.inner_text("body")


async def settings_theme_state(page) -> str:
    """Returns 'unlocked' | 'locked-child' | 'locked-individual' | 'unknown'."""
    await page.goto(f"{BASE_URL}/settings", wait_until="domcontentloaded")
    body = await wait_for_any(page, [THEME_UNLOCKED_COPY, CHILD_LOCK_COPY, INDIVIDUAL_LOCK_COPY])
    if THEME_UNLOCKED_COPY in body:
        return "unlocked"
    if CHILD_LOCK_COPY in body:
        return "locked-child"
    if INDIVIDUAL_LOCK_COPY in body:
        return "locked-individual"
    return "unknown"


async def coach_state(page) -> str:
    await page.goto(f"{BASE_URL}/coach", wait_until="domcontentloaded")
    body = await wait_for_any(page, [COACH_LOCKED_TITLE], selector="#coach-input")
    if COACH_LOCKED_TITLE in body:
        return "locked-child" if CHILD_LOCK_COPY in body else "locked-individual"
    return "unlocked" if await page.locator("#coach-input").count() else "unknown"


async def main():
    SCREENSHOTS.mkdir(exist_ok=True)
    async with async_playwright() as pw:
        # 1. Child, parent has an ACTIVE PRO Family plan -> everything unlocked.
        print("\n[1] child + active PRO Family")
        browser, page = await open_as(
            pw, role="child", family_pro={"active": True, "cancelling": False, "ends_at": None}
        )
        state = await settings_theme_state(page)
        check("theme picker unlocked for child on active family plan", state == "unlocked", detail=str(state"unlocked"))
        await page.screenshot(path=str(SCREENSHOTS / "1_child_active_settings.png"))
        state = await coach_state(page)
        check("AI coach usable for child on active family plan", state == "unlocked", detail=str(state"unlocked"))
        await page.screenshot(path=str(SCREENSHOTS / "1_child_active_coach.png"))
        await browser.close()

        # 2. Child, parent has NO family plan -> locked with child-specific copy.
        print("\n[2] child + no PRO Family")
        browser, page = await open_as(
            pw, role="child", family_pro={"active": False, "cancelling": False, "ends_at": None}
        )
        state = await settings_theme_state(page)
        check("theme picker locked for child without family plan", state == "locked-child", detail=str(state"locked-child"))
        await page.screenshot(path=str(SCREENSHOTS / "2_child_locked_settings.png"))
        state = await coach_state(page)
        check("AI coach locked for child without family plan", state == "locked-child", detail=str(state"locked-child"))
        await page.screenshot(path=str(SCREENSHOTS / "2_child_locked_coach.png"))
        await browser.close()

        # 3. Child, parent cancelled but the period has not ended -> still unlocked.
        print("\n[3] child + cancelled-but-active PRO Family")
        browser, page = await open_as(
            pw,
            role="child",
            family_pro={"active": True, "cancelling": True, "ends_at": "2099-01-01T00:00:00Z"},
        )
        check("theme picker still unlocked until period end", await settings_theme_state(page) == "unlocked", detail=str(await settings_theme_state(page)"unlocked"))
        check("AI coach still usable until period end", await coach_state(page) == "unlocked", detail=str(await coach_state(page)"unlocked"))
        await browser.close()

        # 4. Child, own is_pro row is true but no family plan -> must stay locked
        #    (a child can never self-grant PRO).
        print("\n[4] child + stale own is_pro, no family plan")
        browser, page = await open_as(
            pw,
            role="child",
            own_pro=True,
            family_pro={"active": False, "cancelling": False, "ends_at": None},
        )
        check("child cannot self-grant theme access", await settings_theme_state(page) == "locked-child", detail=str(await settings_theme_state(page)"locked-child"))
        check("child cannot self-grant coach access", await coach_state(page) == "locked-child", detail=str(await coach_state(page)"locked-child"))
        await browser.close()

        # 5. Individual (non-child) without PRO -> generic upgrade copy, not the parent copy.
        print("\n[5] individual without PRO")
        browser, page = await open_as(
            pw, role="individual", family_pro={"active": False, "cancelling": False, "ends_at": None}
        )
        check("individual sees generic PRO upsell", await settings_theme_state(page) == "locked-individual", detail=str(await settings_theme_state(page)"locked-individual"))
        check("individual coach shows generic PRO lock", await coach_state(page) == "locked-individual", detail=str(await coach_state(page)"locked-individual"))
        await browser.close()

    print(f"\n{checks - len(failures)}/{checks} checks passed")
    if failures:
        for f in failures:
            print("FAILED:", f)
        sys.exit(1)


asyncio.run(main())
