# Architecture rules
- Swift friends views observe one account-scoped FriendsStore preloaded at authenticated app entry; refresh after mutations and foregrounding, never fetch on view appearance, so navigation reuses the same snapshot.
- Swift Home and Screen Time observe one account-scoped FamilyStore preloaded at account entry and refreshed after mutations/foregrounding; this avoids view-entry loading and clears private snapshots on sign-out.
- Settings uses a tab binding that dismisses its presentation on every tab selection, including Profile reselection, so the shared bottom bar behaves like a tab bar without visual changes.
- Friend search, list and insertion use caller-scoped database functions exposing only public identity fields; normalized insertion derives its first endpoint from auth.uid(), preserving restrictive direct-table policies.
- Native rollover restores the account preference without writing it back, reports measured usage before claiming, and synchronizes the resulting allowance with Apple's shared ledger immediately.
- Keep personal earning-rule and cap edits PRO-gated in both settings interfaces and in a database validation trigger, so old clients cannot bypass subscription access; do not gate parent-managed child rules or daily step goals.
- Keep the Swift and web upgrade views aligned using the existing semantic themes and bilingual translation dictionaries; preserve the existing purchase, restore, and child inheritance flows.
- The iOS AI coach goes through one authenticated server route that reads data via RLS as the caller; the model may only propose actions (goal, challenge, navigation) that the app applies after user confirmation, so AI output can never change settings or grant screen time.
- PRO screen-time rollover is computed only by the claim_rollover database function (once per user per local day, stored in its own column separate from bonus minutes); clients just display it, so all devices agree and it cannot be inflated.
- The iOS onboarding owns all account entry (sign in, kid code, sign up) and AuthView reuses it in auth-only mode, so there is one sign-in implementation; onboarding is only marked complete after authentication.
- Swift onboarding uses the shared PrimaryButton, F typography with bundled Albert Sans weights, and Theme tokens sourced from the web design system; declare font resources in both Info.plist and project.yml so Xcode generation cannot revert the visual match.
- Signed-out iOS actions (username check, kid-code redeem) call public server routes that reuse the web server logic, because the underlying database functions are service-role only.

- Native Profile embeds StatsView's shared cached content without a second AppShell or view-entry fetch; Screen Time replaces the Coach tab while Profile retains Coach access, preserving five navigation destinations.
- Native child management separates overview, tasks and settings with shared SegmentedTabs; child creation groups identity and rules in a shared-dialog flow, preserving existing mutation handlers.
- Native app selection uses draft FamilyActivityPicker sheets for separate Always Allowed/Earned Only policies; consolidate legacy tokens only on explicit Save and retain dormant per-category limit storage so old settings are not destroyed.
