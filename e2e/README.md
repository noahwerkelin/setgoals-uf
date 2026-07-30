# End-to-end tests

Playwright (Python) tests that drive the real app on `http://localhost:8080`.
Backend calls are intercepted and answered with fixtures (`supabase_stub.py`),
so account states like "child linked to a parent with an active PRO Family
plan" can be exercised without provisioning real accounts.

Run:

```bash
python3 e2e/test_child_pro_family.py
```

Exit code `0` means every check passed; screenshots land in `e2e/screenshots/`.

## test_child_pro_family.py

Verifies that a child's access to **color themes** (Settings) and the
**AI coach** follows the parent's PRO Family subscription:

| Scenario | Theme picker | AI coach |
| --- | --- | --- |
| Child, parent PRO Family active | unlocked | unlocked |
| Child, no parent PRO Family | locked + "your parent needs PRO Family" | same |
| Child, parent cancelled but period not ended | unlocked | unlocked |
| Child with stale own `is_pro`, no family plan | locked (no self-grant) | locked |
| Individual without PRO | locked + generic PRO upsell | generic PRO lock |
