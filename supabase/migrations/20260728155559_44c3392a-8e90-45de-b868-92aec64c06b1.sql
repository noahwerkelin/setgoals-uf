
-- 1. Block direct client updates to billing/subscription columns on user_settings
CREATE OR REPLACE FUNCTION public.prevent_billing_self_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role bypasses RLS/triggers when the session_user is service_role;
  -- for authenticated user sessions, reject any change to billing columns.
  IF current_setting('request.jwt.claim.role', true) IN ('service_role') THEN
    RETURN NEW;
  END IF;
  IF (NEW.is_pro IS DISTINCT FROM OLD.is_pro)
     OR (NEW.pro_plan IS DISTINCT FROM OLD.pro_plan)
     OR (NEW.pro_auto_renew IS DISTINCT FROM OLD.pro_auto_renew)
     OR (NEW.pro_since IS DISTINCT FROM OLD.pro_since)
     OR (NEW.pro_payment_method IS DISTINCT FROM OLD.pro_payment_method) THEN
    RAISE EXCEPTION 'Subscription fields can only be modified by the server';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_billing_self_update ON public.user_settings;
CREATE TRIGGER trg_prevent_billing_self_update
BEFORE UPDATE ON public.user_settings
FOR EACH ROW EXECUTE FUNCTION public.prevent_billing_self_update();

-- Also block INSERT with pro flags set (initial row is created by handle_new_user trigger with defaults)
CREATE OR REPLACE FUNCTION public.prevent_billing_self_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('request.jwt.claim.role', true) IN ('service_role') THEN
    RETURN NEW;
  END IF;
  NEW.is_pro := false;
  NEW.pro_plan := 'monthly';
  NEW.pro_auto_renew := true;
  NEW.pro_since := NULL;
  NEW.pro_payment_method := NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_billing_self_insert ON public.user_settings;
CREATE TRIGGER trg_prevent_billing_self_insert
BEFORE INSERT ON public.user_settings
FOR EACH ROW EXECUTE FUNCTION public.prevent_billing_self_insert();

-- 2. Add self-scoped DELETE policy on user_settings
CREATE POLICY "Settings self-delete"
ON public.user_settings
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 3. Lock down leaderboard() SECURITY DEFINER function to service_role only
REVOKE EXECUTE ON FUNCTION public.leaderboard(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard(text) TO service_role;
