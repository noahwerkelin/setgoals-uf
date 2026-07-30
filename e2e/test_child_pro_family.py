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
    row = page.locator("[data-testid=theme-row]")
    await row.wait_for(state="visible", timeout=20000)
    # The row re-renders once the inherited PRO Family entitlement resolves.
    await page.wait_for_timeout(1200)
    text = await row.inner_text()
    if await row.get_attribute("data-locked") == "false":
        return "unlocked" if THEME_UNLOCKED_COPY in text else "unknown"
    if CHILD_LOCK_COPY in text:
        return "locked-child"
    if INDIVIDUAL_LOCK_COPY in text:
        return "locked-individual"
    return "unknown"


async def coach_state(page) -> str:
    await page.goto(f"{BASE_URL}/coach", wait_until="domcontentloaded")
    await wait_for_any(page, [COACH_LOCKED_TITLE], selector="#coach-input")
    await page.wait_for_timeout(1200)
    if await page.locator("#coach-input").count():
        return "unlocked"
    if await page.locator("[data-testid=coach-lock-child]").count():
        return "locked-child"
    if COACH_LOCKED_TITLE in await page.inner_text("body"):
        return "locked-individual"
    return "unknown"


async def scenario(pw, name, *, role, family_pro, own_pro, expect_settings, expect_coach, shot=None):
    print(f"\n[{name}]")
    browser, page = await open_as(pw, role=role, family_pro=family_pro, own_pro=own_pro)
    s = await settings_theme_state(page)
    check(f"{name}: theme picker -> {expect_settings}", s == expect_settings, detail=s)
    if shot:
        await page.screenshot(path=str(SCREENSHOTS / f"{shot}_settings.png"))
    c = await coach_state(page)
    check(f"{name}: AI coach -> {expect_coach}", c == expect_coach, detail=c)
    if shot:
        await page.screenshot(path=str(SCREENSHOTS / f"{shot}_coach.png"))
    await browser.close()


async def main():
    SCREENSHOTS.mkdir(exist_ok=True)
    async with async_playwright() as pw:
        # Child, parent has an ACTIVE PRO Family plan -> everything unlocked.
        await scenario(
            pw,
            "child + active PRO Family",
            role="child",
            family_pro={"active": True, "cancelling": False, "ends_at": None},
            own_pro=False,
            expect_settings="unlocked",
            expect_coach="unlocked",
            shot="1_child_active",
        )

        # Child, parent has NO family plan -> locked with child-specific copy.
        await scenario(
            pw,
            "child + no PRO Family",
            role="child",
            family_pro={"active": False, "cancelling": False, "ends_at": None},
            own_pro=False,
            expect_settings="locked-child",
            expect_coach="locked-child",
            shot="2_child_locked",
        )

        # Child, parent cancelled but the period has not ended -> still unlocked.
        await scenario(
            pw,
            "child + cancelled-but-active PRO Family",
            role="child",
            family_pro={"active": True, "cancelling": True, "ends_at": "2099-01-01T00:00:00Z"},
            own_pro=False,
            expect_settings="unlocked",
            expect_coach="unlocked",
        )

        # Child whose own is_pro row is true but with no family plan must stay
        # locked -- a child can never self-grant PRO.
        await scenario(
            pw,
            "child + stale own is_pro, no family plan",
            role="child",
            family_pro={"active": False, "cancelling": False, "ends_at": None},
            own_pro=True,
            expect_settings="locked-child",
            expect_coach="locked-child",
        )

        # Individual (non-child) without PRO -> generic upsell, not the parent copy.
        await scenario(
            pw,
            "individual without PRO",
            role="individual",
            family_pro={"active": False, "cancelling": False, "ends_at": None},
            own_pro=False,
            expect_settings="locked-individual",
            expect_coach="locked-individual",
        )

    print(f"\n{checks - len(failures)}/{checks} checks passed")
    if failures:
        for f in failures:
            print("FAILED:", f)
        sys.exit(1)


asyncio.run(main())
