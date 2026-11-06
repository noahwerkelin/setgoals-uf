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

1. Obtain the complete admin specification from the website project.
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