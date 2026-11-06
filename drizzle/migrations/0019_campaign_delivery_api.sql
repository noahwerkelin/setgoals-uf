CREATE OR REPLACE FUNCTION public.app_version_gte(_v text, _min text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public' AS $$
  SELECT _min IS NULL OR _min='' OR (_v IS NOT NULL AND
    (SELECT array_agg(coalesce(nullif(regexp_replace(x,'\D','','g'),''),'0')::int ORDER BY o) FROM unnest(string_to_array(_v,'.')) WITH ORDINALITY t(x,o))
    >= (SELECT array_agg(coalesce(nullif(regexp_replace(x,'\D','','g'),''),'0')::int ORDER BY o) FROM unnest(string_to_array(_min,'.')) WITH ORDINALITY t(x,o)))
$$;

CREATE OR REPLACE FUNCTION public.campaign_audience_match(_uid uuid, _targeting jsonb, _lang text, _is_ad boolean, _service boolean)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE aud jsonb := coalesce(_targeting->'audiences','["all"]'::jsonb); langs jsonb := _targeting->'languages';
  t text := public.account_type(_uid); pl text := public.account_plan(_uid); bday date; adult boolean;
BEGIN
  SELECT birthday INTO bday FROM profiles WHERE id=_uid;
  adult := t <> 'child' AND (bday IS NULL OR bday <= CURRENT_DATE - interval '18 years');
  IF t='child' AND (_is_ad OR NOT _service) THEN RETURN false; END IF;
  IF _is_ad AND NOT adult THEN RETURN false; END IF;
  IF _lang IS NOT NULL AND langs IS NOT NULL AND jsonb_array_length(langs)>0 AND NOT (langs ? _lang) THEN RETURN false; END IF;
  RETURN aud ? 'all'
    OR (aud ? 'adults' AND adult) OR (aud ? 'parents' AND t='parent') OR (aud ? 'children' AND t='child')
    OR (aud ? 'free' AND pl='free') OR (aud ? 'pro' AND pl='pro') OR (aud ? 'pro_family' AND pl='pro_family');
END $$;
REVOKE ALL ON FUNCTION public.campaign_audience_match(uuid,jsonb,text,boolean,boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_active_announcements(_lang text DEFAULT 'sv', _app_version text DEFAULT NULL)
RETURNS TABLE(id uuid, kind text, priority integer, display_mode text, requires_ack boolean, dismissible boolean, content jsonb, style jsonb, ends_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN; END IF;
  RETURN QUERY SELECT a.id,a.kind,a.priority,a.display_mode,a.requires_ack,a.dismissible,
    coalesce(a.content->coalesce(_lang,'sv'), a.content->'sv'), a.style, a.ends_at
  FROM app_announcements a
  WHERE a.status IN ('scheduled','published') AND (a.starts_at IS NULL OR a.starts_at<=now()) AND (a.ends_at IS NULL OR a.ends_at>now())
    AND public.app_version_gte(_app_version,a.min_app_version)
    AND public.campaign_audience_match(uid,a.targeting,_lang,false,a.kind IN ('important','maintenance','service_interruption','app_update'))
    AND NOT (a.display_mode='once_per_user' AND EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=a.id AND e.event IN ('displayed','dismissed','acknowledged')))
    AND NOT (a.display_mode='until_dismissed' AND EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=a.id AND e.event IN ('dismissed','acknowledged')))
    AND NOT (a.requires_ack AND EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=a.id AND e.event='acknowledged'))
  ORDER BY a.priority, a.starts_at NULLS LAST
  LIMIT 1;
END $$;

CREATE OR REPLACE FUNCTION public.get_active_advertisements(_lang text DEFAULT 'sv', _app_version text DEFAULT NULL)
RETURNS TABLE(id uuid, sponsor_name text, template text, content jsonb, style jsonb, cta_url text, secondary_url text, sponsored_label text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.get_active_announcements(_lang,_app_version)) THEN RETURN; END IF;
  RETURN QUERY SELECT d.id,d.sponsor_name,d.template,coalesce(d.content->coalesce(_lang,'sv'),d.content->'sv'),d.style,d.cta_url,d.secondary_url,
    CASE WHEN coalesce(_lang,'sv')='en' THEN 'Sponsored' ELSE 'Sponsrad' END
  FROM app_advertisements d
  WHERE d.status IN ('scheduled','active') AND (d.starts_at IS NULL OR d.starts_at<=now()) AND (d.ends_at IS NULL OR d.ends_at>now())
    AND public.app_version_gte(_app_version,d.min_app_version)
    AND public.campaign_audience_match(uid,d.targeting,_lang,true,false)
    AND (SELECT count(*) FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=d.id AND e.event='displayed' AND e.created_at>=CURRENT_DATE) < d.max_per_day
    AND NOT EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=d.id AND e.event='displayed' AND e.created_at > now() - make_interval(mins => d.min_minutes_between))
    AND (d.max_total_per_user IS NULL OR (SELECT count(*) FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=d.id AND e.event='displayed') < d.max_total_per_user)
    AND NOT (d.once_per_campaign AND EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_id=d.id AND e.event='displayed'))
    AND NOT EXISTS (SELECT 1 FROM campaign_events e WHERE e.user_id=uid AND e.campaign_type='advertisement' AND e.event='displayed' AND e.created_at > now() - interval '4 hours')
  ORDER BY d.priority, d.starts_at NULLS LAST
  LIMIT 1;
END $$;

CREATE OR REPLACE FUNCTION public.record_campaign_event(_type text, _campaign_id uuid, _event text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid(); ok boolean;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
  IF _event NOT IN ('eligible','displayed','dismissed','acknowledged','cta_click','secondary_click') THEN RAISE EXCEPTION 'Invalid event'; END IF;
  ok := CASE _type
    WHEN 'announcement' THEN EXISTS (SELECT 1 FROM app_announcements WHERE id=_campaign_id AND status IN ('scheduled','published'))
    WHEN 'advertisement' THEN EXISTS (SELECT 1 FROM app_advertisements WHERE id=_campaign_id AND status IN ('scheduled','active')) AND public.account_type(uid)<>'child'
    WHEN 'sponsored_challenge' THEN EXISTS (SELECT 1 FROM sponsored_challenges WHERE id=_campaign_id AND status IN ('visible','active','completed'))
    ELSE false END;
  IF NOT coalesce(ok,false) THEN RAISE EXCEPTION 'Campaign not available'; END IF;
  IF (SELECT count(*) FROM campaign_events WHERE user_id=uid AND created_at > now()-interval '1 minute') >= 30 THEN RAISE EXCEPTION 'Too many events'; END IF;
  INSERT INTO campaign_events(campaign_type,campaign_id,user_id,event) VALUES(_type,_campaign_id,uid,_event);
END $$;

CREATE OR REPLACE FUNCTION public.sponsored_progress_value(_uid uuid, _c public.sponsored_challenges)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH days AS (
    SELECT a.day, sum(a.steps) steps, sum(a.distance_km) km, sum(a.exercise_minutes) ex
    FROM activity_steps a WHERE a.user_id=_uid
      AND a.day >= coalesce((_c.starts_at AT TIME ZONE _c.timezone)::date, '-infinity'::date)
      AND a.day <= least(CURRENT_DATE, coalesce((_c.ends_at AT TIME ZONE _c.timezone)::date, CURRENT_DATE))
    GROUP BY a.day)
  SELECT CASE _c.metric
    WHEN 'steps' THEN coalesce(sum(steps),0)
    WHEN 'distance_km' THEN coalesce(sum(km),0)
    WHEN 'exercise_minutes' THEN coalesce(sum(ex),0)
    WHEN 'active_days' THEN count(*) FILTER (WHERE steps >= coalesce((SELECT daily_goal FROM user_settings WHERE user_id=_uid),10000))
  END FROM days
$$;
REVOKE ALL ON FUNCTION public.sponsored_progress_value(uuid, public.sponsored_challenges) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_sponsored_challenges(_lang text DEFAULT 'sv')
RETURNS TABLE(id uuid, content jsonb, sponsor_name text, sponsor_logo_url text, sponsor_url text, style jsonb, sponsored_label boolean, metric text, target integer,
  reward_minutes integer, reward_badge_id text, join_mode text, phase text, join_opens_at timestamptz, join_closes_at timestamptz, starts_at timestamptz, ends_at timestamptz,
  joined boolean, progress numeric, completed boolean, reward_claimed boolean, claims_remaining integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN; END IF;
  RETURN QUERY SELECT c.id, coalesce(c.content->coalesce(_lang,'sv'),c.content->'sv'), c.sponsor_name, c.sponsor_logo_url, c.sponsor_url, c.style, c.sponsored_label,
    c.metric, c.target, c.reward_minutes, c.reward_badge_id, c.join_mode,
    CASE WHEN c.starts_at IS NOT NULL AND now()<c.starts_at THEN 'upcoming' WHEN c.ends_at IS NOT NULL AND now()>=c.ends_at THEN 'ended' ELSE 'active' END,
    c.join_opens_at, c.join_closes_at, c.starts_at, c.ends_at,
    (p.user_id IS NOT NULL OR c.join_mode='automatic'),
    CASE WHEN p.user_id IS NOT NULL OR c.join_mode='automatic' THEN public.sponsored_progress_value(uid,c) END,
    (p.completed_at IS NOT NULL), EXISTS (SELECT 1 FROM sponsored_challenge_rewards r WHERE r.challenge_id=c.id AND r.user_id=uid),
    CASE WHEN c.max_claims IS NULL THEN NULL ELSE greatest(0, c.max_claims - (SELECT count(*)::int FROM sponsored_challenge_rewards r WHERE r.challenge_id=c.id)) END
  FROM sponsored_challenges c LEFT JOIN sponsored_challenge_participants p ON p.challenge_id=c.id AND p.user_id=uid
  WHERE c.status IN ('visible','active','completed') AND (c.visible_at IS NULL OR c.visible_at<=now()) AND (c.removed_at IS NULL OR c.removed_at>now())
    AND public.campaign_audience_match(uid,c.eligibility,_lang,false,true)
  ORDER BY c.starts_at NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.join_sponsored_challenge(_challenge_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid(); c sponsored_challenges%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
  SELECT * INTO c FROM sponsored_challenges WHERE id=_challenge_id;
  IF NOT FOUND OR c.status NOT IN ('visible','active') OR (c.visible_at IS NOT NULL AND c.visible_at>now()) OR (c.removed_at IS NOT NULL AND c.removed_at<=now()) THEN RAISE EXCEPTION 'Challenge not available'; END IF;
  IF (c.join_opens_at IS NOT NULL AND now()<c.join_opens_at) OR (c.join_closes_at IS NOT NULL AND now()>=c.join_closes_at) OR (c.ends_at IS NOT NULL AND now()>=c.ends_at) THEN RAISE EXCEPTION 'Participation is closed'; END IF;
  IF NOT public.campaign_audience_match(uid,c.eligibility,NULL,false,true) THEN RAISE EXCEPTION 'Not eligible'; END IF;
  INSERT INTO sponsored_challenge_participants(challenge_id,user_id) VALUES(_challenge_id,uid) ON CONFLICT DO NOTHING;
END $$;

CREATE OR REPLACE FUNCTION public.get_sponsored_challenge_progress(_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid(); c sponsored_challenges%ROWTYPE; v numeric; joined boolean;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
  SELECT * INTO c FROM sponsored_challenges WHERE id=_challenge_id AND status IN ('visible','active','completed');
  IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not available'; END IF;
  joined := c.join_mode='automatic' OR EXISTS (SELECT 1 FROM sponsored_challenge_participants WHERE challenge_id=c.id AND user_id=uid);
  v := CASE WHEN joined THEN public.sponsored_progress_value(uid,c) ELSE 0 END;
  RETURN jsonb_build_object('joined',joined,'metric',c.metric,'target',c.target,'progress',v,'percent',least(100,round(100*v/c.target,1)),
    'completed',v>=c.target,'reward_claimed',EXISTS (SELECT 1 FROM sponsored_challenge_rewards WHERE challenge_id=c.id AND user_id=uid));
END $$;

CREATE OR REPLACE FUNCTION public.claim_sponsored_challenge_reward(_challenge_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid(); c sponsored_challenges%ROWTYPE; v numeric; inserted int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
  SELECT * INTO c FROM sponsored_challenges WHERE id=_challenge_id FOR UPDATE;
  IF NOT FOUND OR c.status NOT IN ('visible','active','completed') OR (c.removed_at IS NOT NULL AND c.removed_at<=now()) THEN RAISE EXCEPTION 'Challenge not available'; END IF;
  IF c.join_mode='manual' AND NOT EXISTS (SELECT 1 FROM sponsored_challenge_participants WHERE challenge_id=c.id AND user_id=uid) THEN RAISE EXCEPTION 'Join the challenge first'; END IF;
  IF EXISTS (SELECT 1 FROM sponsored_challenge_rewards WHERE challenge_id=c.id AND user_id=uid) THEN RETURN jsonb_build_object('granted',false,'reason','already_claimed'); END IF;
  v := public.sponsored_progress_value(uid,c);
  IF v < c.target THEN RETURN jsonb_build_object('granted',false,'reason','not_completed','progress',v,'target',c.target); END IF;
  IF c.max_claims IS NOT NULL AND (SELECT count(*) FROM sponsored_challenge_rewards WHERE challenge_id=c.id) >= c.max_claims THEN RETURN jsonb_build_object('granted',false,'reason','sold_out'); END IF;
  INSERT INTO sponsored_challenge_participants(challenge_id,user_id,completed_at) VALUES(c.id,uid,now())
    ON CONFLICT (challenge_id,user_id) DO UPDATE SET completed_at=coalesce(sponsored_challenge_participants.completed_at,now());
  INSERT INTO sponsored_challenge_rewards(challenge_id,user_id,minutes,badge_id) VALUES(c.id,uid,c.reward_minutes,c.reward_badge_id) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS inserted = ROW_COUNT;
  IF inserted = 0 THEN RETURN jsonb_build_object('granted',false,'reason','already_claimed'); END IF;
  IF c.reward_minutes > 0 THEN
    INSERT INTO earned_balances(user_id,day,bonus_min) VALUES(uid,CURRENT_DATE,c.reward_minutes)
    ON CONFLICT (user_id,day) DO UPDATE SET bonus_min = earned_balances.bonus_min + EXCLUDED.bonus_min;
  END IF;
  IF c.reward_badge_id IS NOT NULL THEN
    INSERT INTO user_badges(user_id,badge_id) VALUES(uid,c.reward_badge_id) ON CONFLICT (user_id,badge_id) DO NOTHING;
  END IF;
  RETURN jsonb_build_object('granted',true,'minutes',c.reward_minutes,'badge_id',c.reward_badge_id);
END $$;

DO $$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY['get_active_announcements(text,text)','get_active_advertisements(text,text)','record_campaign_event(text,uuid,text)',
    'get_sponsored_challenges(text)','join_sponsored_challenge(uuid)','get_sponsored_challenge_progress(uuid)','claim_sponsored_challenge_reward(uuid)']
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;