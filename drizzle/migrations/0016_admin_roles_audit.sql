CREATE TABLE public.admin_roles (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('super_admin','admin','support_admin','marketing_admin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);
GRANT SELECT ON public.admin_roles TO authenticated;
GRANT ALL ON public.admin_roles TO service_role;
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own admin roles readable" ON public.admin_roles FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE TABLE public.admin_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid NOT NULL,
  action text NOT NULL,
  target_user_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  aal text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.admin_audit_log TO authenticated;
GRANT ALL ON public.admin_audit_log TO service_role;
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

INSERT INTO public.admin_roles(user_id, role)
SELECT r.user_id, 'super_admin' FROM public.user_roles r JOIN public.profiles p ON p.id=r.user_id
WHERE r.role='admin' ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.admin_can(_perm text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.admin_roles a WHERE a.user_id=auth.uid() AND (
      a.role='super_admin'
      OR (a.role='admin' AND _perm IN ('overview','users','history','audit'))
      OR (a.role='support_admin' AND _perm IN ('users','history'))
      OR (a.role='marketing_admin' AND _perm IN ('overview'))))
$$;

CREATE POLICY "Super admins read audit" ON public.admin_audit_log FOR SELECT TO authenticated USING (public.admin_can('audit'));

CREATE OR REPLACE FUNCTION public.admin_require(_perm text, _action text, _target uuid DEFAULT NULL, _details jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.admin_can(_perm) THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  INSERT INTO public.admin_audit_log(actor_id, action, target_user_id, details, aal)
  VALUES (auth.uid(), _action, _target, coalesce(_details,'{}'::jsonb), auth.jwt()->>'aal');
END $$;
REVOKE ALL ON FUNCTION public.admin_require(text,text,uuid,jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_me()
RETURNS TABLE(user_id uuid, roles text[], aal text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT auth.uid(), coalesce(array_agg(a.role ORDER BY a.role) FILTER (WHERE a.role IS NOT NULL), '{}'), auth.jwt()->>'aal'
  FROM (SELECT 1) x LEFT JOIN public.admin_roles a ON a.user_id=auth.uid()
  WHERE auth.uid() IS NOT NULL
$$;

CREATE OR REPLACE FUNCTION public.admin_overview_totals()
 RETURNS TABLE(total_users bigint, active_1d bigint, active_7d bigint, active_30d bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  PERFORM public.admin_require('overview','overview_totals');
  RETURN QUERY SELECT
    (SELECT COUNT(*) FROM profiles),
    (SELECT COUNT(DISTINCT d.user_id) FROM user_daily_stats d WHERE d.steps>0 AND d.stat_date = CURRENT_DATE),
    (SELECT COUNT(DISTINCT d.user_id) FROM user_daily_stats d WHERE d.steps>0 AND d.stat_date > CURRENT_DATE-7),
    (SELECT COUNT(DISTINCT d.user_id) FROM user_daily_stats d WHERE d.steps>0 AND d.stat_date > CURRENT_DATE-30);
END $function$;

CREATE OR REPLACE FUNCTION public.admin_overview_daily(_from date, _to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(day date, active_users bigint, new_users bigint, avg_steps numeric, goal_rate numeric, avg_earned_seconds numeric, avg_used_seconds numeric)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  PERFORM public.admin_require('overview','overview_daily',NULL,jsonb_build_object('from',_from,'to',_to));
  IF _to - _from > 366 THEN RAISE EXCEPTION 'Range too large'; END IF;
  RETURN QUERY
  SELECT g::date,
    (SELECT COUNT(*) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT COUNT(*) FROM profiles p WHERE p.created_at::date = g::date),
    (SELECT ROUND(AVG(d.steps)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT ROUND(100.0*AVG(CASE WHEN d.steps>=d.step_goal THEN 1 ELSE 0 END),1) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.step_goal IS NOT NULL AND d.steps>0),
    (SELECT ROUND(AVG(d.screen_time_earned_seconds)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.steps>0),
    (SELECT ROUND(AVG(d.screen_time_used_seconds)) FROM user_daily_stats d WHERE d.stat_date=g::date AND d.screen_time_used_seconds IS NOT NULL)
  FROM generate_series(_from, _to, interval '1 day') g ORDER BY 1;
END $function$;

CREATE OR REPLACE FUNCTION public.admin_user_history(_uid uuid, _from date DEFAULT NULL::date)
 RETURNS SETOF user_daily_stats
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  PERFORM public.admin_require('history','user_history',_uid);
  RETURN QUERY SELECT * FROM user_daily_stats WHERE user_id=_uid AND (_from IS NULL OR stat_date >= _from) ORDER BY stat_date;
END $function$;

CREATE OR REPLACE FUNCTION public.admin_users(_search text DEFAULT ''::text, _sort text DEFAULT 'created_at'::text, _desc boolean DEFAULT true, _limit integer DEFAULT 25, _offset integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, email text, username text, display_name text, created_at timestamp with time zone, last_active_at timestamp with time zone, total_steps bigint, avg_daily_steps numeric, step_goal integer, avg_earned_seconds numeric, avg_used_seconds numeric, last_activity_date date, days_recorded bigint, total_count bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE q text := replace(replace(replace(left(coalesce(_search,''),100),'\','\\'),'%','\%'),'_','\_');
BEGIN
  PERFORM public.admin_require('users','user_search',NULL,jsonb_build_object('search',left(coalesce(_search,''),100)));
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
    WHERE q = '' OR u.email ILIKE '%'||q||'%' OR p.username ILIKE '%'||q||'%'
       OR p.display_name ILIKE '%'||q||'%' OR p.id::text ILIKE q||'%'
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
END $function$;

REVOKE ALL ON FUNCTION public.admin_overview_totals(), public.admin_overview_daily(date,date), public.admin_user_history(uuid,date), public.admin_users(text,text,boolean,integer,integer), public.admin_me(), public.admin_can(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_overview_totals(), public.admin_overview_daily(date,date), public.admin_user_history(uuid,date), public.admin_users(text,text,boolean,integer,integer), public.admin_me(), public.admin_can(text) TO authenticated;