DROP POLICY IF EXISTS "Activity self-insert" ON public.activity_steps;
CREATE POLICY "Activity self-insert"
ON public.activity_steps
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND source IN ('manual'::public.step_source, 'healthkit'::public.step_source)
);

DROP POLICY IF EXISTS "Activity self-update" ON public.activity_steps;
CREATE POLICY "Activity self-update"
ON public.activity_steps
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
  AND source IN ('manual'::public.step_source, 'healthkit'::public.step_source)
)
WITH CHECK (
  auth.uid() = user_id
  AND source IN ('manual'::public.step_source, 'healthkit'::public.step_source)
);