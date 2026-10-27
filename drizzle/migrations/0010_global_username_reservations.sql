LOCK TABLE public.profiles, public.children IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM (SELECT lower(username) AS name,id AS owner FROM public.profiles UNION ALL SELECT lower(username),coalesce(auth_user_id,id) FROM public.children WHERE username IS NOT NULL) u GROUP BY name HAVING count(DISTINCT owner)>1) THEN
  RAISE EXCEPTION 'Existing username conflicts require manual resolution; no accounts were changed';
 END IF;
END $$;
CREATE TABLE public.username_reservations (username text PRIMARY KEY, owner_id uuid NOT NULL);
GRANT ALL ON public.username_reservations TO service_role;
ALTER TABLE public.username_reservations ENABLE ROW LEVEL SECURITY;
INSERT INTO public.username_reservations(username,owner_id)
SELECT lower(username),id FROM public.profiles
UNION SELECT lower(username),coalesce(auth_user_id,id) FROM public.children WHERE username IS NOT NULL;
CREATE OR REPLACE FUNCTION public.username_is_valid(_username text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public AS $$ SELECT coalesce(_username ~ '^[a-zA-Z0-9_]{3,20}$',false) $$;
REVOKE ALL ON FUNCTION public.username_is_valid(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.username_is_valid(text) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.reserve_account_username() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE owner uuid; reserved uuid; old_owner uuid;
BEGIN
 IF TG_TABLE_NAME='children' THEN
  owner:=coalesce(NEW.auth_user_id,NEW.id);
  IF TG_OP='UPDATE' AND NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
   IF coalesce(auth.role(),'') NOT IN ('','service_role') THEN RAISE EXCEPTION 'Child account linking requires trusted server' USING ERRCODE='42501'; END IF;
   old_owner:=coalesce(OLD.auth_user_id,OLD.id);
   IF OLD.auth_user_id IS NULL AND NEW.auth_user_id IS NOT NULL THEN
    UPDATE public.username_reservations SET owner_id=owner WHERE owner_id=old_owner;
   END IF;
  END IF;
 ELSE owner:=NEW.id;
 END IF;
 IF TG_OP='INSERT' OR NEW.username IS DISTINCT FROM OLD.username THEN
  IF NOT public.username_is_valid(NEW.username) THEN RAISE EXCEPTION 'username_invalid' USING ERRCODE='23514'; END IF;
  NEW.username:=lower(NEW.username);
 END IF;
 IF NEW.username IS NOT NULL THEN
  INSERT INTO public.username_reservations(username,owner_id) VALUES(lower(NEW.username),owner)
  ON CONFLICT(username) DO UPDATE SET owner_id=EXCLUDED.owner_id
   WHERE public.username_reservations.owner_id=EXCLUDED.owner_id
  RETURNING owner_id INTO reserved;
  IF reserved IS NULL THEN RAISE EXCEPTION 'username_taken' USING ERRCODE='23505'; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.reserve_account_username() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER profiles_reserve_username BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.reserve_account_username();
CREATE TRIGGER children_reserve_username BEFORE INSERT OR UPDATE ON public.children FOR EACH ROW EXECUTE FUNCTION public.reserve_account_username();
CREATE OR REPLACE FUNCTION public.sync_account_username() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE old_owner uuid;
BEGIN
 IF TG_OP<>'DELETE' THEN
  IF TG_TABLE_NAME='children' THEN
   IF NEW.auth_user_id IS NOT NULL THEN UPDATE public.profiles SET username=NEW.username WHERE id=NEW.auth_user_id AND username IS DISTINCT FROM NEW.username; END IF;
  ELSE
   UPDATE public.children SET username=NEW.username WHERE auth_user_id=NEW.id AND username IS DISTINCT FROM NEW.username;
  END IF;
 END IF;
 IF TG_OP<>'INSERT' AND OLD.username IS NOT NULL THEN
  IF TG_TABLE_NAME='children' THEN old_owner:=coalesce(OLD.auth_user_id,OLD.id); ELSE old_owner:=OLD.id; END IF;
  DELETE FROM public.username_reservations r WHERE r.username=lower(OLD.username) AND r.owner_id=old_owner
   AND NOT EXISTS(SELECT 1 FROM public.profiles p WHERE lower(p.username)=r.username AND p.id=r.owner_id)
   AND NOT EXISTS(SELECT 1 FROM public.children c WHERE lower(c.username)=r.username AND coalesce(c.auth_user_id,c.id)=r.owner_id);
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sync_account_username() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER profiles_sync_username AFTER INSERT OR UPDATE OF username OR DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.sync_account_username();
CREATE TRIGGER children_sync_username AFTER INSERT OR UPDATE OF username,auth_user_id OR DELETE ON public.children FOR EACH ROW EXECUTE FUNCTION public.sync_account_username();
CREATE OR REPLACE FUNCTION public.username_available(_username text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.username_is_valid(_username) AND NOT EXISTS(SELECT 1 FROM public.username_reservations WHERE username=lower(_username));
$$;
REVOKE ALL ON FUNCTION public.username_available(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.username_available(text) TO service_role;
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE final_username text; child_id uuid; child_row public.children;
BEGIN
 IF coalesce(NEW.email,'') ~ '^child\.[0-9a-f-]{36}@child\.setgoals\.app$' THEN
  child_id:=substring(NEW.email from 7 for 36)::uuid;
  SELECT * INTO child_row FROM public.children WHERE id=child_id FOR UPDATE;
  IF child_row.id IS NULL OR child_row.auth_user_id IS NOT NULL OR child_row.invitation_expires_at<=now() THEN RAISE EXCEPTION 'Invalid child invitation'; END IF;
  final_username:=child_row.username;
  IF NOT public.username_is_valid(final_username) THEN RAISE EXCEPTION 'username_invalid' USING ERRCODE='23514'; END IF;
  UPDATE public.children SET auth_user_id=NEW.id WHERE id=child_id;
 ELSE
  final_username:=lower(NEW.raw_user_meta_data->>'username');
  IF final_username IS NULL THEN final_username:='user'||substring(NEW.id::text from 1 for 8); END IF;
  IF NOT public.username_is_valid(final_username) THEN RAISE EXCEPTION 'username_invalid' USING ERRCODE='23514'; END IF;
 END IF;
 INSERT INTO public.profiles(id,username,display_name,email,avatar_url,birthday,country_code,region)
 VALUES(NEW.id,final_username,coalesce(NEW.raw_user_meta_data->>'display_name',NEW.raw_user_meta_data->>'full_name',final_username),NEW.email,NEW.raw_user_meta_data->>'avatar_url',nullif(NEW.raw_user_meta_data->>'birthday','')::date,coalesce(NEW.raw_user_meta_data->>'country_code','SE'),coalesce(NEW.raw_user_meta_data->>'region','Stockholms län'));
 INSERT INTO public.user_settings(user_id) VALUES(NEW.id);
 INSERT INTO public.streaks(user_id) VALUES(NEW.id);
 INSERT INTO public.earned_balances(user_id) VALUES(NEW.id);
 RETURN NEW;
END $$;