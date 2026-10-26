"""Run database regressions without retaining changes to any account."""
import os
import subprocess
from pathlib import Path

result = subprocess.run(
    ["psql", os.environ["SUPABASE_DB_URL"], "-v", "ON_ERROR_STOP=1", "-f",
     str(Path(__file__).with_suffix(".sql"))],
    capture_output=True, text=True,
)
if result.returncode:
    # Never print connection credentials, even in connection errors.
    raise RuntimeError("Friend/rollover regression checks failed; inspect database assertions.")
print("PASS: UUID ordering, duplicate/self protection, friend identities, username search, anonymous grants, 45-minute rounding, usage subtraction, exactly-once claim and separate bonus storage; all changes rolled back.")