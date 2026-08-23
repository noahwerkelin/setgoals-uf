CREATE OR REPLACE FUNCTION public.leaderboard_ranked(_scope text, _uid uuid DEFAULT NULL)
RETURNS TABLE(user_id uuid, display_name text, username text, avatar_url text, total_steps bigint, rank bigint)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  me UUID;
  my_country TEXT;
  my_region TEXT;
BEGIN
  me := COALESCE(auth.uid(), _uid);
  IF me IS NULL THEN
    RETURN;
  END IF;

  SELECT p.country_code, p.region INTO my_country, my_region FROM public.profiles p WHERE p.id = me;
  my_country := COALESCE(my_country, 'SE');
  my_region := COALESCE(my_region, 'Stockholms län');

  RETURN QUERY
  WITH scope_users AS (
    SELECT p.id AS profile_id
    FROM public.profiles p
    WHERE
      CASE _scope
        WHEN 'national' THEN p.country_code = my_country
        WHEN 'local' THEN p.country_code = my_country AND p.region = my_region
        WHEN 'friends' THEN
          p.id = me
          OR EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE (f.user_id = me AND f.friend_id = p.id)
               OR (f.friend_id = me AND f.user_id = p.id)
          )
        ELSE TRUE
      END
  ),
  per_user AS (
    SELECT a.user_id, SUM(a.steps)::BIGINT AS total
    FROM public.activity_steps a
    JOIN scope_users su ON su.profile_id = a.user_id
    WHERE a.day = CURRENT_DATE
    GROUP BY a.user_id
  ),
  ranked AS (
    SELECT
      p.id AS uid,
      CASE WHEN s.anonymous_leaderboard THEN 'Anonymous' ELSE COALESCE(NULLIF(p.display_name,''), p.username) END AS dname,
      CASE WHEN s.anonymous_leaderboard THEN '—' ELSE p.username END AS uname,
      CASE WHEN s.anonymous_leaderboard THEN NULL ELSE p.avatar_url END AS avatar,
      pu.total AS total,
      ROW_NUMBER() OVER (ORDER BY pu.total DESC, p.id) AS rnk
    FROM per_user pu
    JOIN public.profiles p ON p.id = pu.user_id
    LEFT JOIN public.user_settings s ON s.user_id = pu.user_id
  )
  SELECT r.uid, r.dname, r.uname, r.avatar, r.total, r.rnk
  FROM ranked r
  WHERE r.rnk <= 10 OR r.uid = me
  ORDER BY r.rnk;
END; $function$;

REVOKE ALL ON FUNCTION public.leaderboard_ranked(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.leaderboard_ranked(text, uuid) TO authenticated, service_role;