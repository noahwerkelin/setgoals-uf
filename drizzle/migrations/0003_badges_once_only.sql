CREATE OR REPLACE FUNCTION public.keep_badge_earned_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.earned_at := OLD.earned_at;
  NEW.badge_id := OLD.badge_id;
  NEW.user_id := OLD.user_id;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS keep_badge_earned_at ON public.user_badges;
CREATE TRIGGER keep_badge_earned_at BEFORE UPDATE ON public.user_badges
FOR EACH ROW EXECUTE FUNCTION public.keep_badge_earned_at();