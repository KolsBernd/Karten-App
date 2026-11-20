-- Version 38: modular client, protected friend statistics and bounded diagnostics.
begin;
create or replace function public.hh_tournament_logo_valid(value text) returns boolean language plpgsql immutable set search_path='' as $$
declare bytes bytea;w bigint;h bigint;begin
 if value is null or value='' then return true;end if;
 if length(value)>60000 or value !~ '^data:image/png;base64,[A-Za-z0-9+/=]+$' then return false;end if;
 bytes:=decode(substr(value,23),'base64');
 if length(bytes)<33 or substring(bytes from 1 for 8)<>decode('89504e470d0a1a0a','hex') or substring(bytes from 13 for 4)<>convert_to('IHDR','UTF8') then return false;end if;
 w:=get_byte(bytes,16)::bigint*16777216+get_byte(bytes,17)*65536+get_byte(bytes,18)*256+get_byte(bytes,19);
 h:=get_byte(bytes,20)::bigint*16777216+get_byte(bytes,21)*65536+get_byte(bytes,22)*256+get_byte(bytes,23);
 return w between 1 and 256 and h between 1 and 256;
 exception when others then return false;
end$$;
revoke all on function public.hh_tournament_logo_valid(text) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.hh_tournament_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<turnier>>
declare t public.hh_tournaments;tb public.hh_tournament_tables;r jsonb;uid uuid:=auth.uid();boss boolean;roster uuid[];all_ids uuid[];next_ids uuid[];ids uuid[];v uuid;gn int;side int;base int;mult int;points int;win int;need int;stages int;idx int;n int;offset_n int;lim int;result jsonb;settings jsonb;games jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden';end if;if p_action not in('list','detail','directory') then perform public.hh_require_tournament_profile();end if;boss:=public.hh_tournament_can_create();
 if p_action in('table','replace_table','start','next_stage','finish','cancel') then perform pg_advisory_xact_lock(73190219);end if;
 if p_action='list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'created_by',a.created_by,'title',a.title,'status',a.status,'created_at',a.created_at,'stage',a.stage,'settings',a.settings,'tables',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage),'done',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage and b.done)) order by a.created_at desc),'[]') into result from public.hh_tournaments a where a.status in('finished','cancelled') or a.created_by=uid or exists(select 1 from public.hh_tournament_tables b where b.tournament_id=a.id and uid=any(b.players));return result;
 end if;
 if p_action='directory' then
  if not boss then raise exception 'Nur Turnierverwaltung';end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(select p.user_id,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) username,p.avatar,false as guest,coalesce(d.locality,'') as locality,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) full_name,d.first_name,d.last_name from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id where (p.username||' '||coalesce(d.first_name,'')||' '||coalesce(d.last_name,'')) ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' union all select id,first_name||' '||last_name,null,true,locality,first_name||' '||last_name,first_name,last_name from public.hh_tournament_guests where created_by=uid and deleted_at is null and (first_name||' '||last_name||' '||locality) ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' order by username limit 100 offset greatest(0,least(100000,coalesce((p_body->>'offset')::int,0)))) q;return result;
 end if;
 if p_action in('create','settings') then
  if not boss then raise exception 'Nur freigeschaltete Turnierersteller dürfen Turniere erstellen';end if;
  settings:=p_body->'settings';if not public.hh_tournament_logo_valid(settings->>'logo') then raise exception 'Ungültiges Turnierlogo';end if;if settings ? 'capture_colors' and jsonb_typeof(settings->'capture_colors') is distinct from 'boolean' then raise exception 'Ungültige Farberfassung';end if;
  if coalesce(settings->>'game',coalesce(p_body->'settings'->>'game','Bierkopf')) not in('Bierkopf','Schafkopf') then raise exception 'Unbekanntes Turnierspiel';end if;
  if settings->>'game'='Schafkopf' then
   if jsonb_typeof(settings->'variants') is distinct from 'array' or jsonb_array_length(settings->'variants')=0 or not exists(select 1 from jsonb_array_elements_text(settings->'variants') variant_option where variant_option in('King','Solo','Wenz','Geier','Kreuzspiel','Sau')) or exists(select 1 from jsonb_array_elements_text(settings->'variants') variant_option where variant_option not in('King','Solo','Wenz','Geier','Kreuzspiel','Sau','Tout')) then raise exception 'Bitte gültige Spielmöglichkeiten wählen';end if;
  end if;
  if coalesce(settings->>'mode','') not in('fixed','firstto') or coalesce(settings->>'rotation','') not in('none','players') or coalesce(settings->>'ranking','') not in('wins_points','full','wins') then raise exception 'Ungültige Turniereinstellungen';end if;
  need:=(settings->>'target')::int;stages:=(settings->>'stages')::int;
  if need is null or stages is null or stages not between 1 and 10 or need not between 1 and 30  then raise exception 'Partien: 1–30; Runden: 1–10';end if;
  settings:=settings||jsonb_build_object('mode','fixed','ranking','wins_points','game',coalesce(p_body->'settings'->>'game','Bierkopf'));
  if p_action='settings' then
   select * into t from public.hh_tournaments where id=p_id for update;
   if not found or t.created_by<>uid or t.status<>'draft' then raise exception 'Einstellungen sind nach Turnierstart festgelegt';end if;
   if not(settings ? 'logo') then settings:=settings||jsonb_build_object('logo',t.settings->'logo');end if;
   update public.hh_tournaments set title=trim(p_body->>'title'),settings=turnier.settings where id=p_id;update public.hh_tournament_tables set scores=case when settings->>'game'='Schafkopf' then array[0,0,0,0] else array[0,0] end,revision=revision+1 where tournament_id=p_id;return jsonb_build_object('id',p_id);
  end if;
  insert into public.hh_tournaments(title,created_by,settings) values(trim(p_body->>'title'),uid,settings) returning id into v;return jsonb_build_object('id',v);
 end if;
 if p_action in('round','undo','abort') then
  select * into tb from public.hh_tournament_tables where id=p_id;
  if not found then raise exception 'Tisch nicht gefunden';end if;
  p_id:=tb.tournament_id;
 end if;
 -- Parent lock serializes simultaneous last-table finishes and stage transitions.
 select * into t from public.hh_tournaments where id=p_id for update;
 if not found or not((p_action='detail' and t.status in('finished','cancelled')) or t.created_by=uid or exists(select 1 from public.hh_tournament_tables where tournament_id=p_id and uid=any(players))) then raise exception 'Kein Zugriff auf dieses Turnier';end if;
 if p_action in('table','replace_table') then
  if t.created_by<>uid or t.status<>'draft' then raise exception 'Tische nur vor Turnierbeginn anlegen';end if;
  select array_agg(value::uuid order by ordinality) into roster from jsonb_array_elements_text(p_body->'players') with ordinality;
  if cardinality(roster) is distinct from 4 or (select count(distinct x) from unnest(roster) x)<>4 or (select count(*) from (select user_id as id from public.hh_profiles union all select id from public.hh_tournament_guests where created_by=uid and deleted_at is null) q where id=any(roster))<>4 then raise exception 'Vier verschiedene Spieler oder Gäste auswählen';end if;
  if exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and b.players&&roster and (p_action='table' or b.id is distinct from (p_body->>'table_id')::uuid)) then raise exception 'Ein Spieler ist bereits einem Tisch zugeteilt';end if;
  select coalesce(max(start_no),0) into gn from public.hh_tournament_numbers where tournament_id=t.id;foreach v in array roster loop if not exists(select 1 from public.hh_tournament_numbers where tournament_id=t.id and player_id=v) then gn:=gn+1;insert into public.hh_tournament_numbers values(t.id,v,gn);end if;end loop;
  if p_action='replace_table' then
   update public.hh_tournament_tables set players=roster where id=(p_body->>'table_id')::uuid and tournament_id=t.id and stage=1;
   if not found then raise exception 'Tisch nicht gefunden';end if;
  else
  select coalesce(max(table_no),0)+1 into n from public.hh_tournament_tables where tournament_id=t.id;
  insert into public.hh_tournament_tables(tournament_id,stage,table_no,players,scores) values(t.id,1,n,roster,case when t.settings->>'game'='Schafkopf' then array[0,0,0,0] else array[0,0] end);
  end if;
 elsif p_action='start' then
  if t.created_by<>uid or t.status<>'draft' then raise exception 'Nur Verwaltung kann ein vorbereitetes Turnier starten';end if;
  if not exists(select 1 from public.hh_tournament_tables where tournament_id=t.id) then raise exception 'Bitte mindestens einen Tisch anlegen';end if;
  if exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and (array_position(players,null) is not null or cardinality(players)<>4 or (select count(*) from(select user_id as id from public.hh_profiles union all select id from public.hh_tournament_guests where created_by=uid and deleted_at is null) valid where valid.id=any(players))<>4)) then raise exception 'Bitte freie Plätze an allen Tischen zuerst neu besetzen';end if;
  if coalesce((t.settings->>'draw')::boolean,true) then
   select array_agg(x order by random()) into all_ids from public.hh_tournament_tables b cross join lateral unnest(b.players) x where b.tournament_id=t.id and b.stage=1;
   all_ids:=public.hh_tournament_balance(all_ids);idx:=1;for tb in select * from public.hh_tournament_tables where tournament_id=t.id and stage=1 order by table_no loop
    update public.hh_tournament_tables set players=all_ids[idx:idx+3] where id=tb.id;idx:=idx+4;
   end loop;
  end if;
  if exists(select 1 from public.hh_tournament_tables b where tournament_id=t.id and not exists(select 1 from public.hh_profiles where user_id=any(b.players))) then raise exception 'Jeder Tisch benötigt mindestens einen registrierten Mitspieler';end if;
  update public.hh_tournament_tables set round_started_at=now(),table_started_at=now() where tournament_id=t.id and stage=t.stage;
  update public.hh_tournaments set status='running' where id=t.id;
 elsif p_action in('round','undo','abort') then
  if not(uid=any(tb.players) or t.created_by=uid) then raise exception 'Nur Teilnehmer dieses Tisches';end if;
  if p_action='abort' and t.created_by<>uid then raise exception 'Nur der Turnierersteller darf eine Partie abbrechen';end if;
  perform public.hh_table_apply(tb.id,(p_body->>'revision')::bigint,p_action,p_body,uid,(select coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id where p.user_id=uid));
 elsif p_action in('next_stage','finish','cancel') then
  if t.created_by<>uid then raise exception 'Nur der Turnierersteller darf diese Aktion ausführen';end if;
  if t.status not in('draft','running') then raise exception 'Dieses Turnier ist bereits archiviert';end if;
  if p_action='cancel' then
   update public.hh_tournaments set status='cancelled',finished_at=now() where id=t.id;
  else
   if t.status<>'running' or not exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and stage=t.stage) or exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and stage=t.stage and not done) then raise exception 'Zuerst müssen alle Tische die Partien dieser Runde beenden';end if;
   if p_action='finish' then
    if t.stage<(t.settings->>'stages')::int then raise exception 'Es sind noch weitere Turnierrunden vorgesehen';end if;
    update public.hh_tournaments set status='finished',finished_at=now() where id=t.id;
   else
    if t.stage>=(t.settings->>'stages')::int then raise exception 'Alle Runden gespielt. Bitte das Turnier beenden';end if;
    select array_agg(x order by random()) into next_ids from public.hh_tournament_tables b cross join lateral unnest(b.players) x where b.tournament_id=t.id and b.stage=t.stage;
    next_ids:=public.hh_tournament_balance(next_ids);n:=cardinality(next_ids);
    for idx in 1..n by 4 loop insert into public.hh_tournament_tables(tournament_id,stage,table_no,players,scores) values(t.id,t.stage+1,(idx-1)/4+1,next_ids[idx:idx+3],case when t.settings->>'game'='Schafkopf' then array[0,0,0,0] else array[0,0] end);end loop;
    update public.hh_tournaments set stage=stage+1 where id=t.id;
   end if;
  end if;
 elsif p_action<>'detail' then raise exception 'Unbekannte Turnieraktion';end if;
 select * into t from public.hh_tournaments where id=t.id;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'stage',b.stage,'table_no',b.table_no,'players',to_jsonb(b.players),'games',case when uid=any(b.players) or t.created_by=uid then b.games else (select coalesce(jsonb_agg(g-'rounds'),'[]') from jsonb_array_elements(b.games) g) end,'scores',to_jsonb(b.scores),'rounds',case when uid=any(b.players) or t.created_by=uid then b.rounds else '[]'::jsonb end,'done',b.done,'revision',b.revision) order by b.stage,b.table_no),'[]') into result from public.hh_tournament_tables b where b.tournament_id=t.id ;
 -- Ranking input includes only reduced results, never other tables' round/actor data.
 select coalesce(jsonb_agg(jsonb_build_object('players',to_jsonb(b.players),'games',(select coalesce(jsonb_agg((g.value-'rounds')||jsonb_build_object('suit',g.value->'rounds'->0->'suit')),'[]') from jsonb_array_elements(b.games) g))),'[]') into games from public.hh_tournament_tables b where b.tournament_id=t.id;
 select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('locality',case when t.created_by=uid then coalesce((select d.locality from public.hh_account_details d where d.user_id=p.user_id),(select g.locality from public.hh_tournament_guests g where g.id=p.user_id),'') else null end,'start_no',(select start_no from public.hh_tournament_numbers where tournament_id=t.id and player_id=p.user_id))),'[]') into r from(select p.user_id,p.username,p.avatar,false as guest,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) as full_name,d.first_name,d.last_name from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id union all select id,first_name||' '||last_name,null,true,first_name||' '||last_name,first_name,last_name from public.hh_tournament_guests) p where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and p.user_id=any(b.players));
 return jsonb_build_object('id',t.id,'title',t.title,'status',t.status,'stage',t.stage,'settings',t.settings,'created_at',t.created_at,'finished_at',t.finished_at,'tables',result,'results',games,'people',r,'admin',t.created_by=uid,'ready',not exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and stage=t.stage and not done),'created_by',t.created_by);
end $function$;
-- Friend statistics expose aggregate scores only, never room/chat/contact details.
create or replace function public.hh_profile_metrics(p_user uuid) returns jsonb
language sql stable security definer set search_path='' as $$
with sessions as (
 select st.room_id,st.payload->'people' people,a from public.hh_states st
 join public.hh_members m on m.room_id=st.room_id and m.user_id=p_user
 cross join lateral jsonb_array_elements(coalesce(st.payload->'sessions','[]')) a
), records as (
 select room_id,people,coalesce(g->>'gameType','Bierkopf') kind,g from sessions cross join lateral jsonb_array_elements(coalesce(a->'games','[]')) g
 union all select room_id,people,'Schniffelkopf',g from sessions cross join lateral jsonb_array_elements(coalesce(a->'snHistory','[]')) g where g->>'closed'='true'
 union all select room_id,people,'Klopfer',g from sessions cross join lateral jsonb_array_elements(coalesce(a->'klHistory','[]')) g where g->>'closed'='true'
), teams as (
 select kind,public.hh_record_time(g->>'date') played_at,coalesce((g->>'winner')::int=side,false) won,
 coalesce((g->'scores'->>side)::numeric,0) points,coalesce((g->'scores'->>side)::numeric,0)-coalesce((g->'scores'->>(1-side))::numeric,0) net
 from records cross join generate_series(0,1) side
 where kind in('Bierkopf','Schleifer') and exists(select 1 from jsonb_array_elements(coalesce(people,'[]')) person where person->>'authUserId'=p_user::text and g->'members'->side @> jsonb_build_array(person->'id'))
), sheets as (
 select r.*,row_number() over() sheet_id from records r where kind in('Schniffelkopf','Klopfer')
), solo as (
 select r.*,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}'),0) points
 from sheets r cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where kind='Schniffelkopf'
 union all
 select r.*,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'rounds','[]')) rnd cross join lateral jsonb_array_elements(coalesce(rnd->'results','[]')) e where e->>'id'=pid #>> '{}'),0)
 from sheets r cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where kind='Klopfer'
), solo_ranked as (select *,points=max(points) over(partition by sheet_id) won from solo), all_results as (
 select * from teams
 union all select kind,public.hh_record_time(g->>'date'),won,points,null::numeric from solo_ranked where exists(select 1 from jsonb_array_elements(coalesce(people,'[]')) person where person->>'authUserId'=p_user::text and person->>'id'=pid)
 union all select game_type,played_at,won,coalesce(gross_points,case when game_type in('Bierkopf','Schleifer') and not won then null else points end),net_points from public.hh_saved_player_results where user_id=p_user
 union all select r->>'type',public.hh_record_time(r->>'date'),(r->>'won')::boolean,(r->>'points')::numeric,(r->>'net_points')::numeric from public.hh_tournaments t cross join lateral jsonb_array_elements(public.hh_tournament_result_records(t.id)) r where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and p_user=any(b.players)) and r->>'user_id'=p_user::text
), counted as (
 select kind,count(*) games,count(*) filter(where won) wins,coalesce(sum(points),0) points,
 case when kind in('Bierkopf','Schleifer') then coalesce(sum(net),0) else null end net,
 bool_or(points is null) points_incomplete,kind in('Bierkopf','Schleifer') and bool_or(net is null) net_incomplete
 from all_results r where not exists(select 1 from public.hh_statistics_resets x where x.user_id=p_user and(r.played_at is null or r.played_at<=x.since)) group by kind
)
select coalesce(jsonb_object_agg(kind,jsonb_build_object('games',games,'wins',wins,'points',points,'netPoints',net,'pointsIncomplete',points_incomplete,'netIncomplete',net_incomplete)),'{}') from counted;
$$;
revoke all on function public.hh_profile_metrics(uuid) from public,anon,authenticated;
create or replace function public.hh_friend_profile_statistics(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or not exists(select 1 from public.hh_profiles where user_id=auth.uid()) or public.hh_pair_blocked(auth.uid(),p_user) or not public.hh_are_friends(auth.uid(),p_user) then raise exception 'Nur bestätigte Freunde können die Profilstatistik sehen';end if;
 select jsonb_build_object('username',coalesce(p.display_username,p.username),'avatar',p.avatar,'by_game',public.hh_profile_metrics(p_user)) into result from public.hh_profiles p where p.user_id=p_user;
 if result is null then raise exception 'Profil nicht gefunden';end if;return result;
end$$;
revoke all on function public.hh_friend_profile_statistics(uuid) from public,anon;
grant execute on function public.hh_friend_profile_statistics(uuid) to authenticated;

-- Aggregates contain no user identifiers, messages, stack traces or URLs.
create table if not exists public.hh_error_totals(
 day date not null,code text not null,source text not null,build text not null,
 occurrences bigint not null,first_seen timestamptz not null,last_seen timestamptz not null,
 primary key(day,code,source,build)
);
create table if not exists public.hh_error_batches(batch uuid primary key,received_at timestamptz not null default now());
create table if not exists public.hh_error_rate_limits(user_id uuid primary key references auth.users(id) on delete cascade,window_start timestamptz not null,requests int not null);
alter table public.hh_error_totals enable row level security;
alter table public.hh_error_batches enable row level security;
alter table public.hh_error_rate_limits enable row level security;
revoke all on public.hh_error_totals,public.hh_error_batches,public.hh_error_rate_limits from public,anon,authenticated;
create or replace function public.hh_record_error(p_batch uuid,p_code text,p_source text,p_build text,p_count int,p_first timestamptz,p_last timestamptz) returns boolean
language plpgsql security definer set search_path='' as $$
declare requests int;begin
 if auth.uid() is null or not exists(select 1 from auth.users u join public.hh_profiles p on p.user_id=u.id where u.id=auth.uid() and u.email_confirmed_at is not null) then raise exception 'Bitte anmelden';end if;
 if p_batch is null or p_code is null or p_code not in('NETWORK','JS_TYPE','JS_REFERENCE','JS_ERROR','RESOURCE_LOAD','AUTH_FAILED','VALIDATION','RPC_RULE','23505','23503','42501','40001','PGRST202','PGRST301') or p_source is null or p_source not in('ui','global','resource') or p_build is null or p_build !~ '^[0-9]{1,3}\.[0-9]{1,3}$' or p_count is null or p_count not between 1 and 500 or p_first is null or p_last is null or p_first>p_last or p_first<now()-interval '8 days' or p_last>now()+interval '5 minutes' then raise exception 'Ungültiger Fehlerdatensatz';end if;
 insert into public.hh_error_rate_limits as r values(auth.uid(),date_trunc('minute',now()),1) on conflict(user_id) do update set window_start=excluded.window_start,requests=case when r.window_start=excluded.window_start then r.requests+1 else 1 end returning r.requests into requests;
 if requests>60 then return false;end if;
 insert into public.hh_error_batches(batch) values(p_batch) on conflict do nothing;
 if not found then return true;end if;
 insert into public.hh_error_totals as e values((p_last at time zone 'UTC')::date,p_code,p_source,p_build,p_count,p_first,p_last)
 on conflict(day,code,source,build) do update set occurrences=e.occurrences+excluded.occurrences,first_seen=least(e.first_seen,excluded.first_seen),last_seen=greatest(e.last_seen,excluded.last_seen);
 return true;
end$$;
revoke all on function public.hh_record_error(uuid,text,text,text,int,timestamptz,timestamptz) from public,anon;
grant execute on function public.hh_record_error(uuid,text,text,text,int,timestamptz,timestamptz) to authenticated;
create or replace function public.hh_error_report() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or not exists(select 1 from public.hh_reset_control where singleton and admin_id=auth.uid()) then raise exception 'Nur App-Verwaltung';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.last_seen desc),'[]') into result from(select code,source,build,sum(occurrences) occurrences,min(first_seen) first_seen,max(last_seen) last_seen from public.hh_error_totals where day>=(now() at time zone 'UTC')::date-29 group by code,source,build)q;return result;
end$$;
revoke all on function public.hh_error_report() from public,anon;
grant execute on function public.hh_error_report() to authenticated;
create or replace function public.hh_clean_error_log() returns void language plpgsql security definer set search_path='' as $$begin
 delete from public.hh_error_totals where day<(now() at time zone 'UTC')::date-29;
 delete from public.hh_error_batches where received_at<now()-interval '9 days';
 delete from public.hh_error_rate_limits where window_start<now()-interval '1 day';
end$$;
revoke all on function public.hh_clean_error_log() from public,anon,authenticated;
-- Existing pg_cron installation executes retention independently of browser usage.
select cron.schedule('kartabend-error-retention','19 3 * * *','select public.hh_clean_error_log();');

commit;
