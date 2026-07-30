
-- 1) Robust privileged-caller detection for billing guards
CREATE OR REPLACE FUNCTION public.is_privileged_caller()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  claim_role text;
BEGIN
  BEGIN
    claim_role := coalesce(
      nullif(current_setting('request.jwt.claim.role', true), ''),
      (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'role')
    );
  EXCEPTION WHEN others THEN
    claim_role := NULL;
  END;

  IF claim_role IS NOT NULL THEN
    RETURN claim_role = 'service_role';
  END IF;

  -- No PostgREST claims: direct/privileged database connection
  RETURN current_user IN ('service_role', 'postgres', 'supabase_admin');
END;
$$;

REVOKE ALL ON FUNCTION public.is_privileged_caller() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.prevent_billing_self_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_privileged_caller() THEN
    RETURN NEW;
  END IF;
  IF (NEW.is_pro IS DISTINCT FROM OLD.is_pro)
     OR (NEW.pro_plan IS DISTINCT FROM OLD.pro_plan)
     OR (NEW.pro_auto_renew IS DISTINCT FROM OLD.pro_auto_renew)
     OR (NEW.pro_since IS DISTINCT FROM OLD.pro_since)
     OR (NEW.pro_expires_at IS DISTINCT FROM OLD.pro_expires_at)
     OR (NEW.pro_payment_method IS DISTINCT FROM OLD.pro_payment_method) THEN
    RAISE EXCEPTION 'Subscription fields can only be modified by the server';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_billing_self_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_privileged_caller() THEN
    RETURN NEW;
  END IF;
  NEW.is_pro := false;
  NEW.pro_plan := 'monthly';
  NEW.pro_auto_renew := true;
  NEW.pro_since := NULL;
  NEW.pro_expires_at := NULL;
  NEW.pro_payment_method := NULL;
  RETURN NEW;
END;
$$;

-- 2) Lock down SECURITY DEFINER functions
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pro_is_active(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_billing_self_insert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_billing_self_update() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_child_limit() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.leaderboard(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_today() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.parent_family_pro() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.parent_family_pro_status() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_parent_of(uuid) FROM PUBLIC, anon;

-- 3) Caller guards on the definer functions that stay callable
CREATE OR REPLACE FUNCTION public.is_parent_of(_child_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.children c
    WHERE c.auth_user_id = _child_user_id AND c.parent_id = auth.uid()
  )
$$;

CREATE OR REPLACE FUNCTION public.parent_family_pro()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.children c
    JOIN public.user_settings s ON s.user_id = c.parent_id
    WHERE c.auth_user_id = auth.uid()
      AND s.is_pro
      AND s.pro_plan::text LIKE 'family%'
      AND (s.pro_expires_at IS NULL OR s.pro_expires_at > now())
  )
$$;

CREATE OR REPLACE FUNCTION public.parent_family_pro_status()
RETURNS TABLE(active boolean, cancelling boolean, ends_at timestamp with time zone)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (s.is_pro AND s.pro_plan::text LIKE 'family%'
      AND (s.pro_expires_at IS NULL OR s.pro_expires_at > now())) AS active,
    (s.pro_plan::text LIKE 'family%' AND s.pro_expires_at IS NOT NULL
      AND s.pro_expires_at > now()) AS cancelling,
    CASE WHEN s.pro_plan::text LIKE 'family%' THEN s.pro_expires_at END AS ends_at
  FROM public.children c
  JOIN public.user_settings s ON s.user_id = c.parent_id
  WHERE auth.uid() IS NOT NULL AND c.auth_user_id = auth.uid()
  LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.is_parent_of(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parent_family_pro() TO authenticated;
GRANT EXECUTE ON FUNCTION public.parent_family_pro_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_today() TO authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard(text) TO authenticated;
