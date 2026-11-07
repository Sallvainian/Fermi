-- CI red probe (do not merge): a column drop and a USAGE grant on app.
create table app.probe_red (a int, b int);
alter table app.probe_red drop column b;
grant usage on schema app to authenticated;
