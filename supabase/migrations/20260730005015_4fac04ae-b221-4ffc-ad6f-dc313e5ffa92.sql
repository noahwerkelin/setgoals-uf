CREATE OR REPLACE FUNCTION public.family_today()
RETURNS TABLE(member_id text, name text, avatar text, steps bigint, relation text, is_self boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
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
$$;

REVOKE ALL ON FUNCTION public.family_today() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.family_today() TO authenticated;