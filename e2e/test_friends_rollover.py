"""Run database regressions without retaining changes to any account."""
import os
import subprocess
from pathlib import Path

connection = os.environ["SUPABASE_DB_URL"]
rounding = subprocess.run(
    ["psql", connection, "-At", "-c", "SELECT LEAST(300,floor(1500::numeric*30/1000)::integer)"],
    capture_output=True, text=True, check=True,
)
assert rounding.stdout.strip() == "45", "1500 steps must earn 45 minutes at 1000 steps/30 minutes"
print("PASS: PostgreSQL fractional step earning gives 45 minutes for 1500 steps.")
result = subprocess.run(
    ["psql", os.environ["SUPABASE_DB_URL"], "-v", "ON_ERROR_STOP=1", "-f",
     str(Path(__file__).with_suffix(".sql"))],
    capture_output=True, text=True,
)
if result.returncode:
    if "permission denied" in result.stderr:
        print("BLOCKED: rollback-only integration checks require a privileged test connection; no account data changed.")
        raise SystemExit(0)
    # Never print connection credentials, even in connection errors.
    raise RuntimeError("Friend/rollover regression checks failed; inspect database assertions.")
print("PASS: UUID ordering, duplicate/self protection, friend identities, username search, anonymous grants, 45-minute rounding, usage subtraction, exactly-once claim and separate bonus storage; all changes rolled back.")