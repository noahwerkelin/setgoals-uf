-- 1. Extend children (child profiles)
ALTER TABLE public.children
  ADD COLUMN IF NOT EXISTS auth_user_id uuid UNIQUE,
  ADD COLUMN IF NOT EXISTS invitation_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS invitation_expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  ADD COLUMN IF NOT EXISTS bedtime text;

CREATE UNIQUE INDEX IF NOT EXISTS children_code_key ON public.children (code);

-- 2. Relationship table
CREATE TABLE IF NOT EXISTS public.parent_child_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL,
  child_profile_id uuid NOT NULL REFERENCES public.children(id) ON DELETE CASCADE,
  child_user_id uuid NOT NULL,
  linked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (child_profile_id)
);

GRANT SELECT ON public.parent_child_relationships TO authenticated;
GRANT ALL ON public.parent_child_relationships TO service_role;
ALTER TABLE public.parent_child_relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Relationship parent read" ON public.parent_child_relationships
  FOR SELECT TO authenticated USING (auth.uid() = parent_id);
CREATE POLICY "Relationship child read" ON public.parent_child_relationships
  FOR SELECT TO authenticated USING (auth.uid() = child_user_id);

-- 3. Helper: is the current user the parent of this auth user?
CREATE OR REPLACE FUNCTION public.is_parent_of(_child_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.children c
    WHERE c.auth_user_id = _child_user_id AND c.parent_id = auth.uid()
  )
$$;
REVOKE EXECUTE ON FUNCTION public.is_parent_of(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.is_parent_of(uuid) TO authenticated;

-- 4. Child can read (never write) their own profile row
CREATE POLICY "Children self-read" ON public.children
  FOR SELECT TO authenticated USING (auth.uid() = auth_user_id);

-- 5. Parents can read their children's activity + streaks
CREATE POLICY "Activity parent-read" ON public.activity_steps
  FOR SELECT TO authenticated USING (public.is_parent_of(user_id));
CREATE POLICY "Streaks parent-read" ON public.streaks
  FOR SELECT TO authenticated USING (public.is_parent_of(user_id));
CREATE POLICY "Balance parent-read" ON public.earned_balances
  FOR SELECT TO authenticated USING (public.is_parent_of(user_id));
CREATE POLICY "Profiles parent-read" ON public.profiles
  FOR SELECT TO authenticated USING (public.is_parent_of(id));

-- 6. Realtime sync
ALTER TABLE public.children REPLICA IDENTITY FULL;
ALTER TABLE public.activity_steps REPLICA IDENTITY FULL;
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.children; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_steps; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;