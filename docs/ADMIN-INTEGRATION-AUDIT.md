# SetGoals admin integration: pre-change audit

Checked: 2026-11-06 UTC. **Read-only findings, not implementation approval.**

## Decision and blockers

The candidate architectural route is for the separate website to establish its own session with the existing app-owned Auth service and use caller-authorized database RPCs. External return URLs can be allowlisted, but this alone does not establish platform support for sharing managed Cloud Auth across projects. The previous description of this route as already supported was too strong. Secure, supported website authentication and privileged access remain unverified; do not enable a second Cloud backend or alter the existing backend before resolving this gate.

The current integration is **not ready for privileged website use**. No schema, policies, roles, Auth settings, subscriptions, Swift files or published code were changed. No production records were created or edited. The only supplied admin document is the instruction for this project; the referenced complete admin specification is missing.

Before implementation:

1. Supply the complete admin specification, including the precise four-role permission matrix.
2. Verify hosted MFA support and actual Auth rate limits. Available read-only settings expose neither. Existing admin RPCs have no AAL/MFA guard.
3. Approve exact website callback/recovery URLs and add them to this app's Auth redirect allow-list. `https://setgoals.se` paths are currently absent from that list.
4. Resolve and regression-test the existing daily-stats read failure described below before broadening access.
5. Supply or authorize an existing ordinary test account and MFA-enabled admin test account. No other account was selected, created or elevated during this audit.

## Verified backend identity

The project metadata tool confirms that the session tools, existing client configuration and active managed backend refer to the same SetGoals Lovable Cloud instance. App project: `587a4510-3c4e-4fcd-9ace-59e300587f0c`; published app: `https://step-wise-life.lovable.app`. No second backend was provisioned.

Use this project's existing public client configuration as the source of truth. Do not substitute the website's health URL for Auth configuration. Managed-backend identifiers, vendor Auth URLs and keys are deliberately not reproduced in this handoff; configure the separate project from the verified existing client configuration, never a service-role credential. The website's future server handlers must validate sessions against this existing Auth owner, not against a newly enabled Cloud instance.

## Connection, redirects and CORS

- Hosted Site URL is currently `https://setgoals.se/confirmation`.
- The actual redirect allow-list contains the app's preview/published addresses, but **no `setgoals.se` callback or recovery address**. A Site URL alone does not allow an explicit redirect. Email confirmation/recovery completion at the website has not been tested.
- Hosted public Auth settings report email sign-in enabled, Google/Apple disabled, signup enabled and automatic email confirmation disabled. These settings were read, not changed.
- Live preflights from origin `https://setgoals.se` to the Auth password-token endpoint and database RPC endpoint returned 200 and allowed `authorization,apikey,content-type,x-client-info`. Their managed preflight origin header is `*`; actual RPC responses allowed `https://setgoals.se`. This is transport evidence, not authorization or proof of website login.
- No authenticated admin server route currently exists in this app. If narrow app-owned cross-origin routes are chosen later, use versioned `/api/public/admin/v1/*` handlers with input validation, verified token, backend role check, MFA assurance check and an exact-origin CORS allow-list including error responses. This naming is a proposal, not an available API. Native clients still need token/role verification; CORS cannot secure them.
- Prefer the existing Auth verifier when adding handlers. Do not assume JWKS verification works from an advertised key alone; externally verified JWTs require confirming the active signing algorithm and fixed issuer. No key rotation was performed.

## Live database findings

All nine inspected tables exist and have RLS enabled: `profiles`, `activity_steps`, `user_daily_stats`, `user_settings`, `subscriptions`, `children`, `parent_child_relationships`, `user_roles`, `admin_pro_grants`.

The role enum currently contains only `admin` and `user`. `profiles.role` is account kind, not administrative authority. Super Admin, Support Admin and Marketing Admin are not implemented.

Live ACLs, not just repository migration text, were checked:

- Eight inspected tables have broad anon/authenticated table grants; RLS is the actual row-access boundary. Broad grants must not be interpreted as permission to read every row.
- `subscriptions`: authenticated has SELECT only, service role has full table access; owner-read RLS applies.
- `user_roles`: owner-read SELECT policy only; no client write policy. Ordinary clients cannot grant themselves roles through table writes under the current RLS.
- `admin_pro_grants`: broad table ACLs exist in the live instance, unlike the narrower source grant intent, but there are **no RLS policies**. The requester's read returned zero rows. No public entitlement-management function was found.
- Profiles/settings are owner-scoped, with parent-read profile/activity and parent-manage children policies. Relationships are parent/child read-only.
- `user_daily_stats`: owner-read and admin-read policies exist. Direct read with the requester's real session returned **403 / 42501**, although privileged admin-history RPC succeeded. `has_role` is executable only by the owner/service role, while the admin-read RLS policy calls it. This is a concrete compatibility risk requiring a focused regression-tested fix, not blanket widening of grants.

32 migration entries were read from the live migration registry. Admin analytics/grant functions also exist in the live function catalog, despite their source SQL being in `drizzle/migrations`; file presence and a registry count are not proof that every source migration was applied byte-for-byte.

## Existing RPC contracts — deployed, currently unversioned

All four data RPCs below are SECURITY DEFINER with `search_path=public`, executable by authenticated users but not anon, and check `has_role(auth.uid(), 'admin')` inside their bodies. They have no MFA guard. Their use should remain blocked for the new panel until the four-role/MFA design is complete.

| RPC | Inputs/defaults | Returned data / bounds |
| --- | --- | --- |
| `admin_users` | `_search=''`, `_sort='created_at'`, `_desc=true`, `_limit=25`, `_offset=0` | User ID, email, username, display name, creation/last-active timestamps, total/average steps, goal, average earned/used seconds, last activity date, recorded days, total matching count. SQL clamps limit to 1–100 and offset to >=0. |
| `admin_user_history` | `_uid uuid`, `_from date=NULL` | Complete matching `user_daily_stats` rows ordered by day. No pagination or maximum range. |
| `admin_overview_daily` | `_from date`, `_to date=CURRENT_DATE` | Day, active/new users, mean steps, goal percentage, mean earned/used seconds. No maximum range or ordered-range validator. |
| `admin_overview_totals` | none | Total users; active counts for current day and trailing 7/30-day windows. |
| `is_admin` | none | Boolean for existing admin role; SECURITY DEFINER. |

`admin_users` searches email, username, display name and UUID prefix server-side. Sort cases: `total_steps`, `avg_steps`, `avg_earned`, `last_active`; other values fall back to creation date. Search length/wildcards are not narrowly validated. Future versioned callers should define validated enums, search bounds and maximum date ranges; these validations are not yet implemented.

Observed errors: signed-out calls returned HTTP 401 / SQLSTATE `42501`; malformed JWT returned HTTP 401 / `PGRST301`. A valid non-admin is expected to hit the SQL role guard but was not exercised with a real ordinary account. Do not claim its HTTP behavior was tested.

## Data interpretation

- `active_*` means days with positive recorded steps, **not measured app sessions**.
- `profiles.last_active_at` is updated by step-row triggers, at most once every five minutes; do not label it app engagement without a new verified source.
- Screen-time used seconds are sourced from `earned_balances.consumed_min`; this is consumed managed allowance, not automatically full-device screen time.
- Current refresh logic does not populate actual-device or carried-over stats columns. It computes remaining from earned + bonus − consumed, without rollover. Admin reports must label this limitation rather than fabricate missing data.
- Historical goals are frozen for past days by the existing refresh function. This audit did not change history or Apple transactions.

## Tests actually run

Read-only HTTPS tests used the requester's existing real admin account and public client configuration. Response contents, identifiers and tokens were not printed or stored in the handoff.

- Existing admin role confirmed from caller-scoped `user_roles`; no role was assigned.
- `admin_users`, `admin_overview_totals`, `admin_user_history`: signed-out and malformed-token requests denied; requester admin session succeeded.
- User pagination with limit 1 and offsets 0/1 returned distinct users.
- Requester profile/settings/children reads succeeded. Direct daily-stats read failed as noted above. Admin grant table returned no rows.
- The test session carried no `aal` claim; nevertheless admin RPCs succeeded. Together with the live function definitions this confirms **no enforced AAL2 requirement** on those RPCs. It does not prove that normal password sessions or hosted MFA are configured correctly.
- A GET probe to the factors collection returned 405; this inconclusive method probe establishes neither MFA availability nor absence. No factor enrollment/challenge was attempted.
- Published `/api/public/health`: GET 200, OPTIONS 204, correct website origin header, response fields exactly `status` and `checked_at`. It was not extended.

Not tested: a real ordinary-user session; expired but otherwise valid token; all four-role restrictions; MFA enrollment/challenge/recovery; browser login from the actual website; password-reset email completion; effective hosted rate-limit thresholds; full Swift/app regression flows. No fake accounts or mutations were used to simulate these checks.

## First Super Admin process and later stages

No bootstrap endpoint exists or was created. After complete-spec approval and a tested migration introducing the separate backend roles/permission mapping and audit log, have the owner explicitly identify an existing verified account. Check its Auth ID, verified email and MFA enrollment; do not choose an account from a list. Perform a tightly scoped privileged database assignment with audit actor/target/reason, then verify least privilege and direct AAL2-gated calls. Existing `admin` membership must not silently confer Super Admin.

Later stages need approved schema/API designs for role-change auditing, support notes, marketing-safe aggregates/campaigns, and separate temporary promotional entitlements. Support must not publish campaigns/change entitlements; Marketing must not read private identities, child data or support notes. The complete specification must settle additional Admin/Super Admin boundaries. Preserve verified paid transactions and existing permanent grants.

## Changes and publishing

This stage added documentation only. **No migration or backend/Auth change was applied; nothing was published.** Existing RPCs are already live. Future server endpoints must be implemented, tested and explicitly published with approval before the website calls them. Database changes apply directly when approved for implementation; do not confuse deployed database functions with published app routes.