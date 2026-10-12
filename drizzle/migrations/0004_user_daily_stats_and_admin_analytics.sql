ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_active_at timestamptz,
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.user_daily_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  stat_date date NOT NULL,
  steps integer NOT NULL DEFAULT 0,
  step_goal integer,
  screen_time_earned_seconds integer NOT NULL DEFAULT 0,
  screen_time_bonus_seconds integer NOT NULL DEFAULT 0,
  screen_time_used_seconds integer,
  screen_time_remaining_seconds integer,
  screen_time_carried_over_seconds integer,
  actual_device_screen_time_seconds integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, stat_date)
);
COMMENT ON COLUMN public.user_daily_stats.actual_device_screen_time_seconds IS 'Not collected: Apple does not expose device usage totals to apps. Always NULL.';
COMMENT ON COLUMN public.user_daily_stats.screen_time_used_seconds IS 'Earned time consumed inside SetGoals (not device usage).';
CREATE INDEX IF NOT EXISTS user_daily_stats_date_idx ON public.user_daily_stats (stat_date);

GRANT SELECT ON public.user_daily_stats TO authenticated;
GRANT ALL ON public.user_daily_stats TO service_role;
ALTER TABLE public.user_daily_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own daily stats" ON public.user_daily_stats
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins read all daily stats" ON public.user_daily_stats
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Recompute one user/day from the existing source tables (no second formula).
CREATE OR REPLACE FUNCTION public.refresh_daily_stats(_uid uuid, _day date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s int; g int; e int; b int; c int; has_bal boolean;
BEGIN
  IF _uid IS NULL OR _day IS NULL THEN RETURN; END IF;
  SELECT COALESCE(SUM(steps),0) INTO s FROM activity_steps WHERE user_id=_uid AND day=_day;
  SELECT earned_min, bonus_min, consumed_min, true INTO e, b, c, has_bal
    FROM earned_balances WHERE user_id=_uid AND day=_day;
  SELECT daily_goal INTO g FROM user_settings WHERE user_id=_uid;
  INSERT INTO user_daily_stats (user_id, stat_date, steps, step_goal,
    screen_time_earned_seconds, screen_time_bonus_seconds, screen_time_used_seconds, screen_time_remaining_seconds)
  VALUES (_uid, _day, s, g, COALESCE(e,0)*60, COALESCE(b,0)*60,
    CASE WHEN has_bal THEN c*60 END,
    CASE WHEN has_bal THEN GREATEST(0, e+b-c)*60 END)
  ON CONFLICT (user_id, stat_date) DO UPDATE SET
    steps=EXCLUDED.steps,
    -- goal is frozen once set for past days; only today follows goal changes
    step_goal=CASE WHEN _day >= CURRENT_DATE OR user_daily_stats.step_goal IS NULL THEN EXCLUDED.step_goal ELSE user_daily_stats.step_goal END,
    screen_time_earned_seconds=EXCLUDED.screen_time_earned_seconds,
    screen_time_bonus_seconds=EXCLUDED.screen_time_bonus_seconds,
    screen_time_used_seconds=EXCLUDED.screen_time_used_seconds,
    screen_time_remaining_seconds=EXCLUDED.screen_time_remaining_seconds,
    updated_at=now();
END $$;
REVOKE EXECUTE ON FUNCTION public.refresh_daily_stats(uuid, date) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_daily_stats_from_row()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.refresh_daily_stats(NEW.user_id, NEW.day);
  IF TG_TABLE_NAME = 'activity_steps' THEN
    UPDATE profiles SET last_active_at = now() WHERE id = NEW.user_id
      AND (last_active_at IS NULL OR last_active_at < now() - interval '5 minutes');
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.trg_daily_stats_goal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.daily_goal IS DISTINCT FROM OLD.daily_goal THEN
    UPDATE user_daily_stats SET step_goal = NEW.daily_goal, updated_at = now()
     WHERE user_id = NEW.user_id AND stat_date = CURRENT_DATE;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS daily_stats_from_steps ON public.activity_steps;
CREATE TRIGGER daily_stats_from_steps AFTER INSERT OR UPDATE ON public.activity_steps
  FOR EACH ROW EXECUTE FUNCTION public.trg_daily_stats_from_row();
DROP TRIGGER IF EXISTS daily_stats_from_balance ON public.earned_balances;
CREATE TRIGGER daily_stats_from_balance AFTER INSERT OR UPDATE ON public.earned_balances
  FOR EACH ROW EXECUTE FUNCTION public.trg_daily_stats_from_row();
DROP TRIGGER IF EXISTS daily_stats_goal ON public.user_settings;
CREATE TRIGGER daily_stats_goal AFTER UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION public.trg_daily_stats_goal();

-- Backfill from real existing history only (goal unknown for past days).
INSERT INTO public.user_daily_stats (user_id, stat_date, steps)
SELECT user_id, day, SUM(steps) FROM public.activity_steps GROUP BY user_id, day
ON CONFLICT (user_id, stat_date) DO NOTHING;
UPDATE public.user_daily_stats d SET
  screen_time_earned_seconds = b.earned_min*60, screen_time_bonus_seconds = b.bonus_min*60,
  screen_time_used_seconds = b.consumed_min*60,
  screen_time_remaining_seconds = GREATEST(0, b.earned_min+b.bonus_min-b.consumed_min)*60
FROM public.earned_balances b WHERE b.user_id=d.user_id AND b.day=d.stat_date;
UPDATE public.user_daily_stats d SET step_goal = s.daily_goal
FROM public.user_settings s WHERE s.user_id=d.user_id AND d.stat_date = CURRENT_DATE;
UPDATE public.profiles p SET last_active_at = x.t
FROM (SELECT user_id, MAX(updated_at) t FROM public.activity_steps GROUP BY user_id) x
WHERE x.user_id = p.id AND p.last_active_at IS NULL;

-- Admin: paginated user list
CREATE OR REPLACE FUNCTION public.admin_users(_search text DEFAULT '', _sort text DEFAULT 'created_at', _desc boolean DEFAULT true, _limit int DEFAULT 25, _offset int DEFAULT 0)
RETURNS TABLE(user_id uuid, email text, username text, display_name text, created_at timestamptz,
  last_active_at timestamptz, total_steps bigint, avg_daily_steps numeric, step_goal int,
  avg_earned_seconds numeric, avg_used_seconds numeric, last_activity_date date, days_recorded bigint, total_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.id, u.email::text em, p.username un, p.display_name dn, p.created_at ca, p.last_active_at la,
      COALESCE(a.tot,0)::bigint tot, a.avg_s, s.daily_goal g, a.avg_e, a.avg_u, a.last_d, COALESCE(a.n,0)::bigint n
    FROM profiles p
    JOIN auth.users u ON u.id = p.id
    LEFT JOIN user_settings s ON s.user_id = p.id
    LEFT JOIN LATERAL (
      SELECT SUM(d.steps) tot, ROUND(AVG(d.steps)) avg_s, ROUND(AVG(d.screen_time_earned_seconds)) avg_e,
        ROUND(AVG(d.screen_time_used_seconds)) avg_u, MAX(d.stat_date) FILTER (WHERE d.steps>0) last_d, COUNT(*) n
      FROM user_daily_stats d WHERE d.user_id = p.id) a ON true
    WHERE COALESCE(_search,'') = '' OR u.email ILIKE '%'||_search||'%' OR p.username ILIKE '%'||_search||'%'
       OR p.display_name ILIKE '%'||_search||'%' OR p.id::text ILIKE _search||'%'
  )
  SELECT b.id, b.em, b.un, b.dn, b.ca, b.la, b.tot, b.avg_s, b.g, b.avg_e, b.avg_u, b.last_d, b.n, COUNT(*) OVER()
  FROM base b
  ORDER BY
    CASE WHEN _desc THEN CASE _sort WHEN 'total_steps' THEN b.tot::numeric WHEN 'avg_steps' THEN b.avg_s WHEN 'avg_earned' THEN b.avg_e
      WHEN 'last_active' THEN extract(epoch FROM b.la)::numeric ELSE extract(epoch FROM b.ca)::numeric END END DESC NULLS LAST,
    CASE WHEN NOT _desc THEN CASE _sort WHEN 'total_steps' THEN b.tot::numeric WHEN 'avg_steps' THEN b.avg_s WHEN 'avg_earned' THEN b.avg_e
      WHEN 'last_active' THEN extract(epoch FROM b.la)::numeric ELSE extract(epoch FROM b.ca)::numeric END END ASC NULLS LAST,
    b.id
  LIMIT LEAST(GREATEST(_limit,1),100) OFFSET GREATEST(_offset,0);
END $$;

-- Admin: one user's history (missing days are simply absent)
CREATE OR REPLACE FUNCTION public.admin_user_history(_uid uuid, _from date DEFAULT NULL)
RETURNS SETOF public.user_daily_stats LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM user_daily_stats WHERE user_id=_uid AND (_from IS NULL OR stat_date >= _from) ORDER BY stat_date;
END $$;

-- Admin: per-day aggregate trend for the whole user base
CREATE OR REPLACE FUNCTION public.admin_overview_daily(_from date, _to date DEFAULT CURRENT_DATE)
RETURNS TABLE(day date, active_users bigint, new_users bigint, avg_steps numeric, goal_rate numeric,
  avg_earned_seconds numeric, avg_used_seconds numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT g::date,
    (SELECT COUNT(*) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT COUNT(*) FROM profiles p WHERE p.created_at::date = g::date),
    (SELECT ROUND(AVG(d.steps)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT ROUND(100.0*AVG(CASE WHEN d.steps>=d.step_goal THEN 1 ELSE 0 END),1) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.step_goal IS NOT NULL AND d.steps>0),
    (SELECT ROUND(AVG(d.screen_time_earned_seconds)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT ROUND(AVG(d.screen_time_used_seconds)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.screen_time_used_seconds IS NOT NULL)
  FROM generate_series(_from, _to, interval '1 day') g ORDER BY 1;
END $$;

CREATE OR REPLACE FUNCTION public.admin_overview_totals()
RETURNS TABLE(total_users bigint, active_1d bigint, active_7d bigint, active_30d bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT
    (SELECT COUNT(*) FROM profiles),
    (SELECT COUNT(DISTINCT user_id) FROM user_daily_stats WHERE steps>0 AND stat_date = CURRENT_DATE),
    (SELECT COUNT(DISTINCT user_id) FROM user_daily_stats WHERE steps>0 AND stat_date > CURRENT_DATE-7),
    (SELECT COUNT(DISTINCT user_id) FROM user_daily_stats WHERE steps>0 AND stat_date > CURRENT_DATE-30);
END $$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.has_role(auth.uid(), 'admin') $$;

REVOKE EXECUTE ON FUNCTION public.admin_users(text,text,boolean,int,int), public.admin_user_history(uuid,date),
  public.admin_overview_daily(date,date), public.admin_overview_totals(), public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_users(text,text,boolean,int,int), public.admin_user_history(uuid,date),
  public.admin_overview_daily(date,date), public.admin_overview_totals(), public.is_admin() TO authenticated;