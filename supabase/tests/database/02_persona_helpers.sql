-- The persona helpers in 00_test_helpers.sql do what every access-matrix test
-- relies on: authenticate_as switches to the authenticated role with the
-- persona's id as auth.uid(), and nothing outlives the test's rollback.

begin;
select plan(7);

select tests.create_persona('teacher_a');
select tests.create_persona('teacher_b');

select tests.authenticate_as('teacher_a');
select is(current_user::text, 'authenticated', 'authenticate_as switches to the authenticated role');
select is(auth.uid(), tests.persona_id('teacher_a'), 'auth.uid() is the persona''s id');
select is(auth.role(), 'authenticated', 'the JWT claims carry the authenticated role');

select tests.authenticate_as('teacher_b');
select is(auth.uid(), tests.persona_id('teacher_b'), 'authenticate_as can switch persona mid-test');

select tests.authenticate_as_anon();
select is(current_user::text, 'anon', 'authenticate_as_anon switches to anon');
select is(auth.uid(), null, 'anon has no auth.uid()');

select tests.clear_authentication();
select is(current_user::text, 'postgres', 'clear_authentication returns to postgres');

select * from finish();
rollback;
