REVOKE ALL ON FUNCTION public.pro_is_active(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pro_is_active(uuid) TO service_role;