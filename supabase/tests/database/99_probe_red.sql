begin;
select plan(1);
select ok(false, 'CI red probe: fails on purpose');
select * from finish();
rollback;
