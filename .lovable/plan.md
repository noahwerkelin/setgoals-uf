## Production Backend Build

### Database schema (one migration)

Tables in `public` with RLS + GRANTs:

- `profiles` — id (FK auth.users), username (unique), display_name, avatar_url, role (`individual`|`parent`|`child`), email, birthday, created_at, updated_at. Auto-created via `handle_new_user` trigger on `auth.users` insert.
- `user_settings` — user_id PK, steps_per_30, daily_cap_hours, units, push_on, anonymous_leaderboard, share_location, theme_color, is_pro, pro_plan, pro_auto_renew, pro_since, healthkit_connected, googlefit_connected.
- `children` — id, parent_id (FK profiles), name, birthday, avatar, daily_goal, code (unique), steps_per_30, daily_cap_hours.
- `activity_steps` — id, user_id, day (date), steps, distance_km, calories, source (`api`|`manual`|`healthkit`|`healthconnect`), updated_at. UNIQUE (user_id, day, source).
- `earned_balances` — user_id PK, earned_min_today, day, updated_at. Refreshed by trigger on `activity_steps`.
- `restriction_settings` — user_id, app_bundle_id / category_id, label, kind, created_at — preferences only (actual OS-level shielding is native).
- `streaks` — user_id PK, count, best, last_goal_met_date.
- `user_roles` — separate table with `app_role` enum + `has_role()` SECURITY DEFINER (per platform rules).
- `data_export_requests`, `account_deletion_requests` — for GDPR.

Views:
- `leaderboard_daily`, `leaderboard_weekly`, `leaderboard_monthly`, `leaderboard_alltime` — sum verified steps per user, joined with profile display fields, respecting `anonymous_leaderboard`. Realtime via `ALTER PUBLICATION supabase_realtime ADD TABLE activity_steps`.

### Auth
- Email + password (no auto-confirm in default Cloud settings — keep that; verification link works).
- Configure Google + Apple via `configure_social_auth`.
- Password reset → `/reset-password` route.
- Email verification confirm handled by existing `/auth` route on hash.
- Auth-gated routes moved under `_authenticated/` layout (managed).

### Step ingestion (no native app yet, but ready)
- `/api/public/ingest-steps` — POST with HMAC SHA-256 signature header (`x-signature`), body `{ user_id, day, steps, distance_km?, calories?, source }`. Uses `INGEST_HMAC_SECRET`. Upserts into `activity_steps`.
- Also a `recordSteps` `createServerFn` (auth required) so the web app can submit manual entries.

### Frontend wiring (full migration from localStorage)
- New `src/lib/profile.functions.ts`, `src/lib/settings.functions.ts`, `src/lib/steps.functions.ts`, `src/lib/leaderboard.functions.ts`, `src/lib/account.functions.ts`.
- Rewrite `src/lib/settings.tsx` to load from DB via TanStack Query when signed in; `update()` calls server fn. Children, streaks, settings all DB-backed.
- `src/routes/auth.tsx` — full signup/login/Google/Apple/forgot-password flow.
- New `src/routes/reset-password.tsx`.
- New `src/routes/_authenticated/route.tsx` — gate.
- Move `index, profile, stats, settings, parent, rewards, challenges, coach, map, onboarding` under `_authenticated/`.
- `src/routes/challenges.tsx` leaderboard tab — query `leaderboard_*` views with realtime subscription on `activity_steps`.
- Replace all hardcoded `7240`, `WEEK[]`, mock streaks with DB reads.
- Settings page: change email, password, username, delete account, export data buttons.

### Security
- RLS on every table scoped to `auth.uid()`.
- `service_role` GRANTs for server fns and the ingest endpoint.
- No `anon` grants on user data.
- HMAC verification on `/api/public/ingest-steps`.
- Zod input validation on all server fns.
- Leaderboard view excludes email; respects `anonymous_leaderboard` (returns "Anonymous" name).
- GDPR: `requestDataExport` server fn emails a JSON dump link; `deleteAccount` cascades via FKs + calls admin client.

### Out of scope (browser limit — documented in README)
- HealthKit/HealthConnect ingestion (native app calls the HMAC endpoint).
- ManagedSettings/FamilyControls OS shielding (native app only).

### Execution order
1. Migration (schema + RLS + grants + trigger + views + realtime).
2. Configure social auth (Google, Apple) + add `INGEST_HMAC_SECRET`.
3. Server functions + ingest route.
4. Rewrite `settings.tsx` provider + auth route + reset-password.
5. Move pages under `_authenticated/`.
6. Wire leaderboards, profile, home, stats to DB.
7. Settings page account-management UI.
