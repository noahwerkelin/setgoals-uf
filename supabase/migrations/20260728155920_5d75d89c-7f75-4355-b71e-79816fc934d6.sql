-- has_role() is a SECURITY DEFINER helper that is currently not referenced
-- by any RLS policy or app code. Signed-in users had EXECUTE, which the
-- linter flags as a privilege-escalation surface. Restrict it to service_role
-- so it stays available for admin/server code without being reachable from
-- the PostgREST Data API by regular users.

REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM anon;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO service_role;
