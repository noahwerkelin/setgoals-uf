-- All changes are rolled back, including child/account-link tests.
BEGIN;
DO $$
DECLARE a uuid; b uuid; child uuid:=gen_random_uuid(); cuser uuid:=gen_random_uuid(); original text; testname text:='ut_'||substr(replace(gen_random_uuid()::text,'-',''),1,12);
BEGIN
 SELECT id,username INTO a,original FROM public.profiles ORDER BY id LIMIT 1;
 SELECT id INTO b FROM public.profiles WHERE id<>a LIMIT 1;
 IF b IS NULL THEN RAISE EXCEPTION 'Two existing profiles required'; END IF;
 IF public.username_is_valid('ab') OR NOT public.username_is_valid('abc') THEN RAISE EXCEPTION 'Minimum length rule failed'; END IF;
 IF public.username_is_valid(repeat('a',21)) OR NOT public.username_is_valid(repeat('a',20)) THEN RAISE EXCEPTION 'Maximum length rule failed'; END IF;
 IF public.username_is_valid('åke') OR public.username_is_valid('user١') OR public.username_is_valid('a-b') OR NOT public.username_is_valid('USER_1') THEN RAISE EXCEPTION 'ASCII rule failed'; END IF;
 BEGIN
  INSERT INTO public.children(parent_id,name,username,code) VALUES(a,'Test',upper(original),'UTEST001');
  RAISE EXCEPTION 'Child claimed existing regular username';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 INSERT INTO public.children(id,parent_id,name,username,code) VALUES(child,a,'Test',testname,'UTEST002');
 BEGIN
  INSERT INTO public.children(parent_id,name,username,code) VALUES(a,'Test',upper(testname),'UTEST003');
  RAISE EXCEPTION 'Child claimed another child username';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
  UPDATE public.profiles SET username=upper(testname) WHERE id=b;
  RAISE EXCEPTION 'Regular account claimed child username';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
  UPDATE public.children SET username=original WHERE id=child;
  RAISE EXCEPTION 'Child edit claimed another username';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 UPDATE public.children SET name='Changed',username=testname WHERE id=child;
 IF NOT EXISTS(SELECT 1 FROM public.children WHERE id=child AND name='Changed' AND username=testname) THEN RAISE EXCEPTION 'Unchanged username edit failed'; END IF;
 BEGIN
  UPDATE public.children SET username='ab' WHERE id=child;
  RAISE EXCEPTION 'Invalid child edit accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM set_config('request.jwt.claims','{"role":"authenticated"}',true);
 BEGIN
  UPDATE public.children SET auth_user_id=b WHERE id=child;
  RAISE EXCEPTION 'Untrusted child link allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 -- Real auth trigger path, inside the rollback-only transaction.
 INSERT INTO auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_user_meta_data,created_at,updated_at)
 VALUES(cuser,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','child.'||child||'@child.setgoals.app','',now(),jsonb_build_object('username',testname),now(),now());
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=cuser AND username=testname) OR NOT EXISTS(SELECT 1 FROM public.children WHERE id=child AND auth_user_id=cuser AND username=testname) THEN RAISE EXCEPTION 'Child redemption did not preserve username and link'; END IF;
 UPDATE public.children SET username=testname||'x' WHERE id=child;
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=cuser AND username=testname||'x') THEN RAISE EXCEPTION 'Parent rename not synced'; END IF;
 UPDATE public.profiles SET username=testname||'y' WHERE id=cuser;
 IF NOT EXISTS(SELECT 1 FROM public.children WHERE id=child AND username=testname||'y') THEN RAISE EXCEPTION 'Profile rename not synced'; END IF;
 IF NOT public.username_available(testname) THEN RAISE EXCEPTION 'Old reservation not released'; END IF;
 IF has_table_privilege('authenticated','public.username_reservations','INSERT') OR has_table_privilege('anon','public.username_reservations','SELECT') THEN RAISE EXCEPTION 'Private reservations exposed'; END IF;
 IF has_function_privilege('authenticated','public.reserve_account_username()','EXECUTE') THEN RAISE EXCEPTION 'Internal trigger executable'; END IF;
END $$;
ROLLBACK;