# PRO screen-time rollover: findings and proposed fix

## Findings (nothing changed yet)

**The backend never calculates rollover.** There's no database function, scheduled job (pg_cron isn't installed) or API endpoint that computes it. Rollover is worked out on each device every time the Home screen draws, and it is never saved anywhere.

**`bonus_min` contains no rollover at all.** Only three things write to it, and all three add minutes to today's row in `earned_balances`:
- Parent gifts: `src/lib/children.functions.ts:238-255`, plus Swift `SupabaseAPI+Parent.swift:151-164`
- Approved task rewards: `src/lib/tasks.functions.ts:70-87`
- Your own bonus: Swift `SupabaseAPI+Extra.swift:192-210` (`addOwnBonusMinutes`)

The only thing that reads `bonus_min` in the database is `refresh_daily_stats`, which copies it into `user_daily_stats`.

**`SupabaseAPI.todayBalance()`** (`SupabaseService.swift:148`) only reads the row:
```swift
supabase.from("earned_balances").select()
  .eq("user_id", value: uid).eq("day", value: todayKey).single()
```

**Where rollover is calculated (the web and iPhone versions disagree):**
- Web, `src/lib/screentime.ts:45`: `min(earnedMinFromSteps(yesterdaySteps), cap)`. This is **yesterday's earned** minutes.
- iPhone, `HomeView.swift:25-29`: `capMin - min(capMin, earnedMin(yesterdaySteps))`. This is **the part of yesterday's cap that was not earned**. It's the opposite of the web, and it's largest when yesterday had the fewest steps.
- Neither version uses yesterday's actual remaining time.

**How yesterday's used time is measured:** it isn't. `consumed_min` is never written by any app code. The iPhone measures usage only in the app-group ledger (`ScreenTimeBudget.usedMin`, through the Screen Time monitor), and that resets at midnight and is never uploaded.

**Which timezone defines the reset:** the device's local midnight (`localDayKey` on the web, `TimeZone.current` on iPhone). The database's own `CURRENT_DATE` (UTC) is used only by the stats and leaderboard functions.

**Whether it's calculated once per day:** no. It's recalculated on every render. The on/off setting lives only on the device (localStorage `sg.st.pro.v1` on the web, UserDefaults `st.rollover` on iPhone), so it's different on each device.

## Proposed fix (needs your approval)
1. The iPhone uploads the minutes it measures to `consumed_min` for each day.
2. A secured server function computes rollover once per user per local day, using yesterday's earned + bonus - consumed, capped at today's cap. It's only granted when PRO is active and rollover is on.
3. Store the result in a new `rollover_min` column, kept separate from `bonus_min`. A unique per-day write makes it happen only once.
4. Save the rollover on/off setting in `user_settings` instead of on the device.
5. Web and iPhone Home both read the saved rollover value and stop calculating it themselves.
