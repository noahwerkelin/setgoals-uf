CREATE OR REPLACE FUNCTION public.verify_child_signup_link() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.auth_user_id IS NOT NULL AND NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
  IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=NEW.auth_user_id AND u.email='child.'||NEW.id::text||'@child.setgoals.app' AND u.email_confirmed_at IS NOT NULL) THEN
   RAISE EXCEPTION 'Child linking requires a server-confirmed invitation account' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.verify_child_signup_link() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER children_verify_signup BEFORE UPDATE OF auth_user_id ON public.children FOR EACH ROW EXECUTE FUNCTION public.verify_child_signup_link();