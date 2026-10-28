CREATE OR REPLACE FUNCTION public.verify_child_signup_link()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
 IF NEW.auth_user_id IS NOT NULL AND NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
  -- Trusted linkers: the handle_new_user trigger (runs during auth.users INSERT, where
  -- email_confirmed_at is not yet populated) and the service role. For these, verifying
  -- the deterministic child invitation email is sufficient proof the account came from
  -- the server-side code redemption flow.
  IF public.is_privileged_caller() OR current_user IN ('postgres', 'supabase_admin') THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=NEW.auth_user_id AND u.email='child.'||NEW.id::text||'@child.setgoals.app') THEN
    RAISE EXCEPTION 'Child linking requires a server-issued invitation account' USING ERRCODE='42501';
   END IF;
  ELSE
   -- Direct client updates must reference a fully confirmed invitation account.
   IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=NEW.auth_user_id AND u.email='child.'||NEW.id::text||'@child.setgoals.app' AND u.email_confirmed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Child linking requires a server-confirmed invitation account' USING ERRCODE='42501';
   END IF;
  END IF;
 END IF;
 RETURN NEW;
END $function$;