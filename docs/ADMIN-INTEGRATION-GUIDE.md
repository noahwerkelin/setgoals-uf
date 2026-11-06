# SetGoals website admin integration — implementation gate

Reviewed: 2026-11-06 UTC. This is a blocked integration handoff, not an implemented API or approval to change the backend.

## Scope

The admin dashboard belongs to the separate website project at `https://setgoals.se/admin`. Reuse the existing SetGoals app backend only. Do not create another database, change SwiftUI, move records, choose a Super Admin account, or publish automatically.

## Recovered instruction and website inspection

The uploaded **Instruktion till SetGoals UF-projektet** explicitly requires a verified secure and supported connection before any migration or backend change, and directs implementation to stop if this cannot be confirmed. It references a separate complete admin specification; that specification is not present among this project's uploads.

A read-only snapshot of **Setgoals Sage Path** was inspected. Its roadmap confirms that admin authentication and implementation await the connection decision. Its chat records a separate upload called **SetGoals Admin Dashboard — Complete (pasted).md**, but the attachment's full contents are not available in this project's uploads or the inspected source snapshot. Chat summaries are not a substitute for its precise permission matrix.

## Connection status

The existing audit reports successful cross-origin preflights and authenticated RPC reads with an existing app admin session. These establish transport and existing app-session access, not a complete website login or supported cross-project managed-auth integration.

External domains can be added to the Auth return-address allow-list. This is not proof that managed Cloud Auth can be shared between projects or that the website can use the app's managed-auth SDK. Current platform guidance does not confirm that capability. No supported connection is therefore asserted here.

Before changing anything:

1. Use the uploaded instruction as the bounded first-stage scope; do not request another upload to repeat those requirements. Additional capabilities and unspecified role boundaries remain deferred.
2. Confirm a supported method for the website to authenticate against the existing Auth owner, without enabling Cloud in the website project or transferring private credentials.
3. Establish exact public website callback and recovery pages; have the owner add their addresses in **More → Users → Auth settings → Advanced → Redirect URLs**. Agent tools cannot edit this allow-list. Do not change the existing Site URL or app redirects as a workaround.
4. Verify actual hosted MFA enrollment/challenge support and rate-limit settings. Never infer these from local code or a session lacking an assurance claim.
5. Exercise website sign-in and password recovery, then a caller-authorized read using the resulting website session. Test role and AAL2 restrictions with explicitly authorized real test accounts.

## Existing contracts, not new capabilities

See `ADMIN-INTEGRATION-AUDIT.md` for existing RPC signatures, field meanings, grants, observed failures and tests. The existing `admin_users`, `admin_user_history`, `admin_overview_daily`, `admin_overview_totals` and `is_admin` are unversioned legacy contracts; four-role and MFA restrictions have not been implemented. Do not expose them as a completed secure dashboard integration.

The existing direct daily-stats read failure also requires reproduction and a narrow compatibility fix with regression coverage before new access is shipped. Do not restore broad helper execution or widen private table access without verifying all dependent policies.

## Implementation after the gate

Implement the approved role matrix in protected role storage, privilege checks and an administrative audit log. Marketing must not read private identities, child data or support notes; Support must not publish campaigns or change entitlements. Preserve paid transactions, permanent grants, and existing app flows.

Enforce MFA assurance in each privileged backend operation, not only the dashboard. Validate search and pagination on the server. Record precise error behavior, response types, applied migrations and tests only after implementation.

Assign the first Super Admin only after the owner explicitly identifies an existing verified account and its MFA status is checked; use a narrowly scoped privileged assignment with audit actor, target and reason. Never provide a public bootstrap function.

No role, RLS, table, Auth setting, subscription or SwiftUI change was made during this follow-up. No new endpoint was created and nothing needs publishing for this documentation. The public health endpoint remains unchanged and proves no privileged access.

## Approval follow-up — 2026-11-06 02:32 UTC

The owner approved proceeding with the first stage. This does not waive the uploaded instruction's requirement to verify the connection before backend changes.

Official documentation was queried specifically about a standalone website using the existing Cloud Auth URL/publishable key and its own caller session, **without** attaching a second Cloud backend. The answer distinguishes this from managed project attachment: external frontend hosting with the existing backend is documented, but the exact unrelated-website sign-in/MFA/recovery arrangement is not explicitly confirmed. A separate website's password sign-in and AAL2-protected call have therefore not been verified; the gate remains unresolved. This is a platform-verification blocker, not a request for another admin specification.

References: https://docs.lovable.dev/tips-tricks/external-deployment-hosting and https://docs.lovable.dev/features/authentication. These are evidence of general external frontend configuration, not proof that this dashboard arrangement has passed an end-to-end check. No new live-database inspection or authentication test was performed in this follow-up; earlier live findings remain dated audit evidence.

The previous promise to immediately implement four roles and MFA after switching to Build mode was premature. No migrations, role grants, RLS changes, Auth changes, credentials, Swift changes or publishing were made. Do not use an MCP OAuth recipe as proof of support for an ordinary browser dashboard. Platform feedback was submitted requesting an authoritative remote-auth integration contract and hosted MFA/rate-limit verification.
## Etapp 1 – genomförd (2026-11-06)

- Ny tabell `admin_roles` med rollerna `super_admin`, `admin`, `support_admin`, `marketing_admin`. Befintliga admins blev `super_admin`.
- Behörigheter: super_admin = allt; admin = overview, users, history, audit; support_admin = users, history; marketing_admin = overview.
- Ny tabell `admin_audit_log`: varje anrop till admin-funktionerna loggas med användare, åtgärd, mål och MFA-nivå (`aal`). Läsbar för super_admin/admin.
- `admin_me()` returnerar inloggad användares roller och `aal`. Dashboarden ska kräva `aal = 'aal2'` (MFA) innan den visar data.
- `admin_overview_totals`, `admin_overview_daily`, `admin_users`, `admin_user_history` kontrollerar nu rollbehörighet, loggar och är stängda för anonyma anrop. Sökningen escapar jokertecken.
- Hemsidan ansluter med appens publika URL + publishable key (finns i appens `.env`) och loggar in med vanlig e-post/lösenord.

## Etapp 2 – Full dashboard backend (2026-11-06)

Migrations: `0017_admin_dashboard_tables`, `0018_admin_dashboard_functions`, `0019_campaign_delivery_api`.

### Connection (website)
`createClient(VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY)` from this app's `.env`. Admins sign in with email/password, then enroll/verify TOTP (`supabase.auth.mfa.enroll/challenge/verify`). **Every write requires an `aal2` session** (enforced in the database); reads only require the role. Never put a service-role key in the website.

Redirect URLs for `https://setgoals.se/admin/login` and the password-reset page must be added by the owner in Auth settings → Redirect URLs.

### Permission matrix (`admin_can(perm)`)
| perm | super | admin | support | marketing |
|---|---|---|---|---|
| overview, analytics | ✓ | ✓ | | ✓ (aggregates only) |
| users, history | ✓ | ✓ | ✓ | |
| user_edit | ✓ | ✓ | | |
| support (notes) | ✓ | ✓ | ✓ | |
| subs_view | ✓ | ✓ | ✓ | |
| subs_edit (promos) | ✓ | ✓ | | |
| announcements, challenges, calendar | ✓ | ✓ | | ✓ |
| ads | ✓ | | | ✓ |
| audit | ✓ | ✓ | | |
| admin_manage | ✓ | | | |

Use `rpc('admin_me')` to get `{roles, aal}` and hide nav items; the backend enforces regardless.

### Admin RPCs (`supabase.rpc(name, args)`)
- `admin_dashboard_stats()` → jsonb with all overview cards. DAU/WAU/MAU come from `app_activity_days` (app opened); `step_sync_active_*` is reported separately.
- `admin_analytics_series({_from,_to})` → daily rows: new_users, total_users, dau, wau, mau, step_active_users, total_steps, pro_new, pro_active_paid_or_promo, sponsored_joins, sponsored_completions (max 400 days). Weekly/monthly = aggregate client-side.
- `admin_users_v2({_search,_plan:'free|pro|pro_family',_account_type:'individual|parent|child',_activity:'active|inactive',_registered_from,_registered_to,_sort:'created_at|last_active|username|display_name|email',_desc,_limit,_offset})` → rows incl. `total_count`.
- `admin_user_detail({_uid})` → jsonb: profile, settings, activity (today/totals/last_30_days), streak, friends, friend_requests, family, challenges (coach/sponsored/badges), subscription (current/effective_plan/history/promotions). `language` is null (not stored).
- `admin_update_user({_uid,_daily_goal,_steps_per_30,_daily_cap_hours,_account_status:'active|flagged|suspended',_status_note,_reason})` — validated, audited with before/after. Activity history cannot be edited.
- `admin_subscription_overview()`, `admin_subscriptions_list({_search,_status,_limit,_offset})`.
- `admin_grant_promo({_uid,_plan:'pro|pro_family',_expires_at,_reason,_starts_at?})` → id. Max 1 year. Stored in `promotional_entitlements`; only switches the app's PRO flag on when the user has no paid/permanent PRO. `admin_revoke_promo({_promo_id,_reason})` never removes paid access.
- `admin_list_admins()`, `admin_set_role({_email,_role,_grant,_reason})` (super only; the last Super Admin cannot be removed).
- `admin_get_audit_logs({_action,_actor,_target,_from,_to,_limit,_offset})`.
- `admin_campaign_calendar({_from,_to})` → unified rows (type, id, name, status, starts/ends, priority, targeting, fullscreen). Overlap warning = two `fullscreen` rows with intersecting time and audiences.
- `admin_campaign_stats({_type,_id})` → eligible, displayed, unique_viewers, dismissed, cta_clicks, ctr, participants, completions, rewards_granted, daily.

### Direct table access (RLS-protected, audited by trigger)
- `admin_support_notes` (select/insert/update; delete = super only). Fields: user_id, author_id, category (`general|technical|subscription|family|screen_time|account_access|other`), content, priority (`low|normal|high|urgent`), status (`open|resolved|archived`), important. Edit history is in the audit log (`details.previous`).
- `app_announcements`: internal_name, kind (`important|maintenance|service_interruption|new_feature|app_update|general|custom`), `content` = `{"sv":{title,subtitle,description,button_text},"en":{...}}`, `style` = `{background_color,gradient,background_image_url,text_color,icon,logo_url,button_color,button_destination,corner_radius,content_alignment,text_alignment,illustration_url}`, display_mode (`once_per_user|once_per_session|until_dismissed|every_launch`), requires_ack, dismissible (only service kinds may be non-dismissible), priority 1–4 (1 = critical), targeting `{"audiences":["all"|"adults"|"parents"|"children"|"free"|"pro"|"pro_family"],"languages":["sv","en"]}`, min_app_version, status (`draft|scheduled|published|paused|archived`), starts_at, ends_at, timezone.
- `app_advertisements`: sponsor_name, template (`fullscreen_image|centered_logo|image_bottom_text|gradient_illustration|minimal`), content/style as above, cta_url / secondary_url (https only), priority, targeting, max_per_day (1–5), min_minutes_between (≥30), max_total_per_user, once_per_campaign, status (`draft|scheduled|active|paused|expired|archived`), dates. Children and under-18s never receive ads (server-side).
- `sponsored_challenges`: content (sv/en title+description), sponsor_name/logo/url, style (cover_image_url, background_color, accent_color, icon), sponsored_label, metric (`steps|distance_km|active_days|exercise_minutes`), target, reward_minutes (0–240), reward_badge_id, max_claims, join_mode (`manual|automatic`), eligibility (same shape as targeting), status (`draft|scheduled|visible|active|completed|paused|archived`), visible_at, join_opens_at, join_closes_at, starts_at, ends_at, removed_at.
- `admin_preferences` (own row: `prefs` jsonb for language, theme, default timezone, default frequency, notifications).
- Duplicate = select + insert copy with `status='draft'`. Archive = update `status='archived'`. Delete = super only.

### App delivery API (for future SwiftUI; authenticated users)
- `record_app_open({_app_version,_platform})` – call on each foreground; feeds DAU/WAU/MAU.
- `get_active_announcements({_lang,_app_version})` → at most one, highest priority.
- `get_active_advertisements({_lang,_app_version})` → at most one; empty if an announcement is active; frequency caps + global 4-hour cap.
- `record_campaign_event({_type:'announcement|advertisement|sponsored_challenge',_campaign_id,_event:'eligible|displayed|dismissed|acknowledged|cta_click|secondary_click'})`.
- `get_sponsored_challenges({_lang})`, `join_sponsored_challenge({_challenge_id})`, `get_sponsored_challenge_progress({_challenge_id})`, `claim_sponsored_challenge_reward({_challenge_id})` – progress counted only from activity inside the challenge period; one claim per user enforced by primary key + row lock; minutes added as today's bonus.
Only template data is returned – never executable code.

### Not verified
No end-to-end test with a real admin session from the website (MFA enrolment, writes) has been performed yet.
