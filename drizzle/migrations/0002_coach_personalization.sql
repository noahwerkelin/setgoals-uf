CREATE TABLE public.coach_profiles (
  user_id uuid PRIMARY KEY,
  main_goal text NOT NULL DEFAULT 'balance' CHECK (main_goal IN ('walk_more','reduce_screen','consistency','balance')),
  coaching_style text NOT NULL DEFAULT 'supportive' CHECK (coaching_style IN ('supportive','direct','analytical','playful')),
  personal_target text NOT NULL DEFAULT '' CHECK (char_length(personal_target) <= 200),
  preferences jsonb NOT NULL DEFAULT '[]'::jsonb,
  strategies jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.coach_profiles TO authenticated;
GRANT ALL ON public.coach_profiles TO service_role;
ALTER TABLE public.coach_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coach profile own" ON public.coach_profiles FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.coach_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('user','assistant')),
  content text NOT NULL CHECK (char_length(content) <= 8000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX coach_messages_user_idx ON public.coach_messages(user_id, created_at DESC);
GRANT SELECT, INSERT, DELETE ON public.coach_messages TO authenticated;
GRANT ALL ON public.coach_messages TO service_role;
ALTER TABLE public.coach_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coach messages own" ON public.coach_messages FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.coach_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL CHECK (char_length(title) <= 120),
  reason text NOT NULL DEFAULT '' CHECK (char_length(reason) <= 400),
  metric text NOT NULL CHECK (metric IN ('daily_steps','goal_days','total_steps')),
  target integer NOT NULL CHECK (target > 0 AND target <= 300000),
  days integer NOT NULL CHECK (days BETWEEN 1 AND 14),
  start_day date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','dismissed','expired')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX coach_challenges_user_idx ON public.coach_challenges(user_id, created_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.coach_challenges TO authenticated;
GRANT ALL ON public.coach_challenges TO service_role;
ALTER TABLE public.coach_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coach challenges own" ON public.coach_challenges FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.coach_insights (
  user_id uuid NOT NULL,
  day date NOT NULL,
  input_hash text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.coach_insights TO authenticated;
GRANT ALL ON public.coach_insights TO service_role;
ALTER TABLE public.coach_insights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coach insights own" ON public.coach_insights FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);