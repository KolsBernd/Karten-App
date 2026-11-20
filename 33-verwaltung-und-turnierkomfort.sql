begin;
CREATE OR REPLACE FUNCTION public.hh_admin_reset(p_action text, p_scope text DEFAULT NULL::text, p_token text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid();allowed boolean;gen integer;token text;c public.hh_reset_challenges;st public.hh_states;last_session jsonb;clean jsonb;scope text:=p_scope;begin
 select admin_id=uid,generation into allowed,gen from public.hh_reset_control where singleton;
 allowed:=coalesce(allowed,false) and exists(select 1 from auth.users where id=uid and email_confirmed_at is not null);
 if p_action='status' then return jsonb_build_object('admin',allowed,'generation',coalesce(gen,0));end if;
 if not allowed then raise exception 'Nur das freigegebene Verwaltungskonto darf die App zurücksetzen';end if;
 if scope is null or scope not in('statistics','app') then raise exception 'Ungültige Rücksetzfunktion';end if;
 if p_action='prepare' then
  delete from public.hh_reset_challenges where user_id=uid or expires_at<=clock_timestamp();
  token:=encode(extensions.gen_random_bytes(32),'hex');insert into public.hh_reset_challenges values(extensions.digest(token,'sha256'),uid,scope,clock_timestamp()+interval '2 minutes');return jsonb_build_object('token',token);
 elsif p_action<>'execute' then raise exception 'Ungültige Aktion';end if;
 perform pg_advisory_xact_lock(194717,29);
 select * into c from public.hh_reset_challenges where token_hash=extensions.digest(coalesce(p_token,''),'sha256') and user_id=uid and hh_reset_challenges.scope=p_scope and expires_at>clock_timestamp() for update;
 if not found then raise exception 'Bestätigung abgelaufen oder ungültig. Bitte erneut bestätigen';end if;
 -- One transaction; exclude concurrent writes so no result survives half a reset.
 lock table public.hh_rooms,public.hh_states,public.hh_tournaments,public.hh_tournament_tables,public.hh_evenings,public.hh_saved_player_results in share row exclusive mode;
 if scope='statistics' then
  for st in select * from public.hh_states order by room_id for update loop
   last_session:=st.payload->'sessions'->-1;
   clean:=jsonb_build_object('id',floor(extract(epoch from clock_timestamp())*1000)::bigint,'date',clock_timestamp(),'teams',coalesce(last_session->'teams','["Team 1","Team 2"]'),'members',coalesce(last_session->'members','[[],[]]'),'teamSetups',coalesce(last_session->'teamSetups','{}'),'gameType',coalesce(last_session->'gameType','"Bierkopf"'),'games','[]'::jsonb,'current',jsonb_build_object('scores','[0,0]'::jsonb,'rounds','[]'::jsonb,'closed',false),'dismissed',false);
   update public.hh_states set payload=jsonb_set(st.payload,'{sessions}',jsonb_build_array(clean)),revision=revision+1,updated_at=now(),changed_by=uid where room_id=st.room_id;
  end loop;
  delete from public.hh_audit where exists(select 1 from public.hh_audit limit 1);
  delete from public.hh_game_segments where exists(select 1 from public.hh_game_segments limit 1);
  insert into public.hh_game_segments(room_id,game_type,started_at) select r.id,coalesce(rs.payload->'sessions'->-1->>'gameType','Bierkopf'),now() from public.hh_rooms r join public.hh_states rs on rs.room_id=r.id where r.ended_at is null;
  delete from public.hh_tournament_tables where stage<>1;
  update public.hh_tournament_tables set games='[]',scores=array[0,0],rounds='[]',done=false,revision=revision+1 where id is not null;
  update public.hh_tournaments set status='draft',stage=1,finished_at=null where id is not null;
  delete from public.hh_table_capture_sessions where exists(select 1 from public.hh_table_capture_sessions limit 1);delete from public.hh_table_capture_links where exists(select 1 from public.hh_table_capture_links limit 1);delete from public.hh_tournament_invites where exists(select 1 from public.hh_tournament_invites limit 1);
 else
  delete from public.hh_evenings where exists(select 1 from public.hh_evenings limit 1);
  delete from public.hh_rooms where exists(select 1 from public.hh_rooms limit 1);
  delete from public.hh_tournaments where exists(select 1 from public.hh_tournaments limit 1);
  delete from public.hh_tournament_guests where exists(select 1 from public.hh_tournament_guests limit 1);
  delete from public.hh_chat_history_packets where exists(select 1 from public.hh_chat_history_packets limit 1);delete from public.hh_chat_reactions where exists(select 1 from public.hh_chat_reactions limit 1);delete from public.hh_evening_messages where exists(select 1 from public.hh_evening_messages limit 1);
  delete from public.hh_notifications where exists(select 1 from public.hh_notifications limit 1);delete from public.hh_message_dismissals where exists(select 1 from public.hh_message_dismissals limit 1);delete from public.hh_friendships where status<>'accepted';
  delete from public.hh_lobby_presence where exists(select 1 from public.hh_lobby_presence limit 1);
 end if;
 delete from public.hh_saved_player_results where exists(select 1 from public.hh_saved_player_results limit 1);
 insert into public.hh_statistics_resets(user_id,since) select user_id,clock_timestamp() from public.hh_profiles on conflict(user_id) do update set since=excluded.since;
 delete from public.hh_reset_challenges where exists(select 1 from public.hh_reset_challenges limit 1);
 update public.hh_reset_control set generation=generation+1 where singleton returning generation into gen;
 return jsonb_build_object('generation',gen,'scope',scope);
end$function$;
revoke all on function public.hh_admin_reset(text,text,text) from public,anon;
grant execute on function public.hh_admin_reset(text,text,text) to authenticated;
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
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(select p.user_id,coalesce(p.display_username,p.username) username,p.avatar,false as guest,coalesce(d.locality,'') as locality from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id where p.username ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' union all select id,first_name||' '||last_name,null,true,locality from public.hh_tournament_guests where deleted_at is null and (first_name||' '||last_name||' '||locality) ilike '%'||left(coalesce(p_body->>'search',''),60)||'%' order by username limit 100 offset greatest(0,least(100000,coalesce((p_body->>'offset')::int,0)))) q;return result;
 end if;
 if p_action in('create','settings') then
  if not boss then raise exception 'Nur kolsbernd darf Turniere erstellen';end if;
  settings:=p_body->'settings';
  if coalesce(settings->>'game','Bierkopf')<>'Bierkopf' then raise exception 'Turniere unterstützen derzeit Bierkopf';end if;
  if coalesce(settings->>'mode','') not in('fixed','firstto') or coalesce(settings->>'rotation','') not in('none','players') or coalesce(settings->>'ranking','') not in('wins_points','full','wins') then raise exception 'Ungültige Turniereinstellungen';end if;
  need:=(settings->>'target')::int;stages:=(settings->>'stages')::int;
  if need is null or stages is null or stages not between 1 and 10 or need not between 1 and 30  then raise exception 'Partien: 1–30; Runden: 1–10';end if;
  settings:=settings||jsonb_build_object('mode','fixed','ranking','wins_points','game','Bierkopf');
  if p_action='settings' then
   select * into t from public.hh_tournaments where id=p_id for update;
   if not found or t.created_by<>uid or t.status<>'draft' then raise exception 'Einstellungen sind nach Turnierstart festgelegt';end if;
   update public.hh_tournaments set title=trim(p_body->>'title'),settings=(p_body->'settings')||jsonb_build_object('mode','fixed','ranking','wins_points','game','Bierkopf') where id=p_id;return jsonb_build_object('id',p_id);
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
  insert into public.hh_tournament_tables(tournament_id,stage,table_no,players) values(t.id,1,n,roster);
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
  perform public.hh_table_apply(tb.id,(p_body->>'revision')::bigint,p_action,p_body,uid,(select coalesce(display_username,username) from public.hh_profiles where user_id=uid));
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
    for idx in 1..n by 4 loop insert into public.hh_tournament_tables(tournament_id,stage,table_no,players) values(t.id,t.stage+1,(idx-1)/4+1,next_ids[idx:idx+3]);end loop;
    update public.hh_tournaments set stage=stage+1 where id=t.id;
   end if;
  end if;
 elsif p_action<>'detail' then raise exception 'Unbekannte Turnieraktion';end if;
 select * into t from public.hh_tournaments where id=t.id;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'stage',b.stage,'table_no',b.table_no,'players',to_jsonb(b.players),'games',case when uid=any(b.players) or t.created_by=uid then b.games else (select coalesce(jsonb_agg(g-'rounds'),'[]') from jsonb_array_elements(b.games) g) end,'scores',to_jsonb(b.scores),'rounds',case when uid=any(b.players) or t.created_by=uid then b.rounds else '[]'::jsonb end,'done',b.done,'revision',b.revision) order by b.stage,b.table_no),'[]') into result from public.hh_tournament_tables b where b.tournament_id=t.id ;
 -- Ranking input includes only reduced results, never other tables' round/actor data.
 select coalesce(jsonb_agg(jsonb_build_object('players',to_jsonb(b.players),'games',(select coalesce(jsonb_agg(g.value-'rounds'),'[]') from jsonb_array_elements(b.games) g))),'[]') into games from public.hh_tournament_tables b where b.tournament_id=t.id;
 select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('start_no',(select start_no from public.hh_tournament_numbers where tournament_id=t.id and player_id=p.user_id))),'[]') into r from(select p.user_id,p.username,p.avatar,false as guest,coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username) as full_name,d.first_name,d.last_name from public.hh_profiles p left join public.hh_account_details d on d.user_id=p.user_id union all select id,first_name||' '||last_name,null,true,first_name||' '||last_name,first_name,last_name from public.hh_tournament_guests) p where exists(select 1 from public.hh_tournament_tables b where b.tournament_id=t.id and p.user_id=any(b.players));
 return jsonb_build_object('id',t.id,'title',t.title,'status',t.status,'stage',t.stage,'settings',t.settings,'created_at',t.created_at,'finished_at',t.finished_at,'tables',result,'results',games,'people',r,'admin',t.created_by=uid,'ready',not exists(select 1 from public.hh_tournament_tables where tournament_id=t.id and stage=t.stage and not done),'created_by',t.created_by);
end $function$;
notify pgrst,'reload schema';
commit;
