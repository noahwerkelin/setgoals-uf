DROP POLICY IF EXISTS "Profiles parent-read" ON public.profiles;
CREATE POLICY "Profiles parent-read" ON public.profiles FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = profiles.id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Activity parent-read" ON public.activity_steps;
CREATE POLICY "Activity parent-read" ON public.activity_steps FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = activity_steps.user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Parents can view child restrictions" ON public.restriction_settings;
CREATE POLICY "Parents can view child restrictions" ON public.restriction_settings FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = restriction_settings.user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Streaks parent-read" ON public.streaks;
CREATE POLICY "Streaks parent-read" ON public.streaks FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = streaks.user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Grants parent-insert" ON public.screentime_grants;
CREATE POLICY "Grants parent-insert" ON public.screentime_grants FOR INSERT TO authenticated
WITH CHECK (auth.uid() = parent_id AND EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = screentime_grants.child_user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Balance parent-read" ON public.earned_balances;
CREATE POLICY "Balance parent-read" ON public.earned_balances FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = earned_balances.user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Balance parent-insert" ON public.earned_balances;
CREATE POLICY "Balance parent-insert" ON public.earned_balances FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = earned_balances.user_id AND c.parent_id = auth.uid()));

DROP POLICY IF EXISTS "Balance parent-update" ON public.earned_balances;
CREATE POLICY "Balance parent-update" ON public.earned_balances FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = earned_balances.user_id AND c.parent_id = auth.uid()))
WITH CHECK (EXISTS (SELECT 1 FROM public.children c WHERE c.auth_user_id = earned_balances.user_id AND c.parent_id = auth.uid()));