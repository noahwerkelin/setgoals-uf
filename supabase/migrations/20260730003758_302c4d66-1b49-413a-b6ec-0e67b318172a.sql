ALTER TABLE public.children ADD COLUMN IF NOT EXISTS username text;
CREATE UNIQUE INDEX IF NOT EXISTS children_username_lower_key ON public.children (lower(username)) WHERE username IS NOT NULL;