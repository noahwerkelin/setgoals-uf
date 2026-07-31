ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT 'SE';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS region TEXT NOT NULL DEFAULT 'Stockholms län';

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  base_username TEXT;
  final_username TEXT;
  suffix INT := 0;
BEGIN
  base_username := LOWER(REGEXP_REPLACE(
    COALESCE(NEW.raw_user_meta_data->>'username',
             SPLIT_PART(COALESCE(NEW.email, 'user'), '@', 1)),
    '[^a-z0-9_]', '', 'g'));
  IF base_username IS NULL OR LENGTH(base_username) < 3 THEN
    base_username := 'user' || SUBSTRING(NEW.id::text, 1, 8);
  END IF;
  final_username := base_username;
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = final_username)
     OR EXISTS (SELECT 1 FROM public.children WHERE lower(username) = final_username) LOOP
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  END LOOP;

  INSERT INTO public.profiles (id, username, display_name, email, avatar_url, birthday, country_code, region)
  VALUES (
    NEW.id,
    final_username,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', final_username),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url',
    NULLIF(NEW.raw_user_meta_data->>'birthday','')::date,
    COALESCE(NEW.raw_user_meta_data->>'country_code', 'SE'),
    COALESCE(NEW.raw_user_meta_data->>'region', 'Stockholms län')
  );
  INSERT INTO public.user_settings (user_id) VALUES (NEW.id);
  INSERT INTO public.streaks (user_id) VALUES (NEW.id);
  INSERT INTO public.earned_balances (user_id) VALUES (NEW.id);
  RETURN NEW;
END; $function$;

DROP FUNCTION IF EXISTS public.leaderboard(text) CASCADE;

CREATE OR REPLACE FUNCTION public.leaderboard(_scope TEXT)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  username TEXT,
  avatar_url TEXT,
  total_steps BIGINT,
  rank BIGINT
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  me UUID;
  my_country TEXT;
  my_region TEXT;
BEGIN
  me := auth.uid();
  IF me IS NULL THEN
    RETURN;
  END IF;

  SELECT country_code, region INTO my_country, my_region FROM public.profiles WHERE id = me;
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
  )
  SELECT
    p.id,
    CASE WHEN s.anonymous_leaderboard THEN 'Anonymous' ELSE COALESCE(NULLIF(p.display_name,''), p.username) END,
    CASE WHEN s.anonymous_leaderboard THEN '—' ELSE p.username END,
    CASE WHEN s.anonymous_leaderboard THEN NULL ELSE p.avatar_url END,
    pu.total,
    ROW_NUMBER() OVER (ORDER BY pu.total DESC)
  FROM per_user pu
  JOIN public.profiles p ON p.id = pu.user_id
  LEFT JOIN public.user_settings s ON s.user_id = pu.user_id
  ORDER BY pu.total DESC
  LIMIT 10;
END; $$;

REVOKE ALL ON FUNCTION public.leaderboard(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard(text) TO service_role;