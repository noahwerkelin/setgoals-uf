REVOKE ALL ON FUNCTION public.is_parent_of(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parent_family_pro() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_parent_of(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.parent_family_pro() TO service_role;