-- CI red probe (do not merge): an unlisted function, executable by anon.
create function public.probe_red() returns int language sql as 'select 1';
grant execute on function public.probe_red() to anon;
