ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS pro_expires_at timestamptz;

-- Effective entitlement: is_pro AND not past the cancellation end date.
CREATE OR REPLACE FUNCTION public.pro_is_active(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_settings s
    WHERE s.user_id = _user_id
      AND s.is_pro
      AND (s.pro_expires_at IS NULL OR s.pro_expires_at > now())
  )
$$;

REVOKE ALL ON FUNCTION public.pro_is_active(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pro_is_active(uuid) TO authenticated, service_role;

-- Child inherits PRO only while the parent's family plan is still active.
CREATE OR REPLACE FUNCTION public.parent_family_pro()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.children c
    JOIN public.user_settings s ON s.user_id = c.parent_id
    WHERE c.auth_user_id = auth.uid()
      AND s.is_pro
      AND s.pro_plan::text LIKE 'family%'
      AND (s.pro_expires_at IS NULL OR s.pro_expires_at > now())
  )
$$;

REVOKE ALL ON FUNCTION public.parent_family_pro() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.parent_family_pro() TO authenticated;

-- Status a child may see about the parent's family plan (no other parent data).
CREATE OR REPLACE FUNCTION public.parent_family_pro_status()
RETURNS TABLE(active boolean, cancelling boolean, ends_at timestamptz)
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
  WHERE c.auth_user_id = auth.uid()
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.parent_family_pro_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.parent_family_pro_status() TO authenticated;