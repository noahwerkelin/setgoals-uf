ALTER TABLE public.user_settings ALTER COLUMN daily_cap_hours SET DEFAULT 5;
UPDATE public.user_settings SET daily_cap_hours = 5 WHERE daily_cap_hours = 3 AND NOT is_pro;
CREATE OR REPLACE FUNCTION public.guard_personal_earning_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF auth.role() = 'service_role' OR auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.steps_per_30 IS DISTINCT FROM 1000 OR NEW.daily_cap_hours IS DISTINCT FROM 5 THEN
      RAISE EXCEPTION 'Personal earning rules require an active PRO subscription' USING ERRCODE = '42501';
    END IF;
  ELSIF NEW.steps_per_30 IS DISTINCT FROM OLD.steps_per_30
     OR NEW.daily_cap_hours IS DISTINCT FROM OLD.daily_cap_hours THEN
    IF NOT OLD.is_pro OR (OLD.pro_expires_at IS NOT NULL AND OLD.pro_expires_at <= now())
       OR EXISTS (SELECT 1 FROM public.children WHERE auth_user_id = auth.uid()) THEN
      RAISE EXCEPTION 'Personal earning rules require an active PRO subscription' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_personal_earning_rules() FROM PUBLIC, anon, authenticated;