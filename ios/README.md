# SetGoals — SwiftUI port

Native iOS implementation of the SetGoals web app. The design is a 1:1
translation of the web design tokens, not a redesign: the palette here is the
exact sRGB conversion of the oklch values in `src/styles.css`, and spacing,
radii, type sizes, shadows and animation curves mirror the Tailwind classes
used by the React components.

> This project cannot be built or previewed inside Lovable. Open it in Xcode.

## Getting started

```bash
brew install xcodegen        # once
cd ios && xcodegen generate  # creates SetGoals.xcodeproj
open SetGoals.xcodeproj
```

Swift Package dependency (`supabase-swift`) resolves on first build.

### Signing and capabilities

1. Set your team + a unique bundle id on the `SetGoals` target.
2. **HealthKit** — add the capability (entitlement is auto-added by Xcode).
3. **Family Controls** — requires a
   [distribution entitlement request](https://developer.apple.com/contact/request/family-controls-distribution)
   from Apple. Until it is granted, `AuthorizationCenter.requestAuthorization`
   fails on device and the whole framework is unavailable in the Simulator.
4. Run on a **physical device**. HealthKit returns no data and Screen Time
   shields do nothing in the Simulator.

### Fonts

The web app uses **Albert Sans**. Download the family, drop the `.ttf` files
into `SetGoals/Resources/Fonts/`, and add them under `UIAppFonts` in
`Info.plist`. `F.sans()` falls back to the system font when they are absent,
which is the one place the UI will not match the web exactly.

## Structure

```
SetGoals/
  App/SetGoalsApp.swift        entry point, splash gate, auth routing
  Design/Theme.swift           palette (7 PRO themes) + semantic tokens + radii
  Design/Typography.swift      Tailwind type scale
  Design/Components.swift      CardSurface, PrimaryButton, field style, StatTile, rise()
  Design/ProgressRing.swift    port of ProgressRing.tsx
  Features/Shell/AppShell.swift  AppShell, BottomNav, PageHeader
  Features/Splash/             Splash.tsx
  Features/Auth/               auth.tsx (sign in / up / forgot / join by code)
  Features/Home/               index.tsx (ring, stats, family, leaderboard tile)
  Features/Profile/            profile.tsx + ProfileAura.tsx
  Services/SupabaseService.swift   same project, same tables, same RPCs
  Services/HealthKitService.swift  steps/distance/energy + hourly buckets
  Services/ScreenTimeService.swift FamilyControls shields + DeviceActivity
  i18n/Strings.swift           EN/SV strings for the ported screens
```

## Backend

Talks to the same Supabase project as the web app with the publishable anon
key; RLS enforces access exactly as before. Reused server-side logic:
`family_today()`, `leaderboard(_scope)`, `username_available(_username)`,
plus the `profiles`, `user_settings`, `activity_steps`, `earned_balances`,
`streaks` tables.

HealthKit totals are upserted into `activity_steps` with `source = 'healthkit'`,
so leaderboards, badges, streaks and earned screen time keep working unchanged
and stay consistent between the web app and the iOS app.

## Screen Time

`ScreenTimeService` shields every category marked `earnedOnly` when the
remaining balance reaches zero and lifts the shield as soon as steps earn more
time. `HomeView` drives this via `onChange(of: remainingMin)`. Parent-managed
child devices authorize with `.child` so restrictions cannot be removed
locally.

## Still to port

`challenges`, `coach`, `map`, `stats`, `settings`, `parent`, `onboarding`,
badges, tasks & rewards, friends, PRO/Stripe. They currently render
`PlaceholderView`, which keeps the exact shell/header/spacing so each port
drops straight in.
