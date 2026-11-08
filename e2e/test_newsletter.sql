-- Run through the privileged database tool; every test mutation is rolled back.
BEGIN;
DO $$
DECLARE n integer; i integer; suffix text := gen_random_uuid()::text; test_email text;
BEGIN
 test_email := 'newsletter-test-' || suffix || '@example.com';
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.newsletter_subscribers'::regclass)
    OR EXISTS(SELECT 1 FROM pg_policy WHERE polrelid='public.newsletter_subscribers'::regclass)
    OR has_table_privilege('anon','public.newsletter_subscribers','SELECT,INSERT,UPDATE,DELETE')
    OR has_table_privilege('authenticated','public.newsletter_subscribers','SELECT,INSERT,UPDATE,DELETE')
    OR NOT has_table_privilege('service_role','public.newsletter_subscribers','SELECT,INSERT,UPDATE,DELETE')
    OR NOT has_function_privilege('anon','public.newsletter_subscribe(text,text)','EXECUTE')
    OR NOT has_function_privilege('authenticated','public.newsletter_subscribe(text,text)','EXECUTE')
    OR has_function_privilege('anon','public.admin_newsletter_subscribers()','EXECUTE')
    OR NOT has_function_privilege('authenticated','public.admin_newsletter_subscribers()','EXECUTE') THEN
  RAISE EXCEPTION 'Newsletter security rules failed';
 END IF;
 BEGIN PERFORM public.newsletter_subscribe('invalid'); RAISE EXCEPTION 'Invalid email accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 BEGIN PERFORM public.newsletter_subscribe(repeat('a',243)||'@example.com'); RAISE EXCEPTION '255 characters accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 BEGIN PERFORM public.newsletter_subscribe(test_email,'fr'); RAISE EXCEPTION 'Invalid language accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 PERFORM public.newsletter_subscribe('  '||upper(test_email)||'  ');
 PERFORM public.newsletter_subscribe(test_email,'en');
 SELECT count(*) INTO n FROM public.newsletter_subscribers WHERE email=test_email AND lang='sv';
 IF n<>1 THEN RAISE EXCEPTION 'Normalization or deduplication failed'; END IF;
 PERFORM public.newsletter_subscribe(repeat('a',242)||'@example.com','en');
 SELECT count(*) INTO n FROM public.newsletter_subscribers WHERE created_at>clock_timestamp()-interval '1 hour';
 FOR i IN n..199 LOOP
  PERFORM public.newsletter_subscribe('limit-'||suffix||'-'||i||'@example.com');
 END LOOP;
 BEGIN PERFORM public.newsletter_subscribe('blocked-'||suffix||'@example.com'); RAISE EXCEPTION 'Limit failed' USING ERRCODE='22000'; EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL; END;
 BEGIN PERFORM public.newsletter_subscribe(test_email); RAISE EXCEPTION 'Duplicate reveals membership' USING ERRCODE='22000'; EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL; END;
 SELECT count(*) INTO n FROM public.newsletter_subscribers WHERE created_at>clock_timestamp()-interval '1 hour';
 IF n<>200 THEN RAISE EXCEPTION 'Expected exactly 200 sign-ups'; END IF;
 BEGIN PERFORM public.admin_newsletter_subscribers(); RAISE EXCEPTION 'Unauthorized listing accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;