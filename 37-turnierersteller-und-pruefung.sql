begin;
create table if not exists public.hh_tournament_creators(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.hh_tournament_creators enable row level security;
revoke all on public.hh_tournament_creators from public,anon,authenticated;
create or replace function public.hh_tournament_can_create() returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and (public.hh_tournament_admin() or exists(select 1 from public.hh_tournament_creators where user_id=auth.uid()))$$;
revoke all on function public.hh_tournament_can_create() from public,anon,authenticated;
create or replace function public.hh_tournament_capabilities() returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('can_create',public.hh_tournament_can_create())$$;
revoke all on function public.hh_tournament_capabilities() from public,anon;
grant execute on function public.hh_tournament_capabilities() to authenticated;
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
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'status',a.status,'created_at',a.created_at,'stage',a.stage,'settings',a.settings,'tables',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage),'done',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage and b.done)) order by a.created_at desc),'[]') into result from public.hh_tournaments a where a.status in('finished','cancelled') or a.created_by=uid or exists(select 1 from public.hh_tournament_tables b where b.tournament_id=a.id and uid=any(b.players));return result;
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
create or replace function public.hh_tournament_guest(p_action text,p_id uuid default null,p_body jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;begin
 if not public.hh_tournament_can_create() then raise exception 'Nur die Turnierverwaltung';end if;
 if p_action='create' then
  insert into public.hh_tournament_guests(first_name,last_name,locality,created_by) values(trim(p_body->>'first'),trim(p_body->>'last'),trim(p_body->>'locality'),auth.uid()) returning to_jsonb(hh_tournament_guests) into result;return result;
 elsif p_action='delete' then
  perform pg_advisory_xact_lock(73190219);
  if not exists(select 1 from public.hh_tournament_guests where id=p_id and created_by=auth.uid() and deleted_at is null) then raise exception 'Gast nicht verfügbar';end if;
  perform 1 from public.hh_tournaments t where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and p_id=any(b.players)) order by t.id for update;
  if exists(select 1 from public.hh_tournament_tables b join public.hh_tournaments t on t.id=b.tournament_id where p_id=any(b.players) and t.status='running') then raise exception 'Gast ist noch einem laufenden Turnier zugeteilt. Bitte zuerst das Turnier abschließen.';end if;
  update public.hh_tournament_tables b set players=array_replace(b.players,p_id,null::uuid),revision=revision+1 from public.hh_tournaments t where t.id=b.tournament_id and t.status='draft' and p_id=any(b.players);
  if exists(select 1 from public.hh_tournament_tables where p_id=any(players)) then update public.hh_tournament_guests set deleted_at=now() where id=p_id;
  else delete from public.hh_tournament_guests where id=p_id;end if;
  return '{}'::jsonb;
 elsif p_action='list' then select coalesce(jsonb_agg(jsonb_build_object('id',id,'first',first_name,'last',last_name,'locality',locality) order by first_name,last_name),'[]') into result from public.hh_tournament_guests where created_by=auth.uid() and deleted_at is null;return result;
 else raise exception 'Unbekannte Gastaktion';end if;
end $$;
create or replace function public.hh_tournament_invite(p_action text,p_token text default null,p_table uuid default null,p_guest uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$declare i public.hh_tournament_invites;b public.hh_tournament_tables;t public.hh_tournaments;token text;guest_name text;uid uuid:=auth.uid();begin
 if uid is null or not exists(select 1 from public.hh_profiles where user_id=uid) then raise exception 'Bitte zuerst anmelden und das Profil vervollständigen';end if;
 perform pg_advisory_xact_lock(73190219);
 if p_action='create' then
  if not public.hh_tournament_can_create() then raise exception 'Nur der Turnierersteller darf einladen';end if;
  select * into b from public.hh_tournament_tables where id=p_table;
  if not found then raise exception 'Tisch nicht gefunden';end if;
 else
  if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception 'Ungültige Einladung';end if;
  select * into i from public.hh_tournament_invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
  if not found or i.revoked_at is not null or i.expires_at<now() or (i.used_by is not null and i.used_by<>uid) then raise exception 'Einladung ist abgelaufen oder bereits verwendet';end if;
  select * into b from public.hh_tournament_tables where id=i.table_id;
 end if;
 select * into t from public.hh_tournaments where id=b.tournament_id for update;
 if p_action='create' and t.created_by<>uid then raise exception 'Nur der Ersteller dieses Turniers darf einladen';end if;
 if t.status<>'draft' then raise exception 'Tischeinladungen bitte vor Turnierbeginn bestätigen';end if;
 if p_action='create' then
  if not(p_guest=any(b.players)) or not exists(select 1 from public.hh_tournament_guests where id=p_guest and deleted_at is null) then raise exception 'Bitte einen zugeteilten Gast wählen';end if;
  token:=encode(extensions.gen_random_bytes(32),'hex');
  update public.hh_tournament_invites set revoked_at=now() where table_id=b.id and guest_id=p_guest and used_by is null and revoked_at is null;
  insert into public.hh_tournament_invites(table_id,guest_id,token_hash,created_by) values(b.id,p_guest,encode(extensions.digest(token,'sha256'),'hex'),uid);return jsonb_build_object('token',token);
 elsif p_action='accept' then
  if i.used_by=uid then return jsonb_build_object('tournament_id',t.id,'table_id',b.id);end if;
  if not(i.guest_id=any(b.players)) then raise exception 'Der Gastplatz wurde inzwischen neu zugeordnet';end if;
  if exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and uid=any(players)) then raise exception 'Du bist diesem Turnier bereits zugeteilt';end if;
  update public.hh_tournament_tables set players=array_replace(players,i.guest_id,uid),revision=revision+1 where id=b.id;
  update public.hh_tournament_invites set used_by=uid,used_at=now() where id=i.id;
 elsif p_action<>'preview' then raise exception 'Unbekannte Einladungsaktion';end if;
 select first_name||' '||last_name into guest_name from public.hh_tournament_guests where id=i.guest_id;
 return jsonb_build_object('tournament_id',t.id,'table_id',b.id,'title',t.title,'table_no',b.table_no,'guest_name',guest_name);
end $$;
create or replace function public.hh_tournament_access() returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and(public.hh_tournament_can_create() or exists(select 1 from public.hh_tournament_tables where auth.uid()=any(players)) or exists(select 1 from public.hh_tournaments where status in('finished','cancelled')))$$;
notify pgrst,'reload schema';
commit;
