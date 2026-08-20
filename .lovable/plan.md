# Restore Swift statistics data

## Confirmed cause

- The activity history table currently has no rows, so the Swift statistics query returns an empty history.
- `StatsView` only overlays live HealthKit totals after a database history row already exists. With an empty history, even valid live HealthKit values are discarded and every statistic remains at zero/no data.
- The iOS app submits activity with source `healthkit`, but the current backend write rules only permit signed-in users to create or update `manual` activity rows.
- The Swift upsert targets `(user_id, day)`, while the database uniqueness rule is `(user_id, day, source)`, so the write conflict target does not match the database.
- HealthKit capability is not declared in the app entitlements/project configuration.
- Both the HealthKit write and history read suppress errors, which makes these failures appear as an empty statistics page.

## Implementation

1. **Enable native HealthKit access**
   - Add the HealthKit capability to the iOS target and entitlements while preserving the existing permission text and onboarding flow.

2. **Make HealthKit synchronization persist securely**
   - Update the authenticated activity write rules so a user can write only their own `healthkit` activity row in addition to their existing manual row.
   - Keep read access user-scoped and retain all existing validation constraints.
   - Change the Swift upsert conflict key to `(user_id, day, source)`.

3. **Correct activity history loading**
   - Fetch the newest requested activity days rather than applying an ascending limit that can return the oldest rows.
   - Aggregate rows by day and fill missing dates with zeroes before returning data to statistics.
   - Preserve today’s HealthKit values as the live source of truth while its backend write finishes.

4. **Make statistics work before the first persisted row**
   - Build the seven-day and longer reporting windows independently of whether history already contains a row.
   - Overlay today’s live steps, distance, calories, and exercise minutes onto today’s generated entry.
   - Recalculate earned screen time, goal completion, active days, best day, trends, and forecasts from that unified history without changing the interface.

5. **Expose and recover from sync failures**
   - Stop silently swallowing activity read/write failures.
   - Add internal loading/error state and retry synchronization when the statistics page appears, while keeping the current visual design unchanged.

## Verification

- Confirm HealthKit authorization returns movement totals on a real device.
- Confirm one signed-in user can insert and update only their own daily `healthkit` row, while another user cannot access it.
- Confirm reopening Statistics shows today immediately and historical days from the backend.
- Verify all cards and charts use the same daily totals as Home, including earned screen time and daily-goal completion.
