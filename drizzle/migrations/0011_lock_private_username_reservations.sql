REVOKE ALL ON public.username_reservations FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.username_reservations TO service_role;