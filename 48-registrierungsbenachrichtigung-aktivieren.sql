-- Run after version 49 and the updated push-delivery worker are deployed.
begin;
drop trigger if exists hh_notify_registration on public.hh_profiles;
create trigger hh_notify_registration after insert on public.hh_profiles for each row execute function public.hh_notify_registration();
commit;
