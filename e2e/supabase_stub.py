"""Shared helpers for the SetGoals end-to-end tests.

The app talks to the backend through the Supabase JS client, so these tests
intercept those HTTP calls and serve deterministic fixtures. That lets us drive
the *real* UI (routing, providers, components) for account states that would
otherwise require provisioning parents, children and subscriptions.
"""

import json
import os
import re
import time
from pathlib import Path

BASE_URL = os.environ.get("E2E_BASE_URL", "http://localhost:8080")
ROOT = Path(__file__).resolve().parents[1]


def _env(name: str) -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith(f"{name}="):
            return line.split("=", 1)[1].strip().strip('"')
    raise RuntimeError(f"{name} missing from .env")


SUPABASE_URL = _env("VITE_SUPABASE_URL").rstrip("/")
PROJECT_REF = SUPABASE_URL.split("//", 1)[1].split(".", 1)[0]
STORAGE_KEY = f"sb-{PROJECT_REF}-auth-token"

USER_ID = "11111111-1111-4111-8111-111111111111"
PARENT_ID = "22222222-2222-4222-8222-222222222222"
CHILD_ROW_ID = "33333333-3333-4333-8333-333333333333"


def fake_session(email: str = "kid@example.com") -> dict:
    """A session object shaped like the one supabase-js persists in localStorage."""
    expires_at = int(time.time()) + 60 * 60 * 24
    return {
        "access_token": "e2e-fake-access-token",
        "refresh_token": "e2e-fake-refresh-token",
        "token_type": "bearer",
        "expires_in": 86400,
        "expires_at": expires_at,
        "user": {
            "id": USER_ID,
            "aud": "authenticated",
            "role": "authenticated",
            "email": email,
            "app_metadata": {"provider": "email"},
            "user_metadata": {},
            "created_at": "2026-01-01T00:00:00Z",
        },
    }


def child_row(avatar: str = "🌱") -> dict:
    return {
        "id": CHILD_ROW_ID,
        "parent_id": PARENT_ID,
        "name": "Elsa",
        "username": "elsa",
        "birthday": "2015-04-02",
        "avatar": avatar,
        "daily_goal": 8000,
        "code": "ABCD-EFGH",
        "steps_per_30": 1000,
        "daily_cap_hours": 3,
        "bedtime": "21:00",
        "auth_user_id": USER_ID,
        "invitation_status": "connected",
        "invitation_expires_at": None,
    }


def settings_row(**over) -> dict:
    row = {
        "user_id": USER_ID,
        "steps_per_30": 1000,
        "daily_cap_hours": 3,
        "daily_goal": 8000,
        "healthkit_connected": False,
        "googlefit_connected": False,
        "push_on": True,
        "anonymous_leaderboard": False,
        "share_location": "while_using",
        "units": "metric",
        "is_pro": False,
        "pro_since": None,
        "pro_plan": "monthly",
        "pro_auto_renew": True,
        "pro_expires_at": None,
        "pro_payment_method": "",
        "theme_color": "sage",
    }
    row.update(over)
    return row


def profile_row(role: str = "child") -> dict:
    return {
        "id": USER_ID,
        "role": role,
        "display_name": "Elsa",
        "username": "elsa",
        "email": "kid@example.com",
        "avatar_url": None,
    }


async def install_backend_stub(context, *, profile, settings, children, linked_child, family_pro):
    """Route every Supabase REST/RPC call to in-memory fixtures.

    `family_pro` mirrors the `parent_family_pro_status()` RPC:
        {"active": bool, "cancelling": bool, "ends_at": str | None}
    """

    async def handle(route):
        request = route.request
        url = request.url
        path = url.split(SUPABASE_URL, 1)[-1]

        def ok(body):
            return route.fulfill(
                status=200,
                content_type="application/json",
                headers={"access-control-allow-origin": "*"},
                body=json.dumps(body),
            )

        if request.method == "OPTIONS":
            return await route.fulfill(
                status=204,
                headers={
                    "access-control-allow-origin": "*",
                    "access-control-allow-headers": "*",
                    "access-control-allow-methods": "*",
                },
            )

        if "/auth/v1/" in path:
            if "/user" in path:
                return await ok(fake_session()["user"])
            return await ok(fake_session())

        if "/rest/v1/rpc/parent_family_pro_status" in path:
            return await ok([family_pro])
        if "/rest/v1/rpc/" in path:
            return await ok([])

        if "/rest/v1/profiles" in path:
            return await ok(profile)
        if "/rest/v1/user_settings" in path:
            return await ok(settings)
        if "/rest/v1/streaks" in path:
            return await ok({"user_id": USER_ID, "count": 3, "best": 7, "last_goal_met_date": None})
        if "/rest/v1/children" in path:
            # maybeSingle() on the linked-child lookup asks for a single object.
            if "auth_user_id" in path:
                return await ok(linked_child)
            return await ok(children)

        return await ok([])

    await context.route(re.compile(re.escape(SUPABASE_URL) + r".*"), handle)


async def sign_in(page, session=None):
    """Seed the persisted Supabase session so the app boots authenticated."""
    await page.goto(BASE_URL, wait_until="domcontentloaded")
    await page.evaluate(
        "([k, v]) => window.localStorage.setItem(k, v)",
        [STORAGE_KEY, json.dumps(session or fake_session())],
    )
