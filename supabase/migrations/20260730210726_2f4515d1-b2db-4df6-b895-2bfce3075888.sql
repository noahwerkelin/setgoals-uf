-- Case-insensitive unique usernames on profiles
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key ON public.profiles (lower(username));

-- Availability check across profiles and children
CREATE OR REPLACE FUNCTION public.username_available(_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT _username ~ '^[a-z0-9_]{3,20}$'
    AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = lower(_username))
    AND NOT EXISTS (SELECT 1 FROM public.children WHERE lower(username) = lower(_username));
$$;

REVOKE ALL ON FUNCTION public.username_available(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.username_available(text) TO anon, authenticated, service_role;

-- Keep signup fallback from colliding with child usernames too
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  base_username TEXT;
  final_username TEXT;
  suffix INT := 0;
BEGIN
  base_username := LOWER(REGEXP_REPLACE(
    COALESCE(NEW.raw_user_meta_data->>'username',
             SPLIT_PART(COALESCE(NEW.email, 'user'), '@', 1)),
    '[^a-z0-9_]', '', 'g'));
  IF base_username IS NULL OR LENGTH(base_username) < 3 THEN
    base_username := 'user' || SUBSTRING(NEW.id::text, 1, 8);
  END IF;
  final_username := base_username;
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = final_username)
     OR EXISTS (SELECT 1 FROM public.children WHERE lower(username) = final_username) LOOP
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  END LOOP;

  INSERT INTO public.profiles (id, username, display_name, email, avatar_url, birthday)
  VALUES (
    NEW.id,
    final_username,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', final_username),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url',
    NULLIF(NEW.raw_user_meta_data->>'birthday','')::date
  );
  INSERT INTO public.user_settings (user_id) VALUES (NEW.id);
  INSERT INTO public.streaks (user_id) VALUES (NEW.id);
  INSERT INTO public.earned_balances (user_id) VALUES (NEW.id);
  RETURN NEW;
END; $function$;