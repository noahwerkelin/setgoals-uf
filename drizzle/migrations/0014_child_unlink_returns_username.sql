CREATE OR REPLACE FUNCTION public.reserve_account_username() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE owner uuid; reserved uuid; old_owner uuid;
BEGIN
 IF TG_TABLE_NAME='children' THEN
  owner:=coalesce(NEW.auth_user_id,NEW.id);
  IF TG_OP='UPDATE' AND NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
   IF coalesce(auth.role(),'') NOT IN ('','service_role') THEN RAISE EXCEPTION 'Child account linking requires trusted server' USING ERRCODE='42501'; END IF;
   old_owner:=coalesce(OLD.auth_user_id,OLD.id);
   UPDATE public.username_reservations SET owner_id=owner WHERE owner_id=old_owner;
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

-- Return reservations held by vanished child accounts to their child profile.
UPDATE public.username_reservations r SET owner_id=c.id
FROM public.children c
WHERE r.username=lower(c.username) AND r.owner_id<>c.id
  AND NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=r.owner_id)
  AND NOT EXISTS(SELECT 1 FROM public.children c2 WHERE c2.id=r.owner_id);

UPDATE public.children c SET auth_user_id=NULL, invitation_status='pending'
WHERE auth_user_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=c.auth_user_id);