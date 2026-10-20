ALTER TABLE public.earned_balances DROP CONSTRAINT earned_balances_pkey;
ALTER TABLE public.earned_balances ADD CONSTRAINT earned_balances_pkey PRIMARY KEY (user_id, day);
ALTER TABLE public.earned_balances ADD COLUMN IF NOT EXISTS rollover_min integer NOT NULL DEFAULT 0;
ALTER TABLE public.earned_balances ADD COLUMN IF NOT EXISTS rollover_applied_at timestamptz;
ALTER TABLE public.user_settings ADD COLUMN IF NOT EXISTS st_rollover boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.guard_rollover_fields()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $$
BEGIN
  IF public.is_privileged_caller() OR current_setting('app.rollover_write', true) = '1' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.rollover_min := 0; NEW.rollover_applied_at := NULL;
  ELSE
    NEW.rollover_min := OLD.rollover_min; NEW.rollover_applied_at := OLD.rollover_applied_at;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER guard_rollover_fields BEFORE INSERT OR UPDATE ON public.earned_balances
FOR EACH ROW EXECUTE FUNCTION public.guard_rollover_fields();

CREATE OR REPLACE FUNCTION public.compute_rollover(_uid uuid, _day date)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE s record; y_steps int; y_bal record; cap int; earned int;
BEGIN
  SELECT steps_per_30, daily_cap_hours, st_rollover INTO s FROM user_settings WHERE user_id=_uid;
  IF s IS NULL OR NOT s.st_rollover OR s.daily_cap_hours >= 24 THEN RETURN 0; END IF;
  cap := s.daily_cap_hours * 60;
  SELECT COALESCE(SUM(steps),0) INTO y_steps FROM activity_steps WHERE user_id=_uid AND day=_day-1;
  earned := LEAST(cap, (y_steps / GREATEST(1, s.steps_per_30)) * 30);
  SELECT bonus_min, rollover_min, consumed_min INTO y_bal FROM earned_balances WHERE user_id=_uid AND day=_day-1;
  RETURN GREATEST(0, LEAST(cap, earned + COALESCE(y_bal.bonus_min,0) + COALESCE(y_bal.rollover_min,0) - COALESCE(y_bal.consumed_min,0)));
END $$;
REVOKE EXECUTE ON FUNCTION public.compute_rollover(uuid, date) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.claim_rollover(_day date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid(); existing record; r int;
BEGIN
  IF uid IS NULL OR _day IS NULL OR _day < CURRENT_DATE - 1 OR _day > CURRENT_DATE + 1 THEN RETURN 0; END IF;
  SELECT rollover_min, rollover_applied_at INTO existing FROM earned_balances WHERE user_id=uid AND day=_day;
  IF existing.rollover_applied_at IS NOT NULL THEN RETURN existing.rollover_min; END IF;
  IF NOT (public.pro_is_active(uid) OR public.parent_family_pro()) THEN RETURN 0; END IF;
  r := public.compute_rollover(uid, _day);
  IF NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id=uid AND st_rollover) THEN RETURN 0; END IF;
  PERFORM set_config('app.rollover_write', '1', true);
  INSERT INTO earned_balances (user_id, day, rollover_min, rollover_applied_at)
  VALUES (uid, _day, r, now())
  ON CONFLICT (user_id, day) DO UPDATE SET rollover_min = EXCLUDED.rollover_min, rollover_applied_at = EXCLUDED.rollover_applied_at
  WHERE earned_balances.rollover_applied_at IS NULL;
  PERFORM set_config('app.rollover_write', '', true);
  SELECT rollover_min INTO r FROM earned_balances WHERE user_id=uid AND day=_day;
  RETURN COALESCE(r, 0);
END $$;
REVOKE EXECUTE ON FUNCTION public.claim_rollover(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_rollover(date) TO authenticated;

CREATE OR REPLACE FUNCTION public.report_consumed(_day date, _minutes integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL OR _day IS NULL OR _minutes IS NULL OR _minutes < 0 OR _minutes > 1440
     OR _day < CURRENT_DATE - 2 OR _day > CURRENT_DATE + 1 THEN RETURN; END IF;
  INSERT INTO earned_balances (user_id, day, consumed_min) VALUES (uid, _day, _minutes)
  ON CONFLICT (user_id, day) DO UPDATE SET consumed_min = GREATEST(earned_balances.consumed_min, EXCLUDED.consumed_min);
END $$;
REVOKE EXECUTE ON FUNCTION public.report_consumed(date, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.report_consumed(date, integer) TO authenticated;