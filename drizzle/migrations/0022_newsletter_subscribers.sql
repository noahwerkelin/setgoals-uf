CREATE TABLE public.newsletter_subscribers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  lang text NOT NULL DEFAULT 'sv' CHECK (lang IN ('sv', 'en')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT newsletter_email_valid CHECK (
    email = lower(btrim(email)) AND char_length(email) <= 254
    AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  )
);
GRANT ALL ON TABLE public.newsletter_subscribers TO service_role;
REVOKE ALL ON TABLE public.newsletter_subscribers FROM PUBLIC, anon, authenticated;
ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;
CREATE INDEX newsletter_subscribers_created_at_idx ON public.newsletter_subscribers (created_at DESC);

CREATE FUNCTION public.newsletter_subscribe(_email text, _lang text DEFAULT 'sv')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_email text := lower(btrim(_email));
BEGIN
  IF normalized_email IS NULL OR char_length(normalized_email) > 254
    OR normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'Invalid email address' USING ERRCODE = '22023';
  END IF;
  IF _lang IS NULL OR _lang NOT IN ('sv', 'en') THEN
    RAISE EXCEPTION 'Invalid language' USING ERRCODE = '22023';
  END IF;
  -- Serialize public sign-ups so concurrent requests cannot exceed the global limit.
  PERFORM pg_advisory_xact_lock(724615390218::bigint);
  IF (SELECT count(*) FROM public.newsletter_subscribers
      WHERE created_at > clock_timestamp() - interval '1 hour') >= 200 THEN
    -- Apply equally to new and existing addresses: no membership disclosure.
    RAISE EXCEPTION 'Newsletter sign-ups temporarily unavailable; try again later'
      USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.newsletter_subscribers (email, lang)
  VALUES (normalized_email, _lang)
  ON CONFLICT (email) DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION public.newsletter_subscribe(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.newsletter_subscribe(text, text) TO anon, authenticated;

CREATE FUNCTION public.admin_newsletter_subscribers()
RETURNS TABLE(email text, lang text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.admin_require('user_edit', 'newsletter_list');
  RETURN QUERY SELECT n.email, n.lang, n.created_at
    FROM public.newsletter_subscribers AS n ORDER BY n.created_at DESC, n.id DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_newsletter_subscribers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_newsletter_subscribers() TO authenticated;
