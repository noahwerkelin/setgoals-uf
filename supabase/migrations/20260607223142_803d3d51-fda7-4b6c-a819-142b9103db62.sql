
-- =========================
-- ENUMS
-- =========================
CREATE TYPE public.app_role AS ENUM ('admin', 'user');
CREATE TYPE public.user_role_kind AS ENUM ('individual', 'parent', 'child');
CREATE TYPE public.step_source AS ENUM ('api', 'manual', 'healthkit', 'healthconnect');
CREATE TYPE public.theme_color AS ENUM ('sage', 'rose', 'blue', 'pink', 'lavender', 'amber', 'slate');
CREATE TYPE public.sub_plan AS ENUM ('monthly', 'yearly');
CREATE TYPE public.share_location_mode AS ENUM ('off', 'while_using', 'always');
CREATE TYPE public.units_kind AS ENUM ('metric', 'imperial');
CREATE TYPE public.restriction_kind AS ENUM ('app', 'category', 'website');

-- =========================
-- HELPERS
-- =========================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

-- =========================
-- PROFILES
-- =========================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  email TEXT,
  birthday DATE,
  role public.user_role_kind NOT NULL DEFAULT 'individual',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles self-read" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Profiles self-insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Profiles self-update" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Profiles self-delete" ON public.profiles FOR DELETE TO authenticated USING (auth.uid() = id);
CREATE TRIGGER profiles_set_updated BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- USER SETTINGS
-- =========================
CREATE TABLE public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  steps_per_30 INTEGER NOT NULL DEFAULT 1000 CHECK (steps_per_30 > 0),
  daily_cap_hours INTEGER NOT NULL DEFAULT 3 CHECK (daily_cap_hours BETWEEN 0 AND 24),
  units public.units_kind NOT NULL DEFAULT 'metric',
  push_on BOOLEAN NOT NULL DEFAULT TRUE,
  anonymous_leaderboard BOOLEAN NOT NULL DEFAULT FALSE,
  share_location public.share_location_mode NOT NULL DEFAULT 'while_using',
  theme_color public.theme_color NOT NULL DEFAULT 'sage',
  is_pro BOOLEAN NOT NULL DEFAULT FALSE,
  pro_plan public.sub_plan NOT NULL DEFAULT 'monthly',
  pro_auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  pro_since TIMESTAMPTZ,
  pro_payment_method TEXT,
  healthkit_connected BOOLEAN NOT NULL DEFAULT FALSE,
  googlefit_connected BOOLEAN NOT NULL DEFAULT FALSE,
  daily_goal INTEGER NOT NULL DEFAULT 8000 CHECK (daily_goal > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_settings TO authenticated;
GRANT ALL ON public.user_settings TO service_role;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Settings self-read" ON public.user_settings FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Settings self-insert" ON public.user_settings FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Settings self-update" ON public.user_settings FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE TRIGGER user_settings_set_updated BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- CHILDREN
-- =========================
CREATE TABLE public.children (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  birthday DATE,
  avatar TEXT,
  daily_goal INTEGER NOT NULL DEFAULT 8000 CHECK (daily_goal > 0),
  steps_per_30 INTEGER NOT NULL DEFAULT 1000 CHECK (steps_per_30 > 0),
  daily_cap_hours INTEGER NOT NULL DEFAULT 3 CHECK (daily_cap_hours BETWEEN 0 AND 24),
  code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX children_parent_idx ON public.children(parent_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.children TO authenticated;
GRANT ALL ON public.children TO service_role;
ALTER TABLE public.children ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Children parent-manage" ON public.children FOR ALL TO authenticated
  USING (auth.uid() = parent_id) WITH CHECK (auth.uid() = parent_id);
CREATE TRIGGER children_set_updated BEFORE UPDATE ON public.children
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- ACTIVITY STEPS
-- =========================
CREATE TABLE public.activity_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day DATE NOT NULL,
  steps INTEGER NOT NULL CHECK (steps >= 0 AND steps <= 200000),
  distance_km NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
  calories INTEGER NOT NULL DEFAULT 0 CHECK (calories >= 0),
  exercise_minutes INTEGER NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0),
  source public.step_source NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, day, source)
);
CREATE INDEX activity_steps_user_day_idx ON public.activity_steps(user_id, day DESC);
CREATE INDEX activity_steps_day_idx ON public.activity_steps(day DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_steps TO authenticated;
GRANT ALL ON public.activity_steps TO service_role;
ALTER TABLE public.activity_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Activity self-read" ON public.activity_steps FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Activity self-insert" ON public.activity_steps FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND source = 'manual');
CREATE POLICY "Activity self-update" ON public.activity_steps FOR UPDATE TO authenticated USING (auth.uid() = user_id AND source = 'manual');
CREATE POLICY "Activity self-delete" ON public.activity_steps FOR DELETE TO authenticated USING (auth.uid() = user_id AND source = 'manual');
CREATE TRIGGER activity_steps_set_updated BEFORE UPDATE ON public.activity_steps
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- EARNED BALANCES
-- =========================
CREATE TABLE public.earned_balances (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  day DATE NOT NULL DEFAULT CURRENT_DATE,
  earned_min INTEGER NOT NULL DEFAULT 0 CHECK (earned_min >= 0),
  consumed_min INTEGER NOT NULL DEFAULT 0 CHECK (consumed_min >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.earned_balances TO authenticated;
GRANT ALL ON public.earned_balances TO service_role;
ALTER TABLE public.earned_balances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Balance self-read" ON public.earned_balances FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Balance self-write" ON public.earned_balances FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER earned_balances_set_updated BEFORE UPDATE ON public.earned_balances
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- RESTRICTION SETTINGS
-- =========================
CREATE TABLE public.restriction_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind public.restriction_kind NOT NULL,
  identifier TEXT NOT NULL,
  label TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, identifier)
);
CREATE INDEX restriction_settings_user_idx ON public.restriction_settings(user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.restriction_settings TO authenticated;
GRANT ALL ON public.restriction_settings TO service_role;
ALTER TABLE public.restriction_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Restrictions self-manage" ON public.restriction_settings FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- =========================
-- STREAKS
-- =========================
CREATE TABLE public.streaks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
  best INTEGER NOT NULL DEFAULT 0 CHECK (best >= 0),
  last_goal_met_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.streaks TO authenticated;
GRANT ALL ON public.streaks TO service_role;
ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Streaks self-read" ON public.streaks FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Streaks self-write" ON public.streaks FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER streaks_set_updated BEFORE UPDATE ON public.streaks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================
-- USER ROLES
-- =========================
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Roles self-read" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

-- =========================
-- GDPR REQUESTS
-- =========================
CREATE TABLE public.data_export_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  download_url TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);
GRANT SELECT, INSERT ON public.data_export_requests TO authenticated;
GRANT ALL ON public.data_export_requests TO service_role;
ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Export self-read" ON public.data_export_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Export self-insert" ON public.data_export_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.account_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);
GRANT SELECT, INSERT ON public.account_deletion_requests TO authenticated;
GRANT ALL ON public.account_deletion_requests TO service_role;
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Deletion self-read" ON public.account_deletion_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Deletion self-insert" ON public.account_deletion_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- =========================
-- SIGNUP TRIGGER (auto-create profile, settings, streak)
-- =========================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  suffix INT := 0;
BEGIN
  base_username := LOWER(REGEXP_REPLACE(
    COALESCE(NEW.raw_user_meta_data->>'username',
             SPLIT_PART(COALESCE(NEW.email, 'user'), '@', 1)),
    '[^a-z0-9_]', '', 'g'));
  IF base_username IS NULL OR LENGTH(base_username) < 3 THEN
    base_username := 'user' || SUBSTRING(NEW.id::text, 1, 8);
  END IF;
  final_username := base_username;
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = final_username) LOOP
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  END LOOP;

  INSERT INTO public.profiles (id, username, display_name, email, avatar_url, birthday)
  VALUES (
    NEW.id,
    final_username,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', final_username),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url',
    NULLIF(NEW.raw_user_meta_data->>'birthday','')::date
  );
  INSERT INTO public.user_settings (user_id) VALUES (NEW.id);
  INSERT INTO public.streaks (user_id) VALUES (NEW.id);
  INSERT INTO public.earned_balances (user_id) VALUES (NEW.id);
  RETURN NEW;
END; $$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =========================
-- LEADERBOARD VIEWS (security_invoker so RLS on activity_steps applies — but we want global)
-- Use SECURITY DEFINER function approach so signed-in users can see aggregated leaderboard rows.
-- =========================
CREATE OR REPLACE FUNCTION public.leaderboard(_period TEXT)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  username TEXT,
  avatar_url TEXT,
  total_steps BIGINT,
  rank BIGINT
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  since_date DATE;
BEGIN
  -- only signed-in users may read
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  since_date := CASE _period
    WHEN 'daily'   THEN CURRENT_DATE
    WHEN 'weekly'  THEN CURRENT_DATE - INTERVAL '7 days'
    WHEN 'monthly' THEN CURRENT_DATE - INTERVAL '30 days'
    ELSE DATE '1970-01-01'
  END;

  RETURN QUERY
  WITH per_user AS (
    SELECT a.user_id, SUM(a.steps)::BIGINT AS total
    FROM public.activity_steps a
    WHERE a.day >= since_date
    GROUP BY a.user_id
  )
  SELECT
    p.id,
    CASE WHEN s.anonymous_leaderboard THEN 'Anonymous' ELSE COALESCE(NULLIF(p.display_name,''), p.username) END,
    CASE WHEN s.anonymous_leaderboard THEN '—' ELSE p.username END,
    CASE WHEN s.anonymous_leaderboard THEN NULL ELSE p.avatar_url END,
    pu.total,
    RANK() OVER (ORDER BY pu.total DESC)
  FROM per_user pu
  JOIN public.profiles p ON p.id = pu.user_id
  LEFT JOIN public.user_settings s ON s.user_id = pu.user_id
  ORDER BY pu.total DESC
  LIMIT 100;
END; $$;
GRANT EXECUTE ON FUNCTION public.leaderboard(TEXT) TO authenticated;

-- =========================
-- REALTIME
-- =========================
ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_steps;
ALTER PUBLICATION supabase_realtime ADD TABLE public.earned_balances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.streaks;
