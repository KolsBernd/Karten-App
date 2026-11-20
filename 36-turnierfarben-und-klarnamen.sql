begin;
create or replace function public.hh_schaf_apply(p_table uuid,p_revision bigint,p_action text,p_body jsonb,p_actor uuid,p_actor_name text) returns void language plpgsql security definer set search_path='' as $$declare b public.hh_tournament_tables;t public.hh_tournaments;seat int;partner int;variant text;won boolean;bonus text;awards int[];r jsonb;idx int;played_name text;played_user uuid;begin
 select * into b from public.hh_tournament_tables where id=p_table;if not found then raise exception 'Tisch nicht gefunden';end if;
 select * into t from public.hh_tournaments where id=b.tournament_id for update;select * into b from public.hh_tournament_tables where id=p_table for update;
 if t.settings->>'game'<>'Schafkopf' or t.status<>'running' or b.stage<>t.stage or b.revision is distinct from p_revision then raise exception 'Der Tisch wurde inzwischen geändert oder ist nicht aktiv';end if;
 if p_action='undo' then
  if jsonb_array_length(b.games)=0 then raise exception 'Keine Partie zum Zurücknehmen';end if;
  r:=b.games->-1;delete from public.hh_notifications where tournament_table=b.id and tout_event=(r->'rounds'->0->>'event_id')::uuid;for idx in 1..4 loop b.scores[idx]:=b.scores[idx]-(r->'scores'->>(idx-1))::int;end loop;
  b.games:=b.games-(jsonb_array_length(b.games)-1);b.rounds:=b.rounds-(jsonb_array_length(b.rounds)-1);b.done:=false;
 elsif p_action='round' then
  if b.done then raise exception 'Alle Partien abgeschlossen';end if;
  seat:=(p_body->>'seat')::int;partner:=(p_body->>'partner')::int;variant:=p_body->>'variant';won:=(p_body->>'won')::boolean;bonus:=p_body->>'bonus';
  if not coalesce(t.settings->'variants' ? variant,false) or (bonus='tout' and not coalesce(t.settings->'variants' ? 'Tout',false)) then raise exception 'Dieses Spiel wurde für das Turnier nicht freigegeben';end if;
  if variant='Kreuzspiel' and coalesce((p_body->>'winner_selection')::boolean,false)=false then if not won then seat:=(seat+1)%4;end if;partner:=(seat+2)%4;won:=true;end if;
  if bonus='tout' and coalesce((p_body->>'tout_confirmed')::boolean,false) is not true then raise exception 'Bitte Tout vor dem Eintragen bestätigen';end if;
  if coalesce((t.settings->>'capture_colors')::boolean,false) and coalesce(p_body->>'suit','') not in('Eichel','Gras','Herz','Schellen') then raise exception 'Bitte eine gültige Farbe auswählen';end if;
  awards:=public.hh_schaf_awards(seat,variant,won,bonus,partner);
  for idx in 1..4 loop b.scores[idx]:=b.scores[idx]+awards[idx];end loop;
  r:=jsonb_build_object('event_id',gen_random_uuid(),'gameType','Schafkopf','variant',variant,'suit',case when coalesce((t.settings->>'capture_colors')::boolean,false) then p_body->>'suit' else null end,'seat',seat,'partner',partner,'won',won,'bonus',bonus,'awards',to_jsonb(awards),'scores',to_jsonb(b.scores),'date',clock_timestamp(),'actor',p_actor,'actor_name',left(p_actor_name,240),'duration_seconds',greatest(0,floor(extract(epoch from(now()-b.round_started_at))))::int);
  b.rounds:=b.rounds||jsonb_build_array(r);b.games:=b.games||jsonb_build_array(jsonb_build_object('gameType','Schafkopf','scores',to_jsonb(awards),'total_scores',to_jsonb(b.scores),'rounds',jsonb_build_array(r),'winners',(select jsonb_agg(n-1) from generate_series(1,4) n where awards[n]>0),'date',clock_timestamp()));
  b.done:=jsonb_array_length(b.games)>=(t.settings->>'target')::int;
  if bonus='tout' then
   select coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name,'Spieler'),p.user_id into played_name,played_user from (select b.players[seat+1] id) chosen left join public.hh_profiles p on p.user_id=chosen.id left join public.hh_account_details d on d.user_id=p.user_id left join public.hh_tournament_guests g on g.id=chosen.id;
   insert into public.hh_notifications(user_id,actor_id,kind,dedupe_key,tournament_id,tournament_table,tout_event,tout_player,tout_game,tout_table_no)
   values(t.created_by,played_user,'tournament_tout','tout:'||(r->>'event_id'),t.id,b.id,(r->>'event_id')::uuid,played_name,variant,b.table_no) on conflict(dedupe_key) do nothing;
  end if;
 else raise exception 'Beim Schafkopf bitte die letzte Partie zurücknehmen';end if;
 update public.hh_tournament_tables set scores=b.scores,rounds=b.rounds,games=b.games,done=b.done,revision=revision+1,round_started_at=now() where id=b.id;
end$$;
CREATE OR REPLACE FUNCTION public.hh_tournament_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.hh_tournaments;tb public.hh_tournament_tables;r jsonb;uid uuid:=auth.uid();boss boolean;roster uuid[];all_ids uuid[];next_ids uuid[];ids uuid[];v uuid;gn int;side int;base int;mult int;points int;win int;need int;stages int;idx int;n int;offset_n int;lim int;result jsonb;settings jsonb;games jsonb;
begin
 if uid is null then raise exception 'Bitte anmelden';end if;if p_action not in('list','detail','directory') then perform public.hh_require_tournament_profile();end if;boss:=public.hh_tournament_admin();
 if p_action in('table','replace_table','start','next_stage','finish','cancel') then perform pg_advisory_xact_lock(73190219);end if;
 if p_action='list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'status',a.status,'created_at',a.created_at,'stage',a.stage,'settings',a.settings,'tables',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage),'done',(select count(*) from public.hh_tournament_tables b where b.tournament_id=a.id and b.stage=a.stage and b.done)) order by a.created_at desc),'[]') into result from public.hh_tournaments a where a.status in('finished','cancelled') or boss or exists(select 1 from public.hh_tournament_tables b where b.tournament_id=a.id and uid=any(b.players));return result;
 end if;
 if p_action='directory' then
  if not boss then raise exception 'Nur Turnierverwaltung';end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(select p.user_id,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) username,p.avatar,false as guest,coalesce(d.locality,'') as locality,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) full_name,d.first_name,d.last_name from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id where (p.username||' '||coalesce(d.first_name,'')||' '||coalesce(d.last_name,'')) ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' union all select id,first_name||' '||last_name,null,true,locality,first_name||' '||last_name,first_name,last_name from public.hh_tournament_guests where deleted_at is null and (first_name||' '||last_name||' '||locality) ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' order by username limit 100 offset greatest(0,least(100000,coalesce((p_body->>'offset')::int,0)))) q;return result;
 end if;
 if p_action in('create','settings') then
  if not boss then raise exception 'Nur kolsbernd darf Turniere erstellen';end if;
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
  if cardinality(roster) is distinct from 4 or (select count(distinct x) from unnest(roster) x)<>4 or (select count(*) from (select user_id as id from public.hh_profiles union all select id from public.hh_tournament_guests where deleted_at is null) q where id=any(roster))<>4 then raise exception 'Vier verschiedene Spieler oder Gäste auswählen';end if;
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
  if exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and (array_position(players,null) is not null or cardinality(players)<>4 or (select count(*) from(select user_id as id from public.hh_profiles union all select id from public.hh_tournament_guests where deleted_at is null) valid where valid.id=any(players))<>4)) then raise exception 'Bitte freie Plätze an allen Tischen zuerst neu besetzen';end if;
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
 select coalesce(jsonb_agg(jsonb_build_object('players',to_jsonb(b.players),'games',(select coalesce(jsonb_agg(g.value-'rounds'),'[]') from jsonb_array_elements(b.games) g))),'[]') into games from public.hh_tournament_tables b where b.tournament_id=t.id;
 select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('locality',case when t.created_by=uid then coalesce((select d.locality from public.hh_account_details d where d.user_id=p.user_id),(select g.locality from public.hh_tournament_guests g where g.id=p.user_id),'') else null end,'start_no',(select start_no from public.hh_tournament_numbers where tournament_id=t.id and player_id=p.user_id))),'[]') into r from(select p.user_id,p.username,p.avatar,false as guest,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) as full_name,d.first_name,d.last_name from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id union all select id,first_name||' '||last_name,null,true,first_name||' '||last_name,first_name,last_name from public.hh_tournament_guests) p where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and p.user_id=any(b.players));
 return jsonb_build_object('id',t.id,'title',t.title,'status',t.status,'stage',t.stage,'settings',t.settings,'created_at',t.created_at,'finished_at',t.finished_at,'tables',result,'results',games,'people',r,'admin',t.created_by=uid,'ready',not exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and stage=t.stage and not done),'created_by',t.created_by);
end $function$;
CREATE OR REPLACE FUNCTION public.hh_tournament_table_state(p_table uuid, p_revision bigint DEFAULT NULL::bigint, p_member_stamp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare b public.hh_tournament_tables;t public.hh_tournaments;ps jsonb;gs jsonb;payload jsonb;member_stamp text;tour_stamp text;team_names jsonb;begin
 select * into b from public.hh_tournament_tables where id=p_table;
 if not found or auth.uid() is null then raise exception 'Tisch nicht verfügbar';end if;
 select * into t from public.hh_tournaments where id=b.tournament_id;
 if not(auth.uid()=any(b.players) or t.created_by=auth.uid()) then raise exception 'Nur zugeteilte Tischteilnehmer oder der Turnierersteller können diesen Tisch öffnen';end if;

 perform public.hh_require_tournament_profile();
 select jsonb_agg(jsonb_build_object('id',n,'name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name,'Spieler'),'photo',p.avatar,'authUserId',p.user_id,'guest',p.user_id is null,'full_name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name,'Spieler'),'first_name',coalesce(d.first_name,g.first_name),'last_name',coalesce(d.last_name,g.last_name),'start_no',(select start_no from public.hh_tournament_numbers where tournament_id=t.id and player_id=a.uid)) order by n) into ps from unnest(b.players) with ordinality a(uid,n) left join public.hh_profiles p on p.user_id=a.uid left join public.hh_tournament_guests g on g.id=a.uid left join public.hh_account_details d on d.user_id=p.user_id;
 if t.settings->>'game'='Schafkopf' then
 member_stamp:=md5(ps::text);select md5(string_agg(id::text||':'||revision::text,',' order by id)) into tour_stamp from public.hh_tournament_tables where tournament_id=t.id;
 if b.revision=p_revision and member_stamp=p_member_stamp then return jsonb_build_object('unchanged',true,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'current_stage',t.stage,'status',t.status,'done',b.done,'is_creator',t.created_by=auth.uid());end if;
 return jsonb_build_object('game','Schafkopf','people',ps,'schaf_scores',to_jsonb(b.scores),'schaf_games',b.games,'allowed_games',t.settings->'variants','capture_colors',coalesce((t.settings->>'capture_colors')::boolean,false),'table_id',b.id,'tournament_id',t.id,'title','Turnier '||t.title||' · Tisch '||b.table_no,'table_no',b.table_no,'stage',b.stage,'current_stage',t.stage,'status',t.status,'done',b.done,'created_at',t.created_at,'started_at',coalesce(b.table_started_at,t.created_at),'is_creator',t.created_by=auth.uid(),'target',(t.settings->>'target')::int,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'players',to_jsonb(b.players),'payload',jsonb_build_object('sessions',jsonb_build_array(jsonb_build_object('current',jsonb_build_object('rounds','[]'::jsonb)))));
 end if;
 select jsonb_build_array((ps->0->>'full_name')||' & '||(ps->1->>'full_name'),(ps->2->>'full_name')||' & '||(ps->3->>'full_name')) into team_names;
 member_stamp:=md5(ps::text);select md5(string_agg(id::text||':'||revision::text,',' order by id)) into tour_stamp from public.hh_tournament_tables where tournament_id=t.id;
 if b.revision=p_revision and member_stamp=p_member_stamp then return jsonb_build_object('unchanged',true,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'current_stage',t.stage,'status',t.status,'done',b.done,'is_creator',t.created_by=auth.uid(),'started_at',coalesce(b.table_started_at,t.created_at));end if;
 select coalesce(jsonb_agg(value||jsonb_build_object('gameType','Bierkopf','teams',team_names,'members','[[1,2],[3,4]]'::jsonb,'rounds',(select coalesce(jsonb_agg(r||jsonb_build_object('teams',team_names)),'[]') from jsonb_array_elements(value->'rounds') r)) order by ordinality),'[]') into gs from jsonb_array_elements(b.games) with ordinality;
 payload:=jsonb_build_object('people',ps,'sessions',jsonb_build_array(jsonb_build_object('id',b.stage,'date',t.created_at,'gameType','Bierkopf','nextGameType','Bierkopf','teams',team_names,'members','[[1,2],[3,4]]'::jsonb,'games',gs,'current',jsonb_build_object('scores',to_jsonb(b.scores),'rounds',(select coalesce(jsonb_agg(r||jsonb_build_object('teams',team_names)),'[]') from jsonb_array_elements(b.rounds) r),'closed',b.done),'dismissed',false)));
 return jsonb_build_object('member_stamp',member_stamp,'tour_stamp',tour_stamp,'table_id',b.id,'tournament_id',t.id,'title','Turnier '||t.title||' · Tisch '||b.table_no,'table_no',b.table_no,'stage',b.stage,'current_stage',t.stage,'status',t.status,'done',b.done,'created_at',t.created_at,'started_at',coalesce(b.table_started_at,t.created_at),'is_creator',t.created_by=auth.uid(),'target',(t.settings->>'target')::int,'revision',b.revision,'players',to_jsonb(b.players),'payload',payload);
end $function$;
create or replace function public.hh_table_capture_state(p_table uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare b public.hh_tournament_tables;t public.hh_tournaments;people jsonb;begin
 select * into b from public.hh_tournament_tables where id=p_table;select * into t from public.hh_tournaments where id=b.tournament_id;
 select jsonb_agg(jsonb_build_object('name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name,'Spieler'),'photo',p.avatar) order by n) into people from unnest(b.players) with ordinality a(uid,n) left join public.hh_profiles p on p.user_id=a.uid left join public.hh_account_details d on d.user_id=p.user_id left join public.hh_tournament_guests g on g.id=a.uid;
 return jsonb_build_object('game',coalesce(t.settings->>'game','Bierkopf'),'table_id',b.id,'schaf_scores',to_jsonb(b.scores),'schaf_games',b.games,'allowed_games',t.settings->'variants','capture_colors',coalesce((t.settings->>'capture_colors')::boolean,false),'title','Turnier '||t.title||' · Tisch '||b.table_no,'stage',b.stage,'target',(t.settings->>'target')::int,'revision',b.revision,'scores',to_jsonb(b.scores),'rounds',b.rounds,'games',jsonb_array_length(b.games),'done',b.done,'people',people,'started_at',coalesce(b.table_started_at,t.created_at));
end$$;
create or replace function public.hh_schaf_public_rounds(v jsonb) returns jsonb language sql immutable set search_path='' as $$select coalesce(jsonb_agg(jsonb_build_object('variant',r->'variant','suit',r->'suit','seat',r->'seat','partner',r->'partner','won',r->'won','bonus',r->'bonus','scores',r->'scores','awards',r->'awards','actor_name',r->'actor_name','duration_seconds',r->'duration_seconds') order by n),'[]'::jsonb) from jsonb_array_elements(coalesce(v,'[]')) with ordinality x(r,n)$$;
create or replace function public.hh_tournament_lobby() returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]') into result from(
 select t.id,t.title,t.status,t.stage,t.settings,t.created_at,t.finished_at,b.id as table_id,b.table_no,b.scores,b.done,jsonb_array_length(b.games) as completed,
 exists(select 1 from public.hh_tournament_tables h where h.tournament_id=t.id and auth.uid()=any(h.players)) as participant,
 (select coalesce(jsonb_agg(jsonb_build_object('user_id',p.user_id,'username',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name),'full_name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name),'first_name',coalesce(d.first_name,g.first_name),'last_name',coalesce(d.last_name,g.last_name),'avatar',p.avatar) order by u.n),'[]') from unnest(b.players) with ordinality u(id,n) left join public.hh_profiles p on p.user_id=u.id left join public.hh_tournament_guests g on g.id=u.id left join public.hh_account_details d on d.user_id=p.user_id) as people
 from public.hh_tournaments t left join public.hh_tournament_tables b on b.tournament_id=t.id and b.stage=t.stage and auth.uid()=any(b.players)
 where (t.status='running' and b.id is not null) or t.status in('finished','cancelled'))q;
 return result;
end $$;
notify pgrst,'reload schema';
commit;
