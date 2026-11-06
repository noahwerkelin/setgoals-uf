# SetGoals Launch Checklist

Things to verify before launching the app publicly. Items marked **[device]** need a real iPhone — they cannot be checked in the simulator or in code review.

## Privacy & legal

- [ ] Privacy Policy, Terms of Use, Subscription & Payment Terms and Community Guidelines are the final versions in the app (Settings → Legal & Privacy) and match the published website copies.
- [ ] Signup requires accepting Terms & Privacy, and the acceptance timestamp is stored.
- [ ] HealthKit purpose text (`NSHealthShareUsageDescription`) and Screen Time / Family Controls purpose text are written for review — Apple reads these closely.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) declares HealthKit, UserDefaults (app group) and any required-reason APIs.
- [ ] Account deletion works end to end: parent deletion cascades to children, child deletion only affects the child. **[device]**
- [ ] Location is only requested when the map feature is used; the app still works when denied.
- [ ] Anonymous leaderboard mode hides the user from others' lists.

## Apple entitlements (start early — these need Apple's approval)

- [ ] **Family Controls (Distribution)** entitlement approved by Apple for the App Store build — without it Screen Time features only work in development builds.
- [ ] HealthKit entitlement enabled on the App Store provisioning profile.
- [ ] Sign in with Apple / Google are removed — make sure no leftover entitlements or review notes reference them.
- [ ] App Store age rating reflects the Screen Time / parental controls features.

## Payments

- [ ] Stripe is in **live mode** (live keys, live prices for PRO and PRO Family).
- [ ] Test a real purchase, a restore, and a cancellation: PRO features must stay active until the billing date, then turn off. **[device]**
- [ ] PRO Family correctly extends PRO to children and revokes it on cancellation.
- [ ] The admin-granted permanent PRO account still shows PRO after a subscription sync.

## Screen Time behavior **[device]**

- [ ] Earned minutes from steps unlock the shielded apps; reaching the cap locks them again.
- [ ] Weekend 2× multiplier doubles earning on Saturday/Sunday (PRO).
- [ ] Split weekday/weekend caps override the standard daily cap (PRO).
- [ ] Challenge rewards grant real Screen Time through the native system.
- [ ] SetGoals itself is never locked.
- [ ] Daily reset at midnight: earned time, gifted time and rollover all behave correctly across app restarts and background/foreground.

## Data & accounts

- [ ] Child join-with-code flow works for a fresh code (parent creates → child redeems → child can log in).
- [ ] Friend requests require acceptance; removal works both directions.
- [ ] Usernames: uniqueness enforced, availability check works during signup and child creation.
- [ ] Streaks, badges and statistics sync from real movement data on a fresh install.
- [ ] Leaderboards show the daily top 10 and the user's own rank.

## Performance & feel

- [ ] Cold start to usable Home screen feels fast (splash dismisses as soon as data is ready).
- [ ] Challenges, stats, friends and family data are preloaded at entry — no loading spinners on first visit to each tab.
- [ ] Scrolling is smooth on the oldest device you plan to support. **[device]**
- [ ] Dark mode, light mode and system default all look right on every tab. **[device]**

## Operations

- [ ] Auth email templates (signup, recovery, etc.) send from notify.setgoals.se and land in inbox, not spam.
- [ ] The health endpoint (`/api/public/health`) returns `ok` on the published URL.
- [ ] Error reporting is wired so crashes/failures reach you after launch.
- [ ] App icon, splash and App Store screenshots are final.
