-- 1) restriction_settings: parent read access + drop anon access
REVOKE ALL ON public.restriction_settings FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.restriction_settings TO authenticated;
GRANT ALL ON public.restriction_settings TO service_role;

DROP POLICY IF EXISTS "Parents can view child restrictions" ON public.restriction_settings;
CREATE POLICY "Parents can view child restrictions"
  ON public.restriction_settings
  FOR SELECT TO authenticated
  USING (public.is_parent_of(user_id));

-- 2) subscriptions: read-only for users, writes server-side only
REVOKE ALL ON public.subscriptions FROM anon;
REVOKE ALL ON public.subscriptions FROM authenticated;
GRANT SELECT ON public.subscriptions TO authenticated;
GRANT ALL ON public.subscriptions TO service_role;

-- 3) leaderboard() is only invoked server-side with the service role
REVOKE ALL ON FUNCTION public.leaderboard(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard(text) TO service_role;