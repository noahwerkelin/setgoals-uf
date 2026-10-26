-- Integration regressions against real schema/data, with every mutation rolled back.
BEGIN;
DO $$
DECLARE a uuid; b uuid; low_id uuid; high_id uuid; row_count int; value int;
BEGIN
  SELECT id INTO a FROM public.profiles ORDER BY id LIMIT 1;
  SELECT id INTO b FROM public.profiles WHERE id <> a ORDER BY id LIMIT 1;
  IF a IS NULL OR b IS NULL THEN RAISE EXCEPTION 'Two profiles required'; END IF;
  low_id := LEAST(a,b); high_id := GREATEST(a,b);
  DELETE FROM public.friendships WHERE user_id=low_id AND friend_id=high_id;
  INSERT INTO public.friendships(user_id,friend_id) VALUES(high_id,low_id);
  SELECT count(*) INTO row_count FROM public.friendships WHERE user_id=low_id AND friend_id=high_id;
  IF row_count <> 1 THEN RAISE EXCEPTION 'UUID normalization lost an endpoint'; END IF;
  DELETE FROM public.friendships WHERE user_id=low_id AND friend_id=high_id;
  PERFORM set_config('request.jwt.claim.sub',high_id::text,true);
  PERFORM public.add_my_friend(low_id);
  PERFORM public.add_my_friend(low_id);
  SELECT count(*) INTO row_count FROM public.my_friends() WHERE id=low_id;
  IF row_count <> 1 THEN RAISE EXCEPTION 'Add reversed UUID or duplicate failed'; END IF;
  PERFORM set_config('request.jwt.claim.sub',low_id::text,true);
  SELECT count(*) INTO row_count FROM public.my_friends() WHERE id=high_id AND length(username)>0;
  IF row_count <> 1 THEN RAISE EXCEPTION 'Symmetric friend identity read failed'; END IF;
  SELECT count(*) INTO row_count FROM public.search_friend_users((SELECT username FROM public.profiles WHERE id=high_id));
  IF row_count <> 1 THEN RAISE EXCEPTION 'Exact username search failed'; END IF;
  BEGIN
    PERFORM public.add_my_friend(low_id);
    RAISE EXCEPTION 'Self friendship allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'Cannot add yourself' THEN RAISE; END IF;
  END;
  IF has_function_privilege('anon','public.search_friend_users(text)','EXECUTE')
    OR has_function_privilege('anon','public.add_my_friend(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous friendship access allowed';
  END IF;
  UPDATE public.user_settings SET st_rollover=true,steps_per_30=1000,daily_cap_hours=5,is_pro=true,pro_expires_at=NULL WHERE user_id=a;
  DELETE FROM public.activity_steps WHERE user_id=a AND day=CURRENT_DATE-1;
  DELETE FROM public.earned_balances WHERE user_id=a AND day IN (CURRENT_DATE-1,CURRENT_DATE);
  INSERT INTO public.activity_steps(user_id,day,steps,distance_km,calories,exercise_minutes,source)
  VALUES(a,CURRENT_DATE-1,1500,0,0,0,'healthkit');
  SELECT public.compute_rollover(a,CURRENT_DATE) INTO value;
  IF value <> 45 THEN RAISE EXCEPTION '1500 steps at 1000/30 must earn 45, got %',value; END IF;
  INSERT INTO public.earned_balances(user_id,day,bonus_min,consumed_min) VALUES(a,CURRENT_DATE-1,20,15);
  SELECT public.compute_rollover(a,CURRENT_DATE) INTO value;
  IF value <> 50 THEN RAISE EXCEPTION 'Rollover must subtract consumed time and retain gifts'; END IF;
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SELECT public.claim_rollover(CURRENT_DATE) INTO value;
  IF value <> 50 THEN RAISE EXCEPTION 'PRO claim failed'; END IF;
  UPDATE public.activity_steps SET steps=3000 WHERE user_id=a AND day=CURRENT_DATE-1;
  SELECT public.claim_rollover(CURRENT_DATE) INTO value;
  IF value <> 50 THEN RAISE EXCEPTION 'Repeated claim changed rollover'; END IF;
  SELECT bonus_min INTO value FROM public.earned_balances WHERE user_id=a AND day=CURRENT_DATE;
  IF value <> 0 THEN RAISE EXCEPTION 'Rollover contaminated bonus minutes'; END IF;
END $$;
ROLLBACK;