begin;
alter table public.hh_saved_player_results add column if not exists gross_points numeric;
alter table public.hh_saved_player_results add column if not exists net_points numeric;
alter table public.hh_saved_player_results drop constraint if exists hh_saved_player_results_game_type_check;
alter table public.hh_saved_player_results add constraint hh_saved_player_results_game_type_check check(game_type in('Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf'));
CREATE OR REPLACE FUNCTION public.hh_tournament_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  settings:=p_body->'settings';if settings ? 'capture_colors' and jsonb_typeof(settings->'capture_colors') is distinct from 'boolean' then raise exception 'Ungültige Farberfassung';end if;
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
   update public.hh_tournaments set title=trim(p_body->>'title'),settings=(p_body->'settings')||jsonb_build_object('mode','fixed','ranking','wins_points','game',coalesce(p_body->'settings'->>'game','Bierkopf')) where id=p_id;update public.hh_tournament_tables set scores=case when settings->>'game'='Schafkopf' then array[0,0,0,0] else array[0,0] end,revision=revision+1 where tournament_id=p_id;return jsonb_build_object('id',p_id);
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
create or replace function public.hh_tournament_lobby() returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]') into result from(
 select t.id,t.created_by,t.title,t.status,t.stage,t.settings,t.created_at,t.finished_at,b.id as table_id,b.table_no,b.scores,b.done,jsonb_array_length(b.games) as completed,
 exists(select 1 from public.hh_tournament_tables h where h.tournament_id=t.id and auth.uid()=any(h.players)) as participant,
 (select coalesce(jsonb_agg(jsonb_build_object('user_id',p.user_id,'username',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name),'full_name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name),'first_name',coalesce(d.first_name,g.first_name),'last_name',coalesce(d.last_name,g.last_name),'avatar',p.avatar) order by u.n),'[]') from unnest(b.players) with ordinality u(id,n) left join public.hh_profiles p on p.user_id=u.id left join public.hh_tournament_guests g on g.id=u.id left join public.hh_account_details d on d.user_id=p.user_id) as people
 from public.hh_tournaments t left join public.hh_tournament_tables b on b.tournament_id=t.id and b.stage=t.stage and auth.uid()=any(b.players)
 where (t.status='running' and b.id is not null) or t.status in('finished','cancelled'))q;
 return result;
end $$;
create or replace function public.hh_keep_registered_results() returns trigger language plpgsql security definer set search_path='' as $$
declare body jsonb;a jsonb;g jsonb;person jsonb;pid jsonb;uid uuid;side integer;pts numeric;earned numeric;net numeric;best numeric;si integer:=0;gi integer;kind text;items jsonb;key text;score numeric;winner boolean;side_index integer;
begin
 select payload into body from public.hh_states where room_id=old.id;
 for a in select value from jsonb_array_elements(coalesce(body->'sessions','[]')) loop
 si:=si+1;
 foreach kind in array array['Bierkopf','Schleifer','Schniffelkopf','Klopfer'] loop
 items:=case when kind='Schniffelkopf' then a->'snHistory' when kind='Klopfer' then a->'klHistory' else a->'games' end;gi:=0;
 for g in select value from jsonb_array_elements(coalesce(items,'[]')) loop
 gi:=gi+1;if kind in('Bierkopf','Schleifer') and coalesce(g->>'gameType','Bierkopf')<>kind then continue;end if;
 if kind in('Schniffelkopf','Klopfer') and g->>'closed' is distinct from 'true' then continue;end if;
 key:=si||':'||kind||':'||gi;
 for person in select value from jsonb_array_elements(coalesce(body->'people','[]')) loop
 select p.user_id into uid from public.hh_profiles p join public.hh_members m on m.user_id=p.user_id and m.room_id=old.id where p.user_id::text=person->>'authUserId';if uid is null then continue;end if;
 if kind in('Bierkopf','Schleifer') then
 side:=null;for side_index in 0..1 loop
 if exists(select 1 from jsonb_array_elements(coalesce(g->'members'->side_index,'[]')) member where member #>> '{}'=person->>'id') then side:=side_index;exit;end if;end loop;
 if side is null then continue;end if;
 earned:=coalesce((g->'scores'->>side)::numeric,0);net:=earned-coalesce((g->'scores'->>(1-side))::numeric,0);
 winner:=g->>'winner'=side::text;score:=case when winner then coalesce((g->'scores'->>side)::numeric,0) else -coalesce((g->'scores'->>(1-side))::numeric,0) end;
 else
 if not exists(select 1 from jsonb_array_elements(coalesce(g->'players','[]')) member where member #>> '{}'=person->>'id') then continue;end if;
 best:=null;score:=0;
 for pid in select value from jsonb_array_elements(coalesce(g->'players','[]')) loop
 if kind='Schniffelkopf' then select coalesce(sum((e->>'points')::numeric),0) into pts from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}';
 else select coalesce(sum((e->>'points')::numeric),0) into pts from jsonb_array_elements(coalesce(g->'rounds','[]')) r cross join lateral jsonb_array_elements(coalesce(r->'results','[]')) e where e->>'id'=pid #>> '{}';end if;
 best:=greatest(best,pts);if pid #>> '{}'=person->>'id' then score:=pts;end if;
 end loop;winner:=score=best;earned:=score;net:=null;
 end if;
 insert into public.hh_saved_player_results(source_room,record_key,user_id,game_type,played_at,won,points,round_count,gross_points,net_points) values(old.id,key,uid,kind,public.hh_record_time(g->>'date'),coalesce(winner,false),score,jsonb_array_length(coalesce(case when kind='Schniffelkopf' then g->'entries' else g->'rounds' end,'[]')),earned,net) on conflict do nothing;
 end loop;
 end loop;
 end loop;
 end loop;return old;
end$$;
-- Private projection: keep scores, never guest names, images or table writer data.
create or replace function public.hh_tournament_result_records(p_tournament uuid)
returns jsonb language sql stable security definer set search_path='' as $$
-- Aggregate once, rather than repeatedly copying a growing JSON array.
with records as (
 select t.id tournament_id,b.id table_id,b.stage,b.table_no,g,n,seat,b.players[seat] user_id,
  coalesce(t.settings->>'game','Bierkopf') kind,
  coalesce((g->'scores'->>(case when t.settings->>'game'='Schafkopf' then seat-1 else (seat-1)/2 end))::numeric,0) own_points,
  coalesce((g->'scores'->>(1-(seat-1)/2))::numeric,0) opponent_points
 from public.hh_tournaments t join public.hh_tournament_tables b on b.tournament_id=t.id
 cross join lateral jsonb_array_elements(b.games) with ordinality z(g,n)
 cross join generate_series(1,4) seat
 join public.hh_profiles p on p.user_id=b.players[seat]
 where t.id=p_tournament
)
select coalesce(jsonb_agg(jsonb_build_object(
 'source_room',tournament_id,'record_key','table:'||table_id||':'||n,'user_id',user_id,
 'type',kind,'date',public.hh_record_time(g->>'date'),
 'won',case when kind='Schafkopf' then coalesce(g->'winners' @> jsonb_build_array(seat-1),false) else coalesce((g->>'winner')::int=(seat-1)/2,false) end,
 'points',own_points,'net_points',case when kind in('Bierkopf','Schleifer') then own_points-opponent_points else null end,
 'round_count',jsonb_array_length(coalesce(g->'rounds','[]'))
 ) order by stage,table_no,n,seat),'[]') from records;
$$;
revoke all on function public.hh_tournament_result_records(uuid) from public,anon,authenticated;

create or replace function public.hh_saved_personal_statistics() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 with records as (
  select jsonb_build_object('source_room',p.source_room,'type',p.game_type,'date',p.played_at,'won',p.won,'points',coalesce(p.gross_points,case when p.game_type in('Bierkopf','Schleifer') and not p.won then null else p.points end),'net_points',p.net_points) value
  from public.hh_saved_player_results p where p.user_id=auth.uid()
  union all
  select r.value from public.hh_tournaments t cross join lateral jsonb_array_elements(public.hh_tournament_result_records(t.id)) r
  where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and auth.uid()=any(b.players)) and r.value->>'user_id'=auth.uid()::text
 )
 select coalesce(jsonb_agg(value-'user_id'-'record_key'-'round_count'),'[]') into result from records r
 where not exists(select 1 from public.hh_statistics_resets reset where reset.user_id=auth.uid() and (public.hh_record_time(r.value->>'date') is null or public.hh_record_time(r.value->>'date')<=reset.since));
 return result;
end$$;

-- Only an archived tournament's creator may delete it. Active tables cannot be deleted.
-- The parent/advisory locks match the existing turnier action lock order.
create or replace function public.hh_delete_archived_tournament(p_tournament uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t public.hh_tournaments;r jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 perform pg_advisory_xact_lock(73190219);
 select * into t from public.hh_tournaments where id=p_tournament for update;
 if t.id is null or t.created_by<>auth.uid() then raise exception 'Nur der Turnierersteller darf dieses Turnier löschen';end if;
 if t.status not in('finished','cancelled') then raise exception 'Nur archivierte Turniere können gelöscht werden';end if;
 for r in select value from jsonb_array_elements(public.hh_tournament_result_records(t.id)) loop
  insert into public.hh_saved_player_results(source_room,record_key,user_id,game_type,played_at,won,points,round_count,gross_points,net_points)
  values(t.id,r->>'record_key',(r->>'user_id')::uuid,r->>'type',public.hh_record_time(r->>'date'),(r->>'won')::boolean,
   case when r->>'type' in('Bierkopf','Schleifer') and not (r->>'won')::boolean then (r->>'net_points')::numeric-(r->>'points')::numeric else (r->>'points')::numeric end,
   (r->>'round_count')::int,(r->>'points')::numeric,(r->>'net_points')::numeric) on conflict do nothing;
 end loop;
 delete from public.hh_share_choices where scope='table' and target_id in(select id from public.hh_tournament_tables where tournament_id=t.id);
 delete from public.hh_tournaments where id=t.id;
end$$;
revoke all on function public.hh_delete_archived_tournament(uuid) from public,anon;
grant execute on function public.hh_delete_archived_tournament(uuid) to authenticated;

create or replace function public.hh_global_statistics_v10(p_game text,p_days integer) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 if p_game is null or p_game not in ('all','Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf') or p_days is null or p_days not in (0,7,30,90,365) then raise exception 'Ungültiger Statistikfilter';end if;
 with sessions as (
 select st.room_id,st.payload->'people' people,a from public.hh_states st cross join lateral jsonb_array_elements(coalesce(st.payload->'sessions','[]')) a
 ), raw_records as (
 select room_id,people,coalesce(g->>'gameType','Bierkopf') type,g, jsonb_array_length(coalesce(g->'rounds','[]')) rounds from sessions cross join lateral jsonb_array_elements(coalesce(a->'games','[]')) g
 union all select room_id,people,'Schniffelkopf',g,jsonb_array_length(coalesce(g->'entries','[]')) from sessions cross join lateral jsonb_array_elements(coalesce(a->'snHistory','[]')) g where g->>'closed'='true'
 union all select room_id,people,'Klopfer',g,jsonb_array_length(coalesce(g->'rounds','[]')) from sessions cross join lateral jsonb_array_elements(coalesce(a->'klHistory','[]')) g where g->>'closed'='true'
 ), records as (select * from raw_records where (p_game='all' or type=p_game) and (p_days=0 or public.hh_record_time(g->>'date')>=now()-make_interval(days=>p_days))), team_results as (
 select r.room_id,r.people,r.type,public.hh_record_time(r.g->>'date') played_at,pid #>> '{}' pid,(side::text=r.g->>'winner') won from records r cross join generate_series(0,1) side cross join lateral jsonb_array_elements(coalesce(r.g->'members'->side,'[]')) pid where r.type in ('Bierkopf','Schleifer')
 ), sheets as (
 select r.*,row_number() over() sheet_id from records r where type in ('Schniffelkopf','Klopfer')
 ), solo_points as (
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}'),0) points from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Schniffelkopf'
 union all
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'rounds','[]')) rnd cross join lateral jsonb_array_elements(coalesce(rnd->'results','[]')) e where e->>'id'=pid #>> '{}'),0) from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Klopfer'
 ), results as (
 select * from team_results union all select room_id,people,type,played_at,pid,points=max(points) over(partition by sheet_id) from solo_points
 ), user_results as (
 select p.user_id,p.username,r.played_at,r.won from results r cross join lateral jsonb_array_elements(coalesce(r.people,'[]')) person join public.hh_profiles p on p.user_id::text=person->>'authUserId' join public.hh_members m on m.room_id=r.room_id and m.user_id=p.user_id where person->>'id'=r.pid
 union all select p.user_id,p.username,s.played_at,s.won from public.hh_saved_player_results s join public.hh_profiles p on p.user_id=s.user_id where (p_game='all' or s.game_type=p_game) and(p_days=0 or s.played_at>=now()-make_interval(days=>p_days))
 union all select (r->>'user_id')::uuid,p.username,public.hh_record_time(r->>'date'),(r->>'won')::boolean from public.hh_tournaments t cross join lateral jsonb_array_elements(public.hh_tournament_result_records(t.id)) r join public.hh_profiles p on p.user_id=(r->>'user_id')::uuid where (p_game='all' or r->>'type'=p_game) and(p_days=0 or public.hh_record_time(r->>'date')>=now()-make_interval(days=>p_days))
 ), userscores as (
 select u.user_id,u.username,count(*) games,count(*) filter(where u.won) wins from user_results u where not exists(select 1 from public.hh_statistics_resets reset where reset.user_id=u.user_id and(u.played_at is null or u.played_at<=reset.since)) group by u.user_id,u.username
 ), roomcounts as (select room_id,count(*) games,sum(rounds) rounds from records group by room_id), saved_games as(select source_room,record_key,game_type type,max(round_count) rounds from public.hh_saved_player_results where(p_game='all' or game_type=p_game) and(p_days=0 or played_at>=now()-make_interval(days=>p_days)) group by source_room,record_key,game_type
 union all select b.tournament_id,'table:'||b.id||':'||n,coalesce(t.settings->>'game','Bierkopf'),jsonb_array_length(coalesce(g->'rounds','[]')) from public.hh_tournament_tables b join public.hh_tournaments t on t.id=b.tournament_id cross join lateral jsonb_array_elements(b.games) with ordinality z(g,n) where (p_game='all' or coalesce(t.settings->>'game','Bierkopf')=p_game) and(p_days=0 or public.hh_record_time(g->>'date')>=now()-make_interval(days=>p_days))), variants as(select type,count(*) games from(select type from records union all select type from saved_games) all_games group by type)
 select jsonb_build_object('games',(select count(*) from records)+(select count(*) from saved_games),'rounds',(select coalesce(sum(rounds),0) from records)+(select coalesce(sum(rounds),0) from saved_games),'rooms',(select count(*) from roomcounts)+(select count(distinct source_room) from saved_games),
 'players',coalesce((select jsonb_agg(to_jsonb(x)) from(select user_id,username,games,wins from userscores order by wins desc,games desc)x),'[]'::jsonb),
 'top_rooms',coalesce((select jsonb_agg(to_jsonb(x)) from(select case when public.hh_can_discover_room(r.id) then r.title else 'Privater Kartabend' end title,c.games,c.rounds from roomcounts c join public.hh_rooms r on r.id=c.room_id order by c.rounds desc limit 10)x),'[]'::jsonb),
 'variants',coalesce((select jsonb_agg(to_jsonb(x)) from(select * from variants order by games desc)x),'[]'::jsonb)) into result;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
