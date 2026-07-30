ALTER TABLE public.earned_balances ADD COLUMN IF NOT EXISTS bonus_min integer NOT NULL DEFAULT 0;

CREATE POLICY "Balance parent-insert" ON public.earned_balances
  FOR INSERT TO authenticated
  WITH CHECK (public.is_parent_of(user_id));

CREATE POLICY "Balance parent-update" ON public.earned_balances
  FOR UPDATE TO authenticated
  USING (public.is_parent_of(user_id))
  WITH CHECK (public.is_parent_of(user_id));

CREATE TABLE public.screentime_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL,
  child_user_id uuid NOT NULL,
  day date NOT NULL DEFAULT CURRENT_DATE,
  minutes integer NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.screentime_grants TO authenticated;
GRANT ALL ON public.screentime_grants TO service_role;

ALTER TABLE public.screentime_grants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Grants parent-read" ON public.screentime_grants
  FOR SELECT TO authenticated USING (auth.uid() = parent_id);

CREATE POLICY "Grants child-read" ON public.screentime_grants
  FOR SELECT TO authenticated USING (auth.uid() = child_user_id);

CREATE POLICY "Grants parent-insert" ON public.screentime_grants
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = parent_id AND public.is_parent_of(child_user_id));

CREATE INDEX idx_screentime_grants_child_day ON public.screentime_grants (child_user_id, day);