CREATE TABLE public.admin_pro_grants (
  user_id uuid PRIMARY KEY,
  granted_by uuid,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.admin_pro_grants TO service_role;
ALTER TABLE public.admin_pro_grants ENABLE ROW LEVEL SECURITY;
-- No policies for anon/authenticated: only privileged connections may read or write grants.

CREATE OR REPLACE FUNCTION public.enforce_admin_pro_grant()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.admin_pro_grants g WHERE g.user_id = NEW.user_id) THEN
    NEW.is_pro := true;
    NEW.pro_expires_at := NULL;
    NEW.pro_status := 'active';
    NEW.pro_since := COALESCE(NEW.pro_since, now());
  END IF;
  RETURN NEW;
END $$;

-- "zz_" prefix: runs after all other BEFORE triggers so subscription sync cannot override it.
CREATE TRIGGER zz_enforce_admin_pro_grant
BEFORE INSERT OR UPDATE ON public.user_settings
FOR EACH ROW EXECUTE FUNCTION public.enforce_admin_pro_grant();