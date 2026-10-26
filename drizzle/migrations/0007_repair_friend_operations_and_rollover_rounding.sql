CREATE OR REPLACE FUNCTION public.normalize_friendship()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE original_user uuid := NEW.user_id;
BEGIN
  IF NEW.user_id > NEW.friend_id THEN
    NEW.user_id := NEW.friend_id;
    NEW.friend_id := original_user;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.search_friend_users(_query text)
RETURNS TABLE(id uuid, username text, name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE q text := lower(trim(_query));
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE = '42501'; END IF;
  IF length(q) < 2 OR length(q) > 20 THEN RETURN; END IF;
  RETURN QUERY SELECT p.id, p.username::text, COALESCE(NULLIF(p.display_name,''),p.username)::text
  FROM profiles p WHERE p.id <> auth.uid() AND strpos(lower(p.username),q) > 0
  ORDER BY p.username LIMIT 8;
END $$;
REVOKE ALL ON FUNCTION public.search_friend_users(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_friend_users(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.my_friends()
RETURNS TABLE(id uuid, friendship_id uuid, username text, name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE = '42501'; END IF;
  RETURN QUERY SELECT p.id, f.id, p.username::text, COALESCE(NULLIF(p.display_name,''),p.username)::text
  FROM friendships f JOIN profiles p ON p.id = CASE WHEN f.user_id=auth.uid() THEN f.friend_id ELSE f.user_id END
  WHERE f.user_id=auth.uid() OR f.friend_id=auth.uid() ORDER BY p.username;
END $$;
REVOKE ALL ON FUNCTION public.my_friends() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_friends() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.add_my_friend(_friend_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
  IF _friend_id IS NULL OR uid = _friend_id THEN RAISE EXCEPTION 'Cannot add yourself'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=_friend_id) THEN RAISE EXCEPTION 'User not found'; END IF;
  INSERT INTO friendships(user_id,friend_id) VALUES(LEAST(uid,_friend_id),GREATEST(uid,_friend_id))
  ON CONFLICT(user_id,friend_id) DO NOTHING;
END $$;
REVOKE ALL ON FUNCTION public.add_my_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_my_friend(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.compute_rollover(_uid uuid, _day date)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE s record; y_steps int; y_bal record; cap int; earned int;
BEGIN
  SELECT steps_per_30, daily_cap_hours, st_rollover INTO s FROM user_settings WHERE user_id=_uid;
  IF s IS NULL OR NOT s.st_rollover OR s.daily_cap_hours >= 24 THEN RETURN 0; END IF;
  cap := s.daily_cap_hours * 60;
  SELECT COALESCE(SUM(steps),0) INTO y_steps FROM activity_steps WHERE user_id=_uid AND day=_day-1;
  earned := LEAST(cap, floor(y_steps::numeric * 30 / GREATEST(1,s.steps_per_30))::integer);
  SELECT bonus_min, rollover_min, consumed_min INTO y_bal FROM earned_balances WHERE user_id=_uid AND day=_day-1;
  RETURN GREATEST(0, LEAST(cap, earned + COALESCE(y_bal.bonus_min,0) + COALESCE(y_bal.rollover_min,0) - COALESCE(y_bal.consumed_min,0)));
END $$;
REVOKE ALL ON FUNCTION public.compute_rollover(uuid,date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compute_rollover(uuid,date) TO service_role;