-- Permission matrix (extends stage 1)
CREATE OR REPLACE FUNCTION public.admin_can(_perm text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.admin_roles a WHERE a.user_id=auth.uid() AND (
      a.role='super_admin'
      OR (a.role='admin' AND _perm IN ('overview','analytics','users','history','user_edit','support','subs_view','subs_edit','announcements','challenges','calendar','audit'))
      OR (a.role='support_admin' AND _perm IN ('users','history','support','subs_view'))
      OR (a.role='marketing_admin' AND _perm IN ('overview','analytics','announcements','ads','challenges','calendar'))))
$$;

CREATE OR REPLACE FUNCTION public.admin_can_write(_perm text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT public.admin_can(_perm) AND coalesce(auth.jwt()->>'aal','') = 'aal2'
$$;

CREATE OR REPLACE FUNCTION public.admin_require_write(_perm text, _action text, _target uuid DEFAULT NULL, _details jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.admin_can(_perm) THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  IF coalesce(auth.jwt()->>'aal','') <> 'aal2' THEN RAISE EXCEPTION 'MFA required' USING ERRCODE='42501'; END IF;
  INSERT INTO public.admin_audit_log(actor_id, action, target_user_id, details, aal)
  VALUES (auth.uid(), _action, _target, coalesce(_details,'{}'::jsonb), auth.jwt()->>'aal');
END $$;
REVOKE ALL ON FUNCTION public.admin_require_write(text,text,uuid,jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_audit_row()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE n jsonb; o jsonb; changed text[]; tgt uuid;
BEGIN
  n := CASE WHEN TG_OP='DELETE' THEN NULL ELSE to_jsonb(NEW) END;
  o := CASE WHEN TG_OP='INSERT' THEN NULL ELSE to_jsonb(OLD) END;
  IF TG_OP='UPDATE' THEN
    SELECT array_agg(k) INTO changed FROM jsonb_object_keys(n) k WHERE n->k IS DISTINCT FROM o->k AND k NOT IN ('updated_at');
  END IF;
  tgt := nullif(coalesce(n,o)->>'user_id','')::uuid;
  INSERT INTO public.admin_audit_log(actor_id, action, target_user_id, details, aal)
  VALUES (coalesce(auth.uid(),'00000000-0000-0000-0000-000000000000'::uuid), TG_TABLE_NAME||'.'||lower(TG_OP), tgt,
    jsonb_build_object('record_id', coalesce(n,o)->>'id', 'changed', to_jsonb(changed),
      'status', n->>'status', 'previous_status', o->>'status',
      'previous', CASE WHEN TG_TABLE_NAME='admin_support_notes' AND TG_OP<>'INSERT' THEN o ELSE NULL END),
    auth.jwt()->>'aal');
  RETURN coalesce(NEW, OLD);
END $$;
REVOKE ALL ON FUNCTION public.admin_audit_row() FROM PUBLIC, anon, authenticated;

CREATE TABLE public.admin_account_flags (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','flagged','suspended')),
  note text,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.admin_account_flags TO authenticated;
GRANT ALL ON public.admin_account_flags TO service_role;
ALTER TABLE public.admin_account_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read account flags" ON public.admin_account_flags FOR SELECT TO authenticated USING (public.admin_can('users'));

CREATE TABLE public.admin_support_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  author_id uuid NOT NULL DEFAULT auth.uid(),
  category text NOT NULL DEFAULT 'general' CHECK (category IN ('general','technical','subscription','family','screen_time','account_access','other')),
  content text NOT NULL CHECK (length(content) BETWEEN 1 AND 5000),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','archived')),
  important boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_support_notes_user_idx ON public.admin_support_notes(user_id, created_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_support_notes TO authenticated;
GRANT ALL ON public.admin_support_notes TO service_role;
ALTER TABLE public.admin_support_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Support reads notes" ON public.admin_support_notes FOR SELECT TO authenticated USING (public.admin_can('support'));
CREATE POLICY "Support adds notes" ON public.admin_support_notes FOR INSERT TO authenticated WITH CHECK (public.admin_can_write('support') AND author_id = auth.uid());
CREATE POLICY "Authors or admins edit notes" ON public.admin_support_notes FOR UPDATE TO authenticated
  USING (public.admin_can_write('support') AND (author_id = auth.uid() OR public.admin_can('user_edit')))
  WITH CHECK (public.admin_can_write('support'));
CREATE POLICY "Super admins delete notes" ON public.admin_support_notes FOR DELETE TO authenticated USING (public.admin_can_write('admin_manage'));
CREATE TRIGGER admin_support_notes_updated BEFORE UPDATE ON public.admin_support_notes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER admin_support_notes_audit AFTER INSERT OR UPDATE OR DELETE ON public.admin_support_notes FOR EACH ROW EXECUTE FUNCTION public.admin_audit_row();

CREATE TABLE public.promotional_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan text NOT NULL CHECK (plan IN ('pro','pro_family')),
  starts_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  granted_by uuid NOT NULL,
  reason text NOT NULL,
  revoked_at timestamptz,
  revoked_by uuid,
  revoke_reason text,
  applied_to_settings boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX promotional_entitlements_user_idx ON public.promotional_entitlements(user_id, expires_at DESC);
GRANT SELECT ON public.promotional_entitlements TO authenticated;
GRANT ALL ON public.promotional_entitlements TO service_role;
ALTER TABLE public.promotional_entitlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read promos" ON public.promotional_entitlements FOR SELECT TO authenticated USING (public.admin_can('subs_view'));
CREATE POLICY "Users read own promos" ON public.promotional_entitlements FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE TABLE public.app_activity_days (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  day date NOT NULL,
  opens integer NOT NULL DEFAULT 1,
  app_version text,
  platform text,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);
CREATE INDEX app_activity_days_day_idx ON public.app_activity_days(day);
GRANT SELECT ON public.app_activity_days TO authenticated;
GRANT ALL ON public.app_activity_days TO service_role;
ALTER TABLE public.app_activity_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own app activity readable" ON public.app_activity_days FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.record_app_open(_app_version text DEFAULT NULL, _platform text DEFAULT 'ios')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO app_activity_days(user_id, day, app_version, platform)
  VALUES (auth.uid(), CURRENT_DATE, left(_app_version,20), left(_platform,20))
  ON CONFLICT (user_id, day) DO UPDATE SET opens = app_activity_days.opens + 1, last_seen_at = now(),
    app_version = coalesce(EXCLUDED.app_version, app_activity_days.app_version);
END $$;

CREATE TABLE public.app_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internal_name text NOT NULL,
  kind text NOT NULL DEFAULT 'general' CHECK (kind IN ('important','maintenance','service_interruption','new_feature','app_update','general','custom')),
  content jsonb NOT NULL DEFAULT '{"sv":{},"en":{}}'::jsonb,
  style jsonb NOT NULL DEFAULT '{}'::jsonb,
  display_mode text NOT NULL DEFAULT 'once_per_user' CHECK (display_mode IN ('once_per_user','once_per_session','until_dismissed','every_launch')),
  requires_ack boolean NOT NULL DEFAULT false,
  dismissible boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  targeting jsonb NOT NULL DEFAULT '{"audiences":["all"]}'::jsonb,
  min_app_version text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','published','paused','archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  timezone text NOT NULL DEFAULT 'Europe/Stockholm',
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT announcement_dates CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at),
  CONSTRAINT announcement_promo_dismissible CHECK (dismissible OR kind IN ('important','maintenance','service_interruption','app_update'))
);
CREATE INDEX app_announcements_window_idx ON public.app_announcements(status, starts_at, ends_at);

CREATE TABLE public.app_advertisements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internal_name text NOT NULL,
  sponsor_name text NOT NULL,
  template text NOT NULL DEFAULT 'centered_logo' CHECK (template IN ('fullscreen_image','centered_logo','image_bottom_text','gradient_illustration','minimal')),
  content jsonb NOT NULL DEFAULT '{"sv":{},"en":{}}'::jsonb,
  style jsonb NOT NULL DEFAULT '{}'::jsonb,
  cta_url text CHECK (cta_url IS NULL OR cta_url ~ '^https://'),
  secondary_url text CHECK (secondary_url IS NULL OR secondary_url ~ '^https://'),
  priority integer NOT NULL DEFAULT 4 CHECK (priority BETWEEN 1 AND 10),
  targeting jsonb NOT NULL DEFAULT '{"audiences":["all"]}'::jsonb,
  min_app_version text,
  max_per_day integer NOT NULL DEFAULT 1 CHECK (max_per_day BETWEEN 1 AND 5),
  min_minutes_between integer NOT NULL DEFAULT 240 CHECK (min_minutes_between >= 30),
  max_total_per_user integer CHECK (max_total_per_user IS NULL OR max_total_per_user >= 1),
  once_per_campaign boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','active','paused','expired','archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  timezone text NOT NULL DEFAULT 'Europe/Stockholm',
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ad_dates CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);
CREATE INDEX app_advertisements_window_idx ON public.app_advertisements(status, starts_at, ends_at);

CREATE TABLE public.sponsored_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internal_name text NOT NULL,
  content jsonb NOT NULL DEFAULT '{"sv":{},"en":{}}'::jsonb,
  sponsor_name text,
  sponsor_logo_url text,
  sponsor_url text CHECK (sponsor_url IS NULL OR sponsor_url ~ '^https://'),
  style jsonb NOT NULL DEFAULT '{}'::jsonb,
  sponsored_label boolean NOT NULL DEFAULT true,
  metric text NOT NULL CHECK (metric IN ('steps','distance_km','active_days','exercise_minutes')),
  target integer NOT NULL CHECK (target > 0),
  reward_minutes integer NOT NULL DEFAULT 0 CHECK (reward_minutes BETWEEN 0 AND 240),
  reward_badge_id text,
  max_claims integer CHECK (max_claims IS NULL OR max_claims > 0),
  join_mode text NOT NULL DEFAULT 'manual' CHECK (join_mode IN ('manual','automatic')),
  eligibility jsonb NOT NULL DEFAULT '{"audiences":["all"]}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','visible','active','completed','paused','archived')),
  visible_at timestamptz,
  join_opens_at timestamptz,
  join_closes_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  removed_at timestamptz,
  timezone text NOT NULL DEFAULT 'Europe/Stockholm',
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT challenge_dates CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);
CREATE INDEX sponsored_challenges_window_idx ON public.sponsored_challenges(status, visible_at, removed_at);

CREATE TABLE public.sponsored_challenge_participants (
  challenge_id uuid NOT NULL REFERENCES public.sponsored_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  PRIMARY KEY (challenge_id, user_id)
);
CREATE TABLE public.sponsored_challenge_rewards (
  challenge_id uuid NOT NULL REFERENCES public.sponsored_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  minutes integer NOT NULL DEFAULT 0,
  badge_id text,
  granted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, user_id)
);
CREATE TABLE public.campaign_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_type text NOT NULL CHECK (campaign_type IN ('announcement','advertisement','sponsored_challenge')),
  campaign_id uuid NOT NULL,
  user_id uuid NOT NULL,
  event text NOT NULL CHECK (event IN ('eligible','displayed','dismissed','acknowledged','cta_click','secondary_click')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX campaign_events_campaign_idx ON public.campaign_events(campaign_type, campaign_id, event);
CREATE INDEX campaign_events_user_idx ON public.campaign_events(user_id, campaign_id, created_at DESC);

CREATE TABLE public.admin_preferences (
  user_id uuid PRIMARY KEY DEFAULT auth.uid(),
  prefs jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_announcements, public.app_advertisements, public.sponsored_challenges, public.admin_preferences TO authenticated;
GRANT SELECT ON public.sponsored_challenge_participants, public.sponsored_challenge_rewards, public.campaign_events TO authenticated;
GRANT ALL ON public.app_announcements, public.app_advertisements, public.sponsored_challenges, public.sponsored_challenge_participants, public.sponsored_challenge_rewards, public.campaign_events, public.admin_preferences TO service_role;
ALTER TABLE public.app_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_advertisements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsored_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsored_challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsored_challenge_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read announcements" ON public.app_announcements FOR SELECT TO authenticated USING (public.admin_can('announcements') OR public.admin_can('calendar'));
CREATE POLICY "Admins create announcements" ON public.app_announcements FOR INSERT TO authenticated WITH CHECK (public.admin_can_write('announcements'));
CREATE POLICY "Admins edit announcements" ON public.app_announcements FOR UPDATE TO authenticated USING (public.admin_can_write('announcements')) WITH CHECK (public.admin_can_write('announcements'));
CREATE POLICY "Super admins delete announcements" ON public.app_announcements FOR DELETE TO authenticated USING (public.admin_can_write('admin_manage'));

CREATE POLICY "Admins read ads" ON public.app_advertisements FOR SELECT TO authenticated USING (public.admin_can('ads') OR public.admin_can('calendar'));
CREATE POLICY "Admins create ads" ON public.app_advertisements FOR INSERT TO authenticated WITH CHECK (public.admin_can_write('ads'));
CREATE POLICY "Admins edit ads" ON public.app_advertisements FOR UPDATE TO authenticated USING (public.admin_can_write('ads')) WITH CHECK (public.admin_can_write('ads'));
CREATE POLICY "Super admins delete ads" ON public.app_advertisements FOR DELETE TO authenticated USING (public.admin_can_write('admin_manage'));

CREATE POLICY "Admins read challenges" ON public.sponsored_challenges FOR SELECT TO authenticated USING (public.admin_can('challenges') OR public.admin_can('calendar'));
CREATE POLICY "Admins create challenges" ON public.sponsored_challenges FOR INSERT TO authenticated WITH CHECK (public.admin_can_write('challenges'));
CREATE POLICY "Admins edit challenges" ON public.sponsored_challenges FOR UPDATE TO authenticated USING (public.admin_can_write('challenges')) WITH CHECK (public.admin_can_write('challenges'));
CREATE POLICY "Super admins delete challenges" ON public.sponsored_challenges FOR DELETE TO authenticated USING (public.admin_can_write('admin_manage'));

CREATE POLICY "Own participation readable" ON public.sponsored_challenge_participants FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.admin_can('history'));
CREATE POLICY "Own rewards readable" ON public.sponsored_challenge_rewards FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.admin_can('history'));
CREATE POLICY "Own campaign events readable" ON public.campaign_events FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Own admin prefs" ON public.admin_preferences FOR ALL TO authenticated
  USING (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.admin_roles r WHERE r.user_id = auth.uid()))
  WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.admin_roles r WHERE r.user_id = auth.uid()));

CREATE TRIGGER app_announcements_updated BEFORE UPDATE ON public.app_announcements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER app_advertisements_updated BEFORE UPDATE ON public.app_advertisements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER sponsored_challenges_updated BEFORE UPDATE ON public.sponsored_challenges FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER admin_preferences_updated BEFORE UPDATE ON public.admin_preferences FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER app_announcements_audit AFTER INSERT OR UPDATE OR DELETE ON public.app_announcements FOR EACH ROW EXECUTE FUNCTION public.admin_audit_row();
CREATE TRIGGER app_advertisements_audit AFTER INSERT OR UPDATE OR DELETE ON public.app_advertisements FOR EACH ROW EXECUTE FUNCTION public.admin_audit_row();
CREATE TRIGGER sponsored_challenges_audit AFTER INSERT OR UPDATE OR DELETE ON public.sponsored_challenges FOR EACH ROW EXECUTE FUNCTION public.admin_audit_row();

CREATE OR REPLACE FUNCTION public.prevent_billing_self_update()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF public.is_privileged_caller() OR current_setting('app.admin_write', true) = '1' THEN
    RETURN NEW;
  END IF;
  IF (NEW.is_pro IS DISTINCT FROM OLD.is_pro)
     OR (NEW.pro_plan IS DISTINCT FROM OLD.pro_plan)
     OR (NEW.pro_auto_renew IS DISTINCT FROM OLD.pro_auto_renew)
     OR (NEW.pro_since IS DISTINCT FROM OLD.pro_since)
     OR (NEW.pro_expires_at IS DISTINCT FROM OLD.pro_expires_at)
     OR (NEW.pro_payment_method IS DISTINCT FROM OLD.pro_payment_method)
     OR (NEW.pro_environment IS DISTINCT FROM OLD.pro_environment)
     OR (NEW.pro_status IS DISTINCT FROM OLD.pro_status) THEN
    RAISE EXCEPTION 'Subscription fields can only be modified by the server';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.guard_personal_earning_rules()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $function$
BEGIN
  IF auth.role() = 'service_role' OR auth.uid() IS NULL OR current_setting('app.admin_write', true) = '1' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.steps_per_30 IS DISTINCT FROM 1000 OR NEW.daily_cap_hours IS DISTINCT FROM 5 THEN
      RAISE EXCEPTION 'Personal earning rules require an active PRO subscription' USING ERRCODE = '42501';
    END IF;
  ELSIF NEW.steps_per_30 IS DISTINCT FROM OLD.steps_per_30
     OR NEW.daily_cap_hours IS DISTINCT FROM OLD.daily_cap_hours THEN
    IF NOT OLD.is_pro OR (OLD.pro_expires_at IS NOT NULL AND OLD.pro_expires_at <= now())
       OR EXISTS (SELECT 1 FROM public.children WHERE auth_user_id = auth.uid()) THEN
      RAISE EXCEPTION 'Personal earning rules require an active PRO subscription' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.record_app_open(text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_app_open(text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_can_write(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_can_write(text) TO authenticated;