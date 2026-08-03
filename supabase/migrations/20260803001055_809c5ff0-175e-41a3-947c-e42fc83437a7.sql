CREATE TABLE public.tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_id uuid NOT NULL REFERENCES public.children(id) ON DELETE CASCADE,
  child_user_id uuid,
  title text NOT NULL,
  description text,
  reward_minutes integer NOT NULL DEFAULT 30 CHECK (reward_minutes >= 0 AND reward_minutes <= 600),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','submitted','approved','rejected','expired')),
  due_date date,
  repeat_schedule text NOT NULL DEFAULT 'none' CHECK (repeat_schedule IN ('none','daily','weekly','custom')),
  repeat_interval_days integer CHECK (repeat_interval_days IS NULL OR (repeat_interval_days >= 1 AND repeat_interval_days <= 365)),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high')),
  proof_image_url text,
  proof_note text,
  rejection_reason text,
  submitted_at timestamptz,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tasks_parent_idx ON public.tasks (parent_id, status);
CREATE INDEX tasks_child_user_idx ON public.tasks (child_user_id, status);
CREATE INDEX tasks_child_idx ON public.tasks (child_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tasks TO authenticated;
GRANT ALL ON public.tasks TO service_role;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents manage their tasks"
ON public.tasks FOR ALL TO authenticated
USING (parent_id = auth.uid())
WITH CHECK (parent_id = auth.uid() AND EXISTS (
  SELECT 1 FROM public.children c WHERE c.id = tasks.child_id AND c.parent_id = auth.uid()
));

CREATE POLICY "Children view their tasks"
ON public.tasks FOR SELECT TO authenticated
USING (child_user_id = auth.uid());

CREATE POLICY "Children submit their tasks"
ON public.tasks FOR UPDATE TO authenticated
USING (child_user_id = auth.uid())
WITH CHECK (child_user_id = auth.uid());

-- Children may only move pending/rejected -> submitted and attach proof; nothing else.
CREATE OR REPLACE FUNCTION public.tasks_guard_child_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  IF auth.uid() IS NOT NULL AND auth.uid() = OLD.child_user_id AND auth.uid() <> OLD.parent_id THEN
    IF NEW.status IS DISTINCT FROM 'submitted' OR OLD.status NOT IN ('pending','rejected') THEN
      RAISE EXCEPTION 'Children can only submit pending tasks for approval';
    END IF;
    NEW.parent_id := OLD.parent_id;
    NEW.child_id := OLD.child_id;
    NEW.child_user_id := OLD.child_user_id;
    NEW.title := OLD.title;
    NEW.description := OLD.description;
    NEW.reward_minutes := OLD.reward_minutes;
    NEW.due_date := OLD.due_date;
    NEW.repeat_schedule := OLD.repeat_schedule;
    NEW.repeat_interval_days := OLD.repeat_interval_days;
    NEW.priority := OLD.priority;
    NEW.rejection_reason := NULL;
    NEW.approved_at := NULL;
    NEW.submitted_at := now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tasks_guard_child_update
BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.tasks_guard_child_update();

-- Keep child_user_id in sync with the linked child profile.
CREATE OR REPLACE FUNCTION public.tasks_set_child_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  SELECT c.auth_user_id INTO NEW.child_user_id FROM public.children c WHERE c.id = NEW.child_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tasks_set_child_user
BEFORE INSERT ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.tasks_set_child_user();

CREATE TABLE public.task_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id uuid REFERENCES public.tasks(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX task_notifications_user_idx ON public.task_notifications (user_id, created_at DESC);

GRANT SELECT, UPDATE, DELETE ON public.task_notifications TO authenticated;
GRANT ALL ON public.task_notifications TO service_role;
ALTER TABLE public.task_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their notifications"
ON public.task_notifications FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users update their notifications"
ON public.task_notifications FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users delete their notifications"
ON public.task_notifications FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- Notifications are written by triggers (security definer), never directly by clients.
CREATE OR REPLACE FUNCTION public.tasks_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  child_name text;
BEGIN
  SELECT c.name INTO child_name FROM public.children c WHERE c.id = NEW.child_id;

  IF TG_OP = 'INSERT' THEN
    IF NEW.child_user_id IS NOT NULL THEN
      INSERT INTO public.task_notifications (user_id, task_id, type, title, body)
      VALUES (NEW.child_user_id, NEW.id, 'task_assigned', NEW.title, NULL);
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'submitted' THEN
      INSERT INTO public.task_notifications (user_id, task_id, type, title, body)
      VALUES (NEW.parent_id, NEW.id, 'task_submitted', NEW.title, coalesce(child_name, '') );
    ELSIF NEW.status = 'approved' AND NEW.child_user_id IS NOT NULL THEN
      INSERT INTO public.task_notifications (user_id, task_id, type, title, body)
      VALUES (NEW.child_user_id, NEW.id, 'task_approved', NEW.title, NEW.reward_minutes::text);
    ELSIF NEW.status = 'rejected' AND NEW.child_user_id IS NOT NULL THEN
      INSERT INTO public.task_notifications (user_id, task_id, type, title, body)
      VALUES (NEW.child_user_id, NEW.id, 'task_rejected', NEW.title, NEW.rejection_reason);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.tasks_notify() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tasks_guard_child_update() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tasks_set_child_user() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER tasks_notify_insert
AFTER INSERT ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.tasks_notify();

CREATE TRIGGER tasks_notify_update
AFTER UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.tasks_notify();

ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.task_notifications;