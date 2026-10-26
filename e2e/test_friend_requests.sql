-- Run through the privileged database tool; every test mutation is rolled back.
BEGIN;
DO $$
DECLARE a uuid; b uuid; c uuid; req uuid; friendship uuid; n integer;
BEGIN
 SELECT id INTO a FROM public.profiles ORDER BY id LIMIT 1;
 SELECT id INTO b FROM public.profiles WHERE id<>a ORDER BY id LIMIT 1;
 SELECT id INTO c FROM public.profiles WHERE id NOT IN (a,b) ORDER BY id LIMIT 1;
 IF c IS NULL THEN RAISE EXCEPTION 'Three profiles required for authorization tests'; END IF;
 DELETE FROM public.friendships WHERE user_id=LEAST(a,b) AND friend_id=GREATEST(a,b);
 DELETE FROM public.friend_requests WHERE LEAST(sender_id,recipient_id)=LEAST(a,b) AND GREATEST(sender_id,recipient_id)=GREATEST(a,b);
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 PERFORM public.add_my_friend(b);
 PERFORM public.add_my_friend(b);
 SELECT count(*), min(id::text)::uuid INTO n,req FROM public.friend_requests WHERE sender_id=a AND recipient_id=b;
 IF n<>1 THEN RAISE EXCEPTION 'Duplicate requests must produce one pending request'; END IF;
 IF EXISTS(SELECT 1 FROM public.my_friends() WHERE id=b) THEN RAISE EXCEPTION 'Request must not create a friendship before acceptance'; END IF;
 BEGIN
  PERFORM public.accept_friend_request(req);
  RAISE EXCEPTION 'Sender was allowed to accept';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 IF EXISTS(SELECT 1 FROM public.my_friend_requests() WHERE id=req) THEN RAISE EXCEPTION 'Third party can see private request'; END IF;
 BEGIN
  PERFORM public.accept_friend_request(req);
  RAISE EXCEPTION 'Third party was allowed to accept';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM public.dismiss_friend_request(req);
  RAISE EXCEPTION 'Third party was allowed to dismiss';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 PERFORM public.add_my_friend(a);
 IF NOT EXISTS(SELECT 1 FROM public.my_friend_requests() WHERE id=req AND direction='incoming') THEN RAISE EXCEPTION 'Reverse request must remain incoming, not auto accept'; END IF;
 PERFORM public.accept_friend_request(req);
 SELECT friendship_id INTO friendship FROM public.my_friends() WHERE id=a;
 IF friendship IS NULL THEN RAISE EXCEPTION 'Recipient acceptance must create friendship'; END IF;
 IF EXISTS(SELECT 1 FROM public.friend_requests WHERE id=req) THEN RAISE EXCEPTION 'Accepted request not consumed'; END IF;
 PERFORM public.remove_my_friend(friendship);
 IF EXISTS(SELECT 1 FROM public.my_friends() WHERE id=a) THEN RAISE EXCEPTION 'Recipient could not remove friend'; END IF;
 PERFORM public.add_my_friend(a);
 SELECT id INTO req FROM public.friend_requests WHERE sender_id=b AND recipient_id=a;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 PERFORM public.dismiss_friend_request(req);
 IF EXISTS(SELECT 1 FROM public.friend_requests WHERE id=req) THEN RAISE EXCEPTION 'Decline must remove request'; END IF;
 PERFORM public.add_my_friend(b);
 SELECT id INTO req FROM public.friend_requests WHERE sender_id=a AND recipient_id=b;
 PERFORM public.dismiss_friend_request(req);
 IF EXISTS(SELECT 1 FROM public.friend_requests WHERE id=req) THEN RAISE EXCEPTION 'Sender cancellation must remove request'; END IF;
 PERFORM public.add_my_friend(b);
 SELECT id INTO req FROM public.friend_requests WHERE sender_id=a AND recipient_id=b;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 PERFORM public.accept_friend_request(req);
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 SELECT friendship_id INTO friendship FROM public.my_friends() WHERE id=b;
 PERFORM public.remove_my_friend(friendship);
 IF EXISTS(SELECT 1 FROM public.my_friends() WHERE id=b) THEN RAISE EXCEPTION 'Sender could not remove friend'; END IF;
 IF has_table_privilege('authenticated','public.friendships','INSERT') OR has_table_privilege('authenticated','public.friend_requests','INSERT') THEN RAISE EXCEPTION 'Direct writes bypass consent'; END IF;
 IF has_function_privilege('anon','public.accept_friend_request(uuid)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous acceptance allowed'; END IF;
END $$;
ROLLBACK;
