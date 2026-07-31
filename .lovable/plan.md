Based on a full audit of the TanStack Start app, Lovable Cloud backend, StoreKit integration, e2e tests, and security posture, here is what remains before a real App Store launch.

## Current state
- Build, typecheck, and e2e tests pass.
- All core features exist: auth, real step tracking, screen-time math, parent-child linking, challenges, badges, AI coach, map, profile, and settings.
- Backend is on Lovable Cloud with RLS on every user table, service-role grants, and GDPR tables (account_deletion_requests, data_export_requests).
- Apple StoreKit is the chosen payment path (Stripe was bypassed in UI). JWS verification, server notifications, and entitlement sync are implemented.
- E2E tests verify that children inherit PRO Family access correctly.

## Launch-critical gaps

### 1. App Store Connect + StoreKit go-live
These are mostly outside the codebase but block all real revenue:

- Set `APPLE_BUNDLE_ID` secret in Lovable. The JWS verifier checks `bundleId` only when this is set; without it, transactions from other apps could theoretically be accepted (Apple's chain still pins the root, so the risk is low, but bundle ID is the final app-level guard).
- Create the exact App Store Connect product IDs used in the app:
  - `app.setgoals.pro.monthly`
  - `app.setgoals.pro.yearly`
  - `app.setgoals.pro.family.monthly`
  - `app.setgoals.pro.family.yearly`
- Sign the Paid Apps Agreement and complete tax/banking in App Store Connect.
- Configure App Store Server Notifications V2 to POST to the live URL: `https://<your-domain>/api/public/payments/apple-notifications`.
- Configure the native app shell (Capacitor or WKWebView) to expose the StoreKit bridge so `purchasePlan()` and `restorePurchases()` can actually call `window.Capacitor.Plugins` or `webkit.messageHandlers.storekit`. In a plain browser, purchases are unavailable.
- The current Apple root CA is fetched from Apple at runtime. Cache it or bundle it as an environment variable to reduce cold-start failures and avoid network dependency on every notification/verification.

### 2. Leaderboards do not match the stated requirements
The user previously asked for daily-only leaderboards split into Local, National, and Friends.

- The current `public.leaderboard(_period text)` returns a single global list with `daily/weekly/monthly/alltime` periods.
- The UI still shows weekly/monthly/alltime tabs and a 50-row global list.
- Local board needs region grouping (e.g., "Stockholms Län") from geocoding data.
- National board needs country grouping.
- Friends board needs to rank the user's friends by today's steps.
- This requires either new DB columns (`region`, `country` on `profiles` or `user_settings`) or a new `leaderboards` RPC that accepts a `scope` parameter.

### 3. Badges and friends are stored in localStorage only

- `Badges.tsx` saves earned badges to `localStorage`. They do not persist across devices, reinstalls, or child account switches.
- The friends list (`src/lib/friends.ts`) is also localStorage. Friends do not sync across devices and cannot be restored after sign-in.
- For launch, move badges to a `user_badges` table and friends to a `friendships` table (both with RLS). This is required for any multi-device/child/family experience.

### 4. Native health-data bridge

- `src/lib/health-bridge.ts` is wired to Capacitor HealthKit/Health Connect plugins. It will only work inside a native shell. In a browser, the request returns "unavailable". This is expected, but the launch plan must include the native shell build.

### 5. App Store listing requirements

- App Store privacy policy URL is required. The app currently does not have `/privacy` or `/terms` routes.
- App Store privacy manifest (`PrivacyInfo.xcprivacy`) must be added for the native iOS project because the app collects health/fitness data, precise location, and identifiers.
- Screenshots, app icon, and promotional text must be produced for every required iPhone/iPad size.
- The app name in App Store Connect must match `SetGoals` and the bundle ID must match `APPLE_BUNDLE_ID`.

### 6. Security linter warnings

- The Supabase linter reports 5 SECURITY DEFINER functions executable by authenticated users. These appear to be intentional (`has_role`, `is_parent_of`, `leaderboard`, `family_today`, `username_available`, `parent_family_pro`, etc.), but they need to be explicitly reviewed and documented in a security memory note so future scans do not flag them as regressions.

### 7. Hardcoded English strings

- The challenges leaderboard footer still shows `Live updates · Verified step data only` directly in English instead of using the i18n translation system.
- A scan of all routes should be done to catch any remaining hardcoded strings.

### 8. Stripe is still configured in the backend

- Even though the UI uses StoreKit, the Payments tab still shows a Stripe go-live flow and Stripe secrets are present. This is not a launch blocker, but it can confuse billing. If StoreKit is the only revenue path, remove or hide Stripe setup to avoid duplicate/invalid go-live attempts.

## Recommended execution order

### Phase 1 — Data persistence (must be done before any real users)
1. Create `public.user_badges` table with RLS + GRANTs and migrate badge logic to read/write from DB.
2. Create `public.friendships` table with RLS + GRANTs and replace localStorage friends with DB-backed friends.
3. Update `Badges.tsx`, `ProfileBadgeStrip.tsx`, `FriendsCard.tsx`, `src/lib/friends.ts`, and `src/lib/friends.functions.ts` to use the new tables.

### Phase 2 — Leaderboards
4. Add `region` and `country` columns to `profiles` (populated during onboarding or first location use).
5. Replace `public.leaderboard(_period)` with a new `public.leaderboard(scope text, day date)` function that returns top 10 for `local`, `national`, and `friends` scopes.
6. Update `src/routes/challenges.tsx` to show only daily leaderboards with Local / National / Friends tabs.
7. Update the Home leaderboard tile to use real friends ranking from the DB.

### Phase 3 — StoreKit production hardening
8. Set `APPLE_BUNDLE_ID` secret.
9. Bundle or cache the Apple Root CA certificate instead of fetching it every cold start.
10. Add idempotency checks to the App Store notifications handler so duplicate notifications cannot reset subscription dates incorrectly.
11. Add a small admin/status server function to confirm the current environment and subscription state for debugging.

### Phase 4 — Native shell and App Store
12. Build the iOS native shell (Capacitor or WKWebView) with the StoreKit and HealthKit bridges.
13. Add `/privacy` and `/terms` routes with the actual policies.
14. Create App Store Connect products, upload the build, and configure App Store Server Notifications.
15. Add a privacy manifest to the iOS project.
16. Produce App Store screenshots and metadata.

### Phase 5 — Polish
17. Move the remaining hardcoded English strings into `src/lib/i18n.tsx`.
18. Review and document the intentional security definer functions in security memory.
19. Run a final security scan and end-to-end test pass before submission.

## Out of scope for this plan
- Rewriting the AI coach or map features (they are already functional).
- Changing the visual design direction (the sage theme and PRO color theming are established).
- Adding new challenge types beyond the existing 17.

## Immediate next steps
I recommend starting with Phase 1 (badges + friends persistence) and Phase 2 (leaderboards), because those are the biggest functional mismatches with the stated requirements and they affect the launch user experience. Then we move to StoreKit production hardening and the native/iOS work.