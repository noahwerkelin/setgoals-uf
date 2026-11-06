CREATE OR REPLACE FUNCTION public.account_plan(_uid uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id=_uid AND s.is_pro AND (s.pro_expires_at IS NULL OR s.pro_expires_at > now()) AND s.pro_plan::text LIKE 'family%') THEN 'pro_family'
    WHEN EXISTS (SELECT 1 FROM promotional_entitlements p WHERE p.user_id=_uid AND p.revoked_at IS NULL AND now() BETWEEN p.starts_at AND p.expires_at AND p.plan='pro_family') THEN 'pro_family'
    WHEN public.pro_is_active(_uid) THEN 'pro'
    WHEN EXISTS (SELECT 1 FROM promotional_entitlements p WHERE p.user_id=_uid AND p.revoked_at IS NULL AND now() BETWEEN p.starts_at AND p.expires_at) THEN 'pro'
    ELSE 'free' END
$$;
REVOKE ALL ON FUNCTION public.account_plan(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.account_type(_uid uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM children c WHERE c.auth_user_id=_uid) THEN 'child'
              WHEN EXISTS (SELECT 1 FROM children c WHERE c.parent_id=_uid) THEN 'parent'
              ELSE 'individual' END
$$;
REVOKE ALL ON FUNCTION public.account_type(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb; d date := CURRENT_DATE;
BEGIN
  PERFORM public.admin_require('overview','dashboard_stats');
  WITH plans AS (SELECT public.account_plan(p.id) pl FROM profiles p)
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM profiles),
    'dau', (SELECT count(*) FROM app_activity_days WHERE day=d),
    'wau', (SELECT count(DISTINCT user_id) FROM app_activity_days WHERE day > d-7),
    'mau', (SELECT count(DISTINCT user_id) FROM app_activity_days WHERE day > d-30),
    'app_activity_tracking_since', (SELECT min(day) FROM app_activity_days),
    'step_sync_active_1d', (SELECT count(*) FROM user_daily_stats WHERE stat_date=d AND steps>0),
    'step_sync_active_7d', (SELECT count(DISTINCT user_id) FROM user_daily_stats WHERE stat_date>d-7 AND steps>0),
    'step_sync_active_30d', (SELECT count(DISTINCT user_id) FROM user_daily_stats WHERE stat_date>d-30 AND steps>0),
    'new_today', (SELECT count(*) FROM profiles WHERE created_at::date=d),
    'new_week', (SELECT count(*) FROM profiles WHERE created_at >= date_trunc('week', now())),
    'new_month', (SELECT count(*) FROM profiles WHERE created_at >= date_trunc('month', now())),
    'pro', (SELECT count(*) FROM plans WHERE pl='pro'),
    'pro_family', (SELECT count(*) FROM plans WHERE pl='pro_family'),
    'free', (SELECT count(*) FROM plans WHERE pl='free'),
    'active_sponsored_challenges', (SELECT count(*) FROM sponsored_challenges WHERE status IN ('visible','active') AND (removed_at IS NULL OR removed_at>now())),
    'active_announcements', (SELECT count(*) FROM app_announcements WHERE status IN ('published','scheduled') AND (starts_at IS NULL OR starts_at<=now()) AND (ends_at IS NULL OR ends_at>now())),
    'scheduled_campaigns', (SELECT (SELECT count(*) FROM app_announcements WHERE status='scheduled' AND starts_at>now())
       + (SELECT count(*) FROM app_advertisements WHERE status='scheduled' AND starts_at>now())
       + (SELECT count(*) FROM sponsored_challenges WHERE status='scheduled')),
    'steps_today', (SELECT coalesce(sum(steps),0) FROM user_daily_stats WHERE stat_date=d),
    'steps_week', (SELECT coalesce(sum(steps),0) FROM user_daily_stats WHERE stat_date>=date_trunc('week',now())::date),
    'steps_month', (SELECT coalesce(sum(steps),0) FROM user_daily_stats WHERE stat_date>=date_trunc('month',now())::date),
    'steps_all_time', (SELECT coalesce(sum(steps),0) FROM user_daily_stats),
    'avg_daily_steps_per_active_user', (SELECT round(avg(steps)) FROM user_daily_stats WHERE steps>0 AND stat_date>d-30),
    'screen_time_earned_seconds_total', (SELECT coalesce(sum(screen_time_earned_seconds),0) FROM user_daily_stats),
    'avg_screen_time_earned_seconds_per_user_day', (SELECT round(avg(screen_time_earned_seconds)) FROM user_daily_stats WHERE steps>0 AND stat_date>d-30),
    'coach_challenges_completed', (SELECT count(*) FROM coach_challenges WHERE status='completed'),
    'sponsored_challenge_completions', (SELECT count(*) FROM sponsored_challenge_participants WHERE completed_at IS NOT NULL),
    'sponsored_participants_today', (SELECT count(*) FROM sponsored_challenge_participants WHERE joined_at::date=d),
    'sponsored_participants_week', (SELECT count(*) FROM sponsored_challenge_participants WHERE joined_at>=date_trunc('week',now())),
    'active_definition', 'DAU/WAU/MAU = distinct accounts that called record_app_open (app opened). step_sync_* = accounts with synced steps > 0 (may be background HealthKit sync).'
  ) INTO r;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.admin_analytics_series(_from date, _to date DEFAULT CURRENT_DATE)
RETURNS TABLE(day date, new_users bigint, total_users bigint, dau bigint, wau bigint, mau bigint, step_active_users bigint, total_steps bigint, pro_new bigint, pro_active_paid_or_promo bigint, sponsored_joins bigint, sponsored_completions bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  PERFORM public.admin_require('analytics','analytics_series',NULL,jsonb_build_object('from',_from,'to',_to));
  IF _from IS NULL OR _to IS NULL OR _to < _from OR _to - _from > 400 THEN RAISE EXCEPTION 'Invalid range'; END IF;
  RETURN QUERY
  SELECT g::date,
    (SELECT count(*) FROM profiles p WHERE p.created_at::date=g::date),
    (SELECT count(*) FROM profiles p WHERE p.created_at::date<=g::date),
    (SELECT count(*) FROM app_activity_days a WHERE a.day=g::date),
    (SELECT count(DISTINCT a.user_id) FROM app_activity_days a WHERE a.day > g::date-7 AND a.day<=g::date),
    (SELECT count(DISTINCT a.user_id) FROM app_activity_days a WHERE a.day > g::date-30 AND a.day<=g::date),
    (SELECT count(*) FROM user_daily_stats s WHERE s.stat_date=g::date AND s.steps>0),
    (SELECT coalesce(sum(s.steps),0)::bigint FROM user_daily_stats s WHERE s.stat_date=g::date),
    (SELECT count(*) FROM subscriptions s WHERE s.created_at::date=g::date),
    (SELECT count(DISTINCT x.u) FROM (
       SELECT s.user_id u FROM subscriptions s WHERE s.status IN ('active','trialing','past_due') AND coalesce(s.created_at,'-infinity')::date<=g::date AND (s.current_period_end IS NULL OR s.current_period_end::date>=g::date)
       UNION SELECT p.user_id FROM promotional_entitlements p WHERE p.starts_at::date<=g::date AND p.expires_at::date>=g::date AND (p.revoked_at IS NULL OR p.revoked_at::date>g::date)) x),
    (SELECT count(*) FROM sponsored_challenge_participants c WHERE c.joined_at::date=g::date),
    (SELECT count(*) FROM sponsored_challenge_participants c WHERE c.completed_at::date=g::date)
  FROM generate_series(_from,_to,interval '1 day') g ORDER BY 1;
END $$;

CREATE OR REPLACE FUNCTION public.admin_users_v2(_search text DEFAULT '', _plan text DEFAULT NULL, _account_type text DEFAULT NULL, _activity text DEFAULT NULL,
  _registered_from date DEFAULT NULL, _registered_to date DEFAULT NULL, _sort text DEFAULT 'created_at', _desc boolean DEFAULT true, _limit integer DEFAULT 25, _offset integer DEFAULT 0)
RETURNS TABLE(user_id uuid, avatar_url text, display_name text, username text, email text, account_type text, plan text, created_at timestamptz, last_app_activity date, last_step_sync timestamptz, account_status text, total_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE q text := replace(replace(replace(left(coalesce(_search,''),100),'\','\\'),'%','\%'),'_','\_');
BEGIN
  PERFORM public.admin_require('users','user_search',NULL,jsonb_build_object('search',left(coalesce(_search,''),100),'plan',_plan,'type',_account_type,'activity',_activity));
  RETURN QUERY
  WITH base AS (
    SELECT p.id, p.avatar_url av, p.display_name dn, p.username un, u.email::text em, public.account_type(p.id) at, public.account_plan(p.id) pl,
      p.created_at ca, (SELECT max(a.day) FROM app_activity_days a WHERE a.user_id=p.id) lad, p.last_active_at ls, coalesce(f.status,'active') st
    FROM profiles p JOIN auth.users u ON u.id=p.id LEFT JOIN admin_account_flags f ON f.user_id=p.id
    WHERE (q='' OR u.email ILIKE '%'||q||'%' OR p.username ILIKE '%'||q||'%' OR p.display_name ILIKE '%'||q||'%' OR p.id::text ILIKE q||'%')
      AND (_registered_from IS NULL OR p.created_at::date >= _registered_from)
      AND (_registered_to IS NULL OR p.created_at::date <= _registered_to)
  ), filt AS (
    SELECT * FROM base b WHERE (_plan IS NULL OR b.pl=_plan) AND (_account_type IS NULL OR b.at=_account_type)
      AND (_activity IS NULL OR (_activity='active') = coalesce(greatest(b.lad, b.ls::date) > CURRENT_DATE-30, false))
  )
  SELECT b.id,b.av,b.dn,b.un,b.em,b.at,b.pl,b.ca,b.lad,b.ls,b.st,count(*) OVER()
  FROM filt b
  ORDER BY
    CASE WHEN _desc THEN CASE _sort WHEN 'username' THEN b.un WHEN 'display_name' THEN b.dn WHEN 'email' THEN b.em END END DESC NULLS LAST,
    CASE WHEN NOT _desc THEN CASE _sort WHEN 'username' THEN b.un WHEN 'display_name' THEN b.dn WHEN 'email' THEN b.em END END ASC NULLS LAST,
    CASE WHEN _desc THEN CASE _sort WHEN 'last_active' THEN coalesce(b.lad::timestamptz,b.ls) ELSE b.ca END END DESC NULLS LAST,
    CASE WHEN NOT _desc THEN CASE _sort WHEN 'last_active' THEN coalesce(b.lad::timestamptz,b.ls) ELSE b.ca END END ASC NULLS LAST,
    b.id
  LIMIT least(greatest(_limit,1),100) OFFSET greatest(_offset,0);
END $$;

CREATE OR REPLACE FUNCTION public.admin_user_detail(_uid uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb;
BEGIN
  PERFORM public.admin_require('users','user_detail',_uid);
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id=_uid) THEN RAISE EXCEPTION 'User not found'; END IF;
  SELECT jsonb_build_object(
    'profile', (SELECT jsonb_build_object('id',p.id,'username',p.username,'display_name',p.display_name,'avatar_url',p.avatar_url,'email',u.email,
        'birthday',p.birthday,'country_code',p.country_code,'region',p.region,'created_at',p.created_at,'last_step_sync',p.last_active_at,
        'onboarding_completed',p.onboarding_completed,'email_confirmed',u.email_confirmed_at IS NOT NULL,'last_sign_in_at',u.last_sign_in_at,
        'account_type',public.account_type(p.id),'plan',public.account_plan(p.id),
        'account_status',coalesce(f.status,'active'),'account_status_note',f.note,
        'last_app_activity',(SELECT max(day) FROM app_activity_days a WHERE a.user_id=p.id))
      FROM profiles p JOIN auth.users u ON u.id=p.id LEFT JOIN admin_account_flags f ON f.user_id=p.id WHERE p.id=_uid),
    'settings', (SELECT jsonb_build_object('daily_goal',s.daily_goal,'steps_per_30',s.steps_per_30,'daily_cap_hours',s.daily_cap_hours,'units',s.units,
        'theme_color',s.theme_color,'anonymous_leaderboard',s.anonymous_leaderboard,'push_on',s.push_on,'share_location',s.share_location,
        'st_rollover',s.st_rollover,'healthkit_connected',s.healthkit_connected,'googlefit_connected',s.googlefit_connected,'language',NULL)
      FROM user_settings s WHERE s.user_id=_uid),
    'activity', jsonb_build_object(
      'today', (SELECT jsonb_build_object('steps',coalesce(sum(steps),0),'distance_km',coalesce(sum(distance_km),0),'calories',coalesce(sum(calories),0),'exercise_minutes',coalesce(sum(exercise_minutes),0)) FROM activity_steps WHERE user_id=_uid AND day=CURRENT_DATE),
      'totals', (SELECT jsonb_build_object('steps',coalesce(sum(steps),0),'distance_km',coalesce(sum(distance_km),0),'calories',coalesce(sum(calories),0),'exercise_minutes',coalesce(sum(exercise_minutes),0),'days',count(DISTINCT day)) FROM activity_steps WHERE user_id=_uid),
      'avg_daily_steps', (SELECT round(avg(steps)) FROM user_daily_stats WHERE user_id=_uid AND steps>0),
      'screen_time_earned_seconds', (SELECT coalesce(sum(screen_time_earned_seconds),0) FROM user_daily_stats WHERE user_id=_uid),
      'screen_time_used_seconds', (SELECT sum(screen_time_used_seconds) FROM user_daily_stats WHERE user_id=_uid),
      'last_30_days', (SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.stat_date),'[]') FROM (SELECT stat_date,steps,step_goal,screen_time_earned_seconds,screen_time_bonus_seconds,screen_time_used_seconds FROM user_daily_stats WHERE user_id=_uid AND stat_date>CURRENT_DATE-30) d)),
    'streak', (SELECT to_jsonb(s) - 'user_id' FROM streaks s WHERE s.user_id=_uid),
    'friends', (SELECT coalesce(jsonb_agg(jsonb_build_object('user_id',p.id,'username',p.username,'display_name',p.display_name,'since',f.created_at)),'[]')
      FROM friendships f JOIN profiles p ON p.id = CASE WHEN f.user_id=_uid THEN f.friend_id ELSE f.user_id END WHERE _uid IN (f.user_id,f.friend_id)),
    'friend_requests', (SELECT coalesce(jsonb_agg(jsonb_build_object('id',r.id,'direction',CASE WHEN r.sender_id=_uid THEN 'outgoing' ELSE 'incoming' END,'user_id',p.id,'username',p.username,'created_at',r.created_at)),'[]')
      FROM friend_requests r JOIN profiles p ON p.id = CASE WHEN r.sender_id=_uid THEN r.recipient_id ELSE r.sender_id END WHERE _uid IN (r.sender_id,r.recipient_id)),
    'family', jsonb_build_object(
      'parent', (SELECT jsonb_build_object('user_id',p.id,'username',p.username,'display_name',p.display_name,'plan',public.account_plan(p.id)) FROM children c JOIN profiles p ON p.id=c.parent_id WHERE c.auth_user_id=_uid LIMIT 1),
      'children', (SELECT coalesce(jsonb_agg(jsonb_build_object('child_id',c.id,'user_id',c.auth_user_id,'name',c.name,'username',c.username,'status',c.invitation_status,
          'daily_goal',c.daily_goal,'steps_per_30',c.steps_per_30,'daily_cap_hours',c.daily_cap_hours,'bedtime',c.bedtime)),'[]') FROM children c WHERE c.parent_id=_uid)),
    'challenges', jsonb_build_object(
      'coach', (SELECT coalesce(jsonb_agg(jsonb_build_object('title',title,'metric',metric,'target',target,'status',status,'start_day',start_day) ORDER BY created_at DESC),'[]') FROM coach_challenges WHERE user_id=_uid),
      'sponsored', (SELECT coalesce(jsonb_agg(jsonb_build_object('challenge_id',sp.challenge_id,'name',sc.internal_name,'joined_at',sp.joined_at,'completed_at',sp.completed_at,
          'reward_minutes',rw.minutes,'reward_badge',rw.badge_id,'reward_granted_at',rw.granted_at)),'[]')
        FROM sponsored_challenge_participants sp JOIN sponsored_challenges sc ON sc.id=sp.challenge_id LEFT JOIN sponsored_challenge_rewards rw ON rw.challenge_id=sp.challenge_id AND rw.user_id=sp.user_id WHERE sp.user_id=_uid),
      'badges', (SELECT coalesce(jsonb_agg(jsonb_build_object('badge_id',badge_id,'earned_at',earned_at) ORDER BY earned_at),'[]') FROM user_badges WHERE user_id=_uid)),
    'subscription', jsonb_build_object(
      'current', (SELECT jsonb_build_object('is_pro',s.is_pro,'plan',s.pro_plan,'status',s.pro_status,'since',s.pro_since,'expires_at',s.pro_expires_at,'auto_renew',s.pro_auto_renew,'environment',s.pro_environment,
          'admin_permanent_grant',EXISTS(SELECT 1 FROM admin_pro_grants g WHERE g.user_id=_uid)) FROM user_settings s WHERE s.user_id=_uid),
      'effective_plan', public.account_plan(_uid),
      'history', (SELECT coalesce(jsonb_agg(jsonb_build_object('provider',provider,'product_id',product_id,'price_id',price_id,'status',status,'period_start',current_period_start,'period_end',current_period_end,'cancel_at_period_end',cancel_at_period_end,'environment',environment,'created_at',created_at) ORDER BY created_at DESC),'[]') FROM subscriptions WHERE user_id=_uid),
      'promotions', (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC),'[]') FROM promotional_entitlements p WHERE p.user_id=_uid))
  ) INTO r;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.admin_update_user(_uid uuid, _daily_goal integer DEFAULT NULL, _steps_per_30 integer DEFAULT NULL, _daily_cap_hours integer DEFAULT NULL,
  _account_status text DEFAULT NULL, _status_note text DEFAULT NULL, _reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE old record;
BEGIN
  IF _reason IS NULL OR length(trim(_reason)) < 3 THEN RAISE EXCEPTION 'Reason required'; END IF;
  IF _daily_goal IS NOT NULL AND (_daily_goal < 1000 OR _daily_goal > 100000) THEN RAISE EXCEPTION 'daily_goal must be 1000-100000'; END IF;
  IF _steps_per_30 IS NOT NULL AND (_steps_per_30 < 100 OR _steps_per_30 > 20000) THEN RAISE EXCEPTION 'steps_per_30 must be 100-20000'; END IF;
  IF _daily_cap_hours IS NOT NULL AND (_daily_cap_hours < 0 OR _daily_cap_hours > 24) THEN RAISE EXCEPTION 'daily_cap_hours must be 0-24'; END IF;
  IF _account_status IS NOT NULL AND _account_status NOT IN ('active','flagged','suspended') THEN RAISE EXCEPTION 'Invalid status'; END IF;
  SELECT daily_goal, steps_per_30, daily_cap_hours INTO old FROM user_settings WHERE user_id=_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  PERFORM public.admin_require_write('user_edit','user_update',_uid, jsonb_build_object('reason',_reason,
    'before',jsonb_build_object('daily_goal',old.daily_goal,'steps_per_30',old.steps_per_30,'daily_cap_hours',old.daily_cap_hours),
    'after',jsonb_build_object('daily_goal',_daily_goal,'steps_per_30',_steps_per_30,'daily_cap_hours',_daily_cap_hours,'account_status',_account_status)));
  PERFORM set_config('app.admin_write','1',true);
  UPDATE user_settings SET daily_goal=coalesce(_daily_goal,daily_goal), steps_per_30=coalesce(_steps_per_30,steps_per_30), daily_cap_hours=coalesce(_daily_cap_hours,daily_cap_hours) WHERE user_id=_uid;
  PERFORM set_config('app.admin_write','',true);
  IF _account_status IS NOT NULL THEN
    INSERT INTO admin_account_flags(user_id,status,note,updated_by,updated_at) VALUES(_uid,_account_status,_status_note,auth.uid(),now())
    ON CONFLICT (user_id) DO UPDATE SET status=EXCLUDED.status, note=EXCLUDED.note, updated_by=EXCLUDED.updated_by, updated_at=now();
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_subscription_overview()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb;
BEGIN
  PERFORM public.admin_require('subs_view','subscription_overview');
  WITH plans AS (SELECT public.account_plan(p.id) pl FROM profiles p)
  SELECT jsonb_build_object(
    'pro',(SELECT count(*) FROM plans WHERE pl='pro'), 'pro_family',(SELECT count(*) FROM plans WHERE pl='pro_family'), 'free',(SELECT count(*) FROM plans WHERE pl='free'),
    'expired',(SELECT count(*) FROM user_settings WHERE pro_expires_at IS NOT NULL AND pro_expires_at<=now()),
    'cancelling',(SELECT count(*) FROM subscriptions WHERE cancel_at_period_end AND (current_period_end IS NULL OR current_period_end>now())),
    'cancelled',(SELECT count(*) FROM subscriptions WHERE status IN ('canceled','cancelled')),
    'trialing',(SELECT count(*) FROM subscriptions WHERE status='trialing'),
    'active_promotions',(SELECT count(*) FROM promotional_entitlements WHERE revoked_at IS NULL AND now() BETWEEN starts_at AND expires_at),
    'permanent_admin_grants',(SELECT count(*) FROM admin_pro_grants),
    'active_by_price',(SELECT coalesce(jsonb_object_agg(price_id,n),'{}') FROM (SELECT price_id,count(*) n FROM subscriptions WHERE status IN ('active','trialing') AND (current_period_end IS NULL OR current_period_end>now()) GROUP BY price_id) x),
    'revenue_note','No verified payment amounts are stored; revenue = active_by_price x store price.'
  ) INTO r;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.admin_subscriptions_list(_search text DEFAULT '', _status text DEFAULT NULL, _limit integer DEFAULT 25, _offset integer DEFAULT 0)
RETURNS TABLE(id uuid, user_id uuid, username text, email text, provider text, product_id text, price_id text, status text, current_period_end timestamptz, cancel_at_period_end boolean, environment text, created_at timestamptz, total_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE q text := replace(replace(replace(left(coalesce(_search,''),100),'\','\\'),'%','\%'),'_','\_');
BEGIN
  PERFORM public.admin_require('subs_view','subscription_list');
  RETURN QUERY SELECT s.id,s.user_id,p.username,u.email::text,s.provider,s.product_id,s.price_id,s.status,s.current_period_end,s.cancel_at_period_end,s.environment,s.created_at,count(*) OVER()
  FROM subscriptions s JOIN profiles p ON p.id=s.user_id JOIN auth.users u ON u.id=s.user_id
  WHERE (_status IS NULL OR s.status=_status) AND (q='' OR p.username ILIKE '%'||q||'%' OR u.email ILIKE '%'||q||'%')
  ORDER BY s.created_at DESC NULLS LAST LIMIT least(greatest(_limit,1),100) OFFSET greatest(_offset,0);
END $$;

CREATE OR REPLACE FUNCTION public.admin_grant_promo(_uid uuid, _plan text, _expires_at timestamptz, _reason text, _starts_at timestamptz DEFAULT now())
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE pid uuid; paid boolean; applied boolean := false;
BEGIN
  IF _plan NOT IN ('pro','pro_family') THEN RAISE EXCEPTION 'Invalid plan'; END IF;
  IF _reason IS NULL OR length(trim(_reason))<3 THEN RAISE EXCEPTION 'Reason required'; END IF;
  IF _expires_at IS NULL OR _expires_at <= greatest(now(),coalesce(_starts_at,now())) OR _expires_at > now() + interval '1 year' THEN RAISE EXCEPTION 'Expiry must be in the future and within 1 year'; END IF;
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id=_uid) THEN RAISE EXCEPTION 'User not found'; END IF;
  IF public.account_type(_uid)='child' THEN RAISE EXCEPTION 'Child accounts inherit PRO from their parent'; END IF;
  PERFORM public.admin_require_write('subs_edit','promo_grant',_uid,jsonb_build_object('plan',_plan,'expires_at',_expires_at,'reason',_reason));
  SELECT public.pro_is_active(_uid) AND coalesce(s.pro_status,'') <> 'promotional' INTO paid FROM user_settings s WHERE s.user_id=_uid;
  IF NOT coalesce(paid,false) AND NOT EXISTS (SELECT 1 FROM admin_pro_grants g WHERE g.user_id=_uid) AND coalesce(_starts_at,now()) <= now() THEN
    PERFORM set_config('app.admin_write','1',true);
    UPDATE user_settings SET is_pro=true, pro_plan=(CASE WHEN _plan='pro_family' THEN 'family_monthly' ELSE 'monthly' END)::sub_plan,
      pro_status='promotional', pro_expires_at=_expires_at, pro_since=coalesce(pro_since,now()), pro_auto_renew=false WHERE user_id=_uid;
    PERFORM set_config('app.admin_write','',true);
    applied := true;
  END IF;
  INSERT INTO promotional_entitlements(user_id,plan,starts_at,expires_at,granted_by,reason,applied_to_settings)
  VALUES(_uid,_plan,coalesce(_starts_at,now()),_expires_at,auth.uid(),_reason,applied) RETURNING id INTO pid;
  RETURN pid;
END $$;

CREATE OR REPLACE FUNCTION public.admin_revoke_promo(_promo_id uuid, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE p promotional_entitlements%ROWTYPE;
BEGIN
  IF _reason IS NULL OR length(trim(_reason))<3 THEN RAISE EXCEPTION 'Reason required'; END IF;
  SELECT * INTO p FROM promotional_entitlements WHERE id=_promo_id FOR UPDATE;
  IF NOT FOUND OR p.revoked_at IS NOT NULL THEN RAISE EXCEPTION 'Promotion not found or already revoked'; END IF;
  PERFORM public.admin_require_write('subs_edit','promo_revoke',p.user_id,jsonb_build_object('promo_id',_promo_id,'reason',_reason));
  UPDATE promotional_entitlements SET revoked_at=now(), revoked_by=auth.uid(), revoke_reason=_reason WHERE id=_promo_id;
  IF NOT EXISTS (SELECT 1 FROM promotional_entitlements x WHERE x.user_id=p.user_id AND x.revoked_at IS NULL AND now() BETWEEN x.starts_at AND x.expires_at) THEN
    PERFORM set_config('app.admin_write','1',true);
    UPDATE user_settings SET is_pro=false, pro_status='inactive', pro_expires_at=now() WHERE user_id=p.user_id AND pro_status='promotional'
      AND NOT EXISTS (SELECT 1 FROM admin_pro_grants g WHERE g.user_id=p.user_id);
    PERFORM set_config('app.admin_write','',true);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_list_admins()
RETURNS TABLE(user_id uuid, email text, username text, display_name text, roles text[], mfa_factors integer, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  PERFORM public.admin_require('admin_manage','admin_list');
  RETURN QUERY SELECT a.user_id,u.email::text,p.username,p.display_name,array_agg(a.role ORDER BY a.role),
    (SELECT count(*)::int FROM auth.mfa_factors m WHERE m.user_id=a.user_id AND m.status='verified'), min(a.created_at)
  FROM admin_roles a JOIN profiles p ON p.id=a.user_id JOIN auth.users u ON u.id=a.user_id GROUP BY a.user_id,u.email,p.username,p.display_name ORDER BY 7;
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_role(_email text, _role text, _grant boolean, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE target uuid;
BEGIN
  IF _role NOT IN ('super_admin','admin','support_admin','marketing_admin') THEN RAISE EXCEPTION 'Invalid role'; END IF;
  IF _reason IS NULL OR length(trim(_reason))<3 THEN RAISE EXCEPTION 'Reason required'; END IF;
  SELECT u.id INTO target FROM auth.users u JOIN profiles p ON p.id=u.id WHERE lower(u.email)=lower(trim(_email)) AND u.email_confirmed_at IS NOT NULL;
  IF target IS NULL THEN RAISE EXCEPTION 'No confirmed account with that email'; END IF;
  IF public.account_type(target)='child' THEN RAISE EXCEPTION 'Child accounts cannot be admins'; END IF;
  PERFORM public.admin_require_write('admin_manage', CASE WHEN _grant THEN 'admin_role_grant' ELSE 'admin_role_revoke' END, target, jsonb_build_object('role',_role,'reason',_reason));
  PERFORM pg_advisory_xact_lock(hashtext('admin_roles'));
  IF _grant THEN
    INSERT INTO admin_roles(user_id,role) VALUES(target,_role) ON CONFLICT DO NOTHING;
  ELSE
    IF _role='super_admin' AND (SELECT count(*) FROM admin_roles WHERE role='super_admin' AND user_id<>target)=0 THEN RAISE EXCEPTION 'Cannot remove the last Super Admin'; END IF;
    DELETE FROM admin_roles WHERE user_id=target AND role=_role;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_get_audit_logs(_action text DEFAULT NULL, _actor uuid DEFAULT NULL, _target uuid DEFAULT NULL, _from timestamptz DEFAULT NULL, _to timestamptz DEFAULT NULL, _limit integer DEFAULT 50, _offset integer DEFAULT 0)
RETURNS TABLE(id uuid, created_at timestamptz, actor_id uuid, actor_username text, action text, target_user_id uuid, target_username text, details jsonb, aal text, total_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.admin_can('audit') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT l.id,l.created_at,l.actor_id,pa.username,l.action,l.target_user_id,pt.username,
    CASE WHEN public.admin_can('support') THEN l.details ELSE l.details - 'previous' END, l.aal, count(*) OVER()
  FROM admin_audit_log l LEFT JOIN profiles pa ON pa.id=l.actor_id LEFT JOIN profiles pt ON pt.id=l.target_user_id
  WHERE (_action IS NULL OR l.action ILIKE replace(_action,'%','')||'%') AND (_actor IS NULL OR l.actor_id=_actor) AND (_target IS NULL OR l.target_user_id=_target)
    AND (_from IS NULL OR l.created_at>=_from) AND (_to IS NULL OR l.created_at<=_to)
  ORDER BY l.created_at DESC LIMIT least(greatest(_limit,1),200) OFFSET greatest(_offset,0);
END $$;

CREATE OR REPLACE FUNCTION public.admin_campaign_calendar(_from timestamptz, _to timestamptz)
RETURNS TABLE(campaign_type text, id uuid, internal_name text, status text, starts_at timestamptz, ends_at timestamptz, priority integer, targeting jsonb, fullscreen boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.admin_can('calendar') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT 'announcement'::text,a.id,a.internal_name,a.status,a.starts_at,a.ends_at,a.priority,a.targeting,true FROM app_announcements a
    WHERE a.status<>'archived' AND coalesce(a.starts_at,'-infinity')<_to AND coalesce(a.ends_at,'infinity')>_from
  UNION ALL SELECT 'advertisement'::text,d.id,d.internal_name,d.status,d.starts_at,d.ends_at,d.priority,d.targeting,true FROM app_advertisements d
    WHERE d.status<>'archived' AND coalesce(d.starts_at,'-infinity')<_to AND coalesce(d.ends_at,'infinity')>_from
  UNION ALL SELECT 'sponsored_challenge'::text,c.id,c.internal_name,c.status,coalesce(c.visible_at,c.starts_at),coalesce(c.removed_at,c.ends_at),NULL::int,c.eligibility,false FROM sponsored_challenges c
    WHERE c.status<>'archived' AND coalesce(c.visible_at,c.starts_at,'-infinity')<_to AND coalesce(c.removed_at,c.ends_at,'infinity')>_from
  ORDER BY 5 NULLS FIRST;
END $$;

CREATE OR REPLACE FUNCTION public.admin_campaign_stats(_type text, _id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r jsonb; disp bigint; clk bigint;
BEGIN
  IF NOT (public.admin_can('analytics') OR public.admin_can('calendar')) THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  SELECT count(*) FILTER (WHERE event='displayed'), count(*) FILTER (WHERE event='cta_click') INTO disp, clk FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id;
  SELECT jsonb_build_object(
    'eligible',(SELECT count(*) FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id AND event='eligible'),
    'displayed',disp,'unique_viewers',(SELECT count(DISTINCT user_id) FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id AND event='displayed'),
    'dismissed',(SELECT count(*) FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id AND event='dismissed'),
    'acknowledged',(SELECT count(*) FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id AND event='acknowledged'),
    'cta_clicks',clk,'ctr',CASE WHEN disp>0 THEN round(100.0*clk/disp,2) END,
    'participants',(SELECT count(*) FROM sponsored_challenge_participants WHERE challenge_id=_id),
    'completions',(SELECT count(*) FROM sponsored_challenge_participants WHERE challenge_id=_id AND completed_at IS NOT NULL),
    'rewards_granted',(SELECT count(*) FROM sponsored_challenge_rewards WHERE challenge_id=_id),
    'reward_minutes_granted',(SELECT coalesce(sum(minutes),0) FROM sponsored_challenge_rewards WHERE challenge_id=_id),
    'daily',(SELECT coalesce(jsonb_agg(jsonb_build_object('day',y.dd,'displayed',y.a,'clicks',y.b,'joins',y.c) ORDER BY y.dd),'[]') FROM (
       SELECT x.dd, sum(x.a) a, sum(x.b) b, sum(x.c) c FROM (
         SELECT created_at::date dd, (event='displayed')::int a, (event='cta_click')::int b, 0 c FROM campaign_events WHERE campaign_type=_type AND campaign_id=_id
         UNION ALL SELECT joined_at::date,0,0,1 FROM sponsored_challenge_participants WHERE challenge_id=_id) x GROUP BY x.dd) y)
  ) INTO r;
  RETURN r;
END $$;

DO $$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY['admin_dashboard_stats()','admin_analytics_series(date,date)',
    'admin_users_v2(text,text,text,text,date,date,text,boolean,integer,integer)','admin_user_detail(uuid)',
    'admin_update_user(uuid,integer,integer,integer,text,text,text)','admin_subscription_overview()','admin_subscriptions_list(text,text,integer,integer)',
    'admin_grant_promo(uuid,text,timestamptz,text,timestamptz)','admin_revoke_promo(uuid,text)','admin_list_admins()','admin_set_role(text,text,boolean,text)',
    'admin_get_audit_logs(text,uuid,uuid,timestamptz,timestamptz,integer,integer)','admin_campaign_calendar(timestamptz,timestamptz)','admin_campaign_stats(text,uuid)']
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;