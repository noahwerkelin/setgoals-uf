-- 1) Friendships: only the caller can be the initiating side
DROP POLICY IF EXISTS "Users can create their own friendships" ON public.friendships;
CREATE POLICY "Users can create their own friendships"
ON public.friendships
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 2) SECURITY DEFINER functions no longer executable by signed-in users.
--    They take an explicit verified user id and are callable only by service_role.
DROP FUNCTION IF EXISTS public.family_today();
CREATE FUNCTION public.family_today(_uid uuid)
RETURNS TABLE(member_id text, name text, avatar text, steps bigint, relation text, is_self boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  uid uuid := _uid;
  p_id uuid;
  today date := CURRENT_DATE;
BEGIN
  IF uid IS NULL THEN
    RETURN;
  END IF;

  SELECT c.parent_id INTO p_id FROM public.children c WHERE c.auth_user_id = uid LIMIT 1;
  IF p_id IS NULL THEN
    p_id := uid;
  END IF;

  RETURN QUERY
  SELECT
    p.id::text,
    COALESCE(NULLIF(p.display_name, ''), p.username),
    NULL::text,
    COALESCE((SELECT SUM(a.steps) FROM public.activity_steps a WHERE a.user_id = p.id AND a.day = today), 0)::bigint,
    'parent'::text,
    (p.id = uid)
  FROM public.profiles p
  WHERE p.id = p_id;

  RETURN QUERY
  SELECT
    c.id::text,
    c.name,
    c.avatar,
    COALESCE((SELECT SUM(a.steps) FROM public.activity_steps a WHERE a.user_id = c.auth_user_id AND a.day = today), 0)::bigint,
    'child'::text,
    (c.auth_user_id IS NOT NULL AND c.auth_user_id = uid)
  FROM public.children c
  WHERE c.parent_id = p_id
  ORDER BY 2;
END;
$function$;

REVOKE ALL ON FUNCTION public.family_today(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.family_today(uuid) TO service_role;

DROP FUNCTION IF EXISTS public.parent_family_pro_status();
CREATE FUNCTION public.parent_family_pro_status(_uid uuid)
RETURNS TABLE(active boolean, cancelling boolean, ends_at timestamp with time zone, environment text, status text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  WHERE _uid IS NOT NULL AND c.auth_user_id = _uid
  LIMIT 1
$function$;

REVOKE ALL ON FUNCTION public.parent_family_pro_status(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.parent_family_pro_status(uuid) TO service_role;