ALTER TYPE public.sub_plan ADD VALUE IF NOT EXISTS 'family_monthly';
ALTER TYPE public.sub_plan ADD VALUE IF NOT EXISTS 'family_yearly';

CREATE OR REPLACE FUNCTION public.enforce_child_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (SELECT COUNT(*) FROM public.children c WHERE c.parent_id = NEW.parent_id AND c.id <> NEW.id) >= 5 THEN
    RAISE EXCEPTION 'You can add a maximum of 5 children per account.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS children_max_five ON public.children;
CREATE TRIGGER children_max_five
BEFORE INSERT OR UPDATE OF parent_id ON public.children
FOR EACH ROW EXECUTE FUNCTION public.enforce_child_limit();

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
  )
$$;

REVOKE ALL ON FUNCTION public.parent_family_pro() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.parent_family_pro() TO authenticated;