ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS pro_environment text NOT NULL DEFAULT 'sandbox',
  ADD COLUMN IF NOT EXISTS pro_status text NOT NULL DEFAULT 'inactive';

-- Extend the server-only guard to the new billing columns.
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
     OR (NEW.pro_payment_method IS DISTINCT FROM OLD.pro_payment_method)
     OR (NEW.pro_environment IS DISTINCT FROM OLD.pro_environment)
     OR (NEW.pro_status IS DISTINCT FROM OLD.pro_status) THEN
    RAISE EXCEPTION 'Subscription fields can only be modified by the server';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_billing_self_update() FROM PUBLIC, anon, authenticated;

-- Family PRO status now reports the parent's environment and billing status too.
DROP FUNCTION IF EXISTS public.parent_family_pro_status();
CREATE FUNCTION public.parent_family_pro_status()
RETURNS TABLE(active boolean, cancelling boolean, ends_at timestamp with time zone, environment text, status text)
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
    CASE WHEN s.pro_plan::text LIKE 'family%' THEN s.pro_expires_at END AS ends_at,
    s.pro_environment AS environment,
    s.pro_status AS status
  FROM public.children c
  JOIN public.user_settings s ON s.user_id = c.parent_id
  WHERE auth.uid() IS NOT NULL AND c.auth_user_id = auth.uid()
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.parent_family_pro_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.parent_family_pro_status() TO authenticated;