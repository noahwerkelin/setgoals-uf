CREATE TABLE public.friend_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT friend_request_not_self CHECK (sender_id <> recipient_id)
);
GRANT SELECT ON public.friend_requests TO authenticated;
GRANT ALL ON public.friend_requests TO service_role;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants read requests" ON public.friend_requests FOR SELECT TO authenticated USING (auth.uid() IN (sender_id,recipient_id));
CREATE UNIQUE INDEX friend_requests_pair ON public.friend_requests (LEAST(sender_id,recipient_id), GREATEST(sender_id,recipient_id));
REVOKE INSERT, UPDATE ON public.friendships FROM authenticated, anon;
CREATE OR REPLACE FUNCTION public.add_my_friend(_friend_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid := auth.uid();
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
 IF _friend_id IS NULL OR uid=_friend_id THEN RAISE EXCEPTION 'Cannot add yourself'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=_friend_id) THEN RAISE EXCEPTION 'User not found'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(LEAST(uid,_friend_id)::text || GREATEST(uid,_friend_id)::text,0));
 IF EXISTS(SELECT 1 FROM public.friendships WHERE user_id=LEAST(uid,_friend_id) AND friend_id=GREATEST(uid,_friend_id)) THEN RETURN; END IF;
 INSERT INTO public.friend_requests(sender_id,recipient_id) VALUES(uid,_friend_id) ON CONFLICT DO NOTHING;
END $$;
CREATE OR REPLACE FUNCTION public.my_friend_requests() RETURNS TABLE(id uuid,user_id uuid,username text,name text,direction text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.id,p.id,p.username::text,COALESCE(NULLIF(p.display_name,''),p.username)::text,
 CASE WHEN r.recipient_id=auth.uid() THEN 'incoming' ELSE 'outgoing' END
 FROM public.friend_requests r JOIN public.profiles p ON p.id=CASE WHEN r.sender_id=auth.uid() THEN r.recipient_id ELSE r.sender_id END
 WHERE auth.uid() IN (r.sender_id,r.recipient_id) ORDER BY r.created_at DESC;
END $$;
CREATE OR REPLACE FUNCTION public.accept_friend_request(_request_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); req public.friend_requests%ROWTYPE;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
 SELECT * INTO req FROM public.friend_requests WHERE id=_request_id;
 IF NOT FOUND OR req.recipient_id<>uid THEN RAISE EXCEPTION 'Only the recipient can accept' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(LEAST(req.sender_id,req.recipient_id)::text || GREATEST(req.sender_id,req.recipient_id)::text,0));
 SELECT * INTO req FROM public.friend_requests WHERE id=_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request no longer available'; END IF;
 INSERT INTO public.friendships(user_id,friend_id) VALUES(LEAST(req.sender_id,req.recipient_id),GREATEST(req.sender_id,req.recipient_id)) ON CONFLICT DO NOTHING;
 DELETE FROM public.friend_requests WHERE id=req.id;
END $$;
CREATE OR REPLACE FUNCTION public.dismiss_friend_request(_request_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); req public.friend_requests%ROWTYPE;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
 SELECT * INTO req FROM public.friend_requests WHERE id=_request_id;
 IF NOT FOUND OR uid NOT IN (req.sender_id,req.recipient_id) THEN RAISE EXCEPTION 'Not your request' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(LEAST(req.sender_id,req.recipient_id)::text || GREATEST(req.sender_id,req.recipient_id)::text,0));
 DELETE FROM public.friend_requests WHERE id=_request_id AND uid IN (sender_id,recipient_id);
END $$;
CREATE OR REPLACE FUNCTION public.remove_my_friend(_friendship_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in' USING ERRCODE='42501'; END IF;
 DELETE FROM public.friendships WHERE id=_friendship_id AND auth.uid() IN (user_id,friend_id);
 IF NOT FOUND THEN RAISE EXCEPTION 'Friendship not found' USING ERRCODE='42501'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.add_my_friend(uuid),public.my_friend_requests(),public.accept_friend_request(uuid),public.dismiss_friend_request(uuid),public.remove_my_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_my_friend(uuid),public.my_friend_requests(),public.accept_friend_request(uuid),public.dismiss_friend_request(uuid),public.remove_my_friend(uuid) TO authenticated, service_role;