
REVOKE EXECUTE ON FUNCTION public.prevent_billing_self_update() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_billing_self_insert() FROM PUBLIC, anon, authenticated;
