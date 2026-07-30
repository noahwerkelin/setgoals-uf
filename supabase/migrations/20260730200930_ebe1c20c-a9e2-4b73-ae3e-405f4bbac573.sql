
CREATE OR REPLACE FUNCTION public.sync_child_avatar_to_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.auth_user_id IS NOT NULL
     AND (TG_OP = 'INSERT'
          OR NEW.avatar IS DISTINCT FROM OLD.avatar
          OR NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id) THEN
    UPDATE public.profiles
       SET avatar_url = NEW.avatar
     WHERE id = NEW.auth_user_id;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_child_avatar_to_profile() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS children_sync_avatar ON public.children;
CREATE TRIGGER children_sync_avatar
AFTER INSERT OR UPDATE OF avatar, auth_user_id ON public.children
FOR EACH ROW EXECUTE FUNCTION public.sync_child_avatar_to_profile();

-- Backfill existing linked children
UPDATE public.profiles p
   SET avatar_url = c.avatar
  FROM public.children c
 WHERE c.auth_user_id = p.id
   AND c.avatar IS NOT NULL
   AND p.avatar_url IS DISTINCT FROM c.avatar;
