CREATE OR REPLACE FUNCTION public.guard_child_rules_family_pro()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _family boolean;
BEGIN
  IF public.is_privileged_caller() OR auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND NEW.steps_per_30 = OLD.steps_per_30 AND NEW.daily_cap_hours = OLD.daily_cap_hours THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' AND NEW.steps_per_30 = 1000 AND NEW.daily_cap_hours = 5 THEN
    RETURN NEW;
  END IF;
  SELECT (public.pro_is_active(auth.uid()) AND s.pro_plan::text LIKE 'family%')
         OR EXISTS (SELECT 1 FROM public.admin_pro_grants g WHERE g.user_id = auth.uid())
    INTO _family FROM public.user_settings s WHERE s.user_id = auth.uid();
  IF coalesce(_family, false) THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Customizing child earning rules requires PRO Family' USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS guard_child_rules_family_pro ON public.children;
CREATE TRIGGER guard_child_rules_family_pro BEFORE INSERT OR UPDATE ON public.children
FOR EACH ROW EXECUTE FUNCTION public.guard_child_rules_family_pro();