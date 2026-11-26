begin;
-- Read-only normalization for statistics: a room series is kept as one history
-- item, while every Schafkopf hand remains one independently counted game.
create or replace function public.hh_expand_extra_history(items jsonb) returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_agg(value order by parent_no,child_no),'[]') from (
  select g as value,parent_no,0::bigint child_no from jsonb_array_elements(coalesce(items,'[]')) with ordinality a(g,parent_no) where g->>'gameType' is distinct from 'Schafkopf' or jsonb_array_length(coalesce(g->'rounds','[]'))<2
  union all
  select g||jsonb_build_object('id',(g->>'id')||':'||child_no,'rounds',jsonb_build_array(r),'date',coalesce(r->'date',g->'date')),parent_no,child_no
  from jsonb_array_elements(coalesce(items,'[]')) with ordinality a(g,parent_no) cross join lateral jsonb_array_elements(coalesce(g->'rounds','[]')) with ordinality b(r,child_no)
  where g->>'gameType'='Schafkopf' and jsonb_array_length(coalesce(g->'rounds','[]'))>=2
 ) normalized;
$$;
revoke all on function public.hh_expand_extra_history(jsonb) from public,anon,authenticated;

do $migration$
declare def text;updated text;name text;
begin
 select pg_get_functiondef('public.hh_rule_extra_v40(jsonb,text,jsonb,boolean)'::regprocedure) into def;
 if position('series_limit' in def)=0 then
  updated:=replace(def,'cfg jsonb:=sheet->''settings'';begin','cfg jsonb:=sheet->''settings'';series_limit int;played int:=0;begin');
  updated:=replace(updated,'for r in select value from jsonb_array_elements(sheet->''rounds'') loop','if kind=''Schafkopf'' then series_limit:=public.hh_rule_int(coalesce(cfg->''target'',''1''::jsonb),1,50);end if; for r in select value from jsonb_array_elements(sheet->''rounds'') loop');
  updated:=replace(updated,'done:=true;','played:=played+1;done:=played>=series_limit;');
  if updated=def or position('done:=played>=series_limit' in updated)=0 then raise exception 'Unerwartete Raumregel-Version';end if;
  execute updated;
 end if;
 select pg_get_functiondef('public.hh_tournament_action(text,uuid,jsonb)'::regprocedure) into def;
 updated:=replace(def,'if need is null or stages is null or stages not between 1 and 10 or need not between 1 and 30  then raise exception ''Partien: 1–30; Runden: 1–10'';end if;',
 'if need is null or stages is null or need not between 1 and (case when settings->>''game''=''Schafkopf'' then 50 else 30 end) or stages not between 1 and (case when settings->>''game''=''Schafkopf'' then 50 else 10 end) then raise exception ''Schafkopf: 1–50 Partien und Runden; Bierkopf: 1–30 Partien, 1–10 Runden'';end if;');
 if position('then 50 else 30' in updated)=0 then raise exception 'Unerwartete Turnierregel-Version';end if;execute updated;
 foreach name in array array['hh_global_statistics_v10(text,integer)','hh_profile_metrics(uuid)','hh_keep_registered_results()'] loop
  select pg_get_functiondef(('public.'||name)::regprocedure) into def;
  updated:=replace(def,'jsonb_array_elements(coalesce(a->''extraHistory'',''[]''))','jsonb_array_elements(public.hh_expand_extra_history(coalesce(a->''extraHistory'',''[]'')))');
  if position('hh_expand_extra_history' in updated)=0 then raise exception 'Statistikfunktion passt nicht: %',name;end if;execute updated;
 end loop;
end $migration$;

-- The actor's public username and registration time are delivered only to the
-- canonical administration account, never selected by a client-supplied name.
alter table public.hh_notifications drop constraint if exists hh_notifications_kind_check;
alter table public.hh_notifications add constraint hh_notifications_kind_check check(kind in('friend_request','friend_accepted','new_room','evening_cancelled','tournament_tout','new_user'));
create or replace function public.hh_notify_registration() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 select admin_id into recipient from public.hh_reset_control where singleton;
 if recipient is null or recipient=new.user_id or not exists(select 1 from auth.users where id=new.user_id and email_confirmed_at is not null) then return new;end if;
 insert into public.hh_notifications(user_id,actor_id,kind,dedupe_key)
 values(recipient,new.user_id,'new_user','registration:'||new.user_id::text) on conflict(dedupe_key) do nothing;
 return new;
end$$;
revoke all on function public.hh_notify_registration() from public,anon,authenticated;
-- The trigger is deliberately attached only after the frontend and push worker
-- understand this kind. See 48-registrierungsbenachrichtigung-aktivieren.sql.
do $notifications$
declare def text;updated text;name text;
begin
 foreach name in array array['hh_notifications_snapshot()','hh_badge_count_for(uuid)','hh_read_notifications(timestamp with time zone)','hh_message_visibility(text,boolean)'] loop
  select pg_get_functiondef(('public.'||name)::regprocedure) into def;
  updated:=replace(def,'''new_room'',''friend_accepted'',''evening_cancelled'',''tournament_tout''','''new_room'',''friend_accepted'',''evening_cancelled'',''tournament_tout'',''new_user''');
  if position('''new_user''' in updated)=0 then raise exception 'Unerwartete Mitteilungsfunktion: %',name;end if;execute updated;
 end loop;
 select pg_get_functiondef('public.hh_queue_notification()'::regprocedure) into def;
 updated:=replace(def,'((new.kind=''friend_request'' and s.friend_requests)',
 '((new.kind=''new_user'' and new.user_id=(select admin_id from public.hh_reset_control where singleton)) or (new.kind=''friend_request'' and s.friend_requests)');
 if position('new.kind=''new_user''' in updated)=0 then raise exception 'Unerwartete Push-Warteschlange';end if;execute updated;
end $notifications$;
commit;
