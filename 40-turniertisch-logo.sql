-- Version 39: tournament logos in existing authorized table/capture snapshots.
-- No access changes or result mutations. Unchanged poll responses stay compact.
begin;
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
 member_stamp:=md5(ps::text||coalesce(t.settings->>'logo',''));select md5(string_agg(id::text||':'||revision::text,',' order by id)) into tour_stamp from public.hh_tournament_tables where tournament_id=t.id;
 if b.revision=p_revision and member_stamp=p_member_stamp then return jsonb_build_object('unchanged',true,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'current_stage',t.stage,'status',t.status,'done',b.done,'is_creator',t.created_by=auth.uid());end if;
 return jsonb_build_object('tournament_logo',t.settings->'logo','game','Schafkopf','people',ps,'schaf_scores',to_jsonb(b.scores),'schaf_games',b.games,'allowed_games',t.settings->'variants','capture_colors',coalesce((t.settings->>'capture_colors')::boolean,false),'table_id',b.id,'tournament_id',t.id,'title','Turnier '||t.title||' · Tisch '||b.table_no,'table_no',b.table_no,'stage',b.stage,'current_stage',t.stage,'status',t.status,'done',b.done,'created_at',t.created_at,'started_at',coalesce(b.table_started_at,t.created_at),'is_creator',t.created_by=auth.uid(),'target',(t.settings->>'target')::int,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'players',to_jsonb(b.players),'payload',jsonb_build_object('sessions',jsonb_build_array(jsonb_build_object('current',jsonb_build_object('rounds','[]'::jsonb)))));
 end if;
 select jsonb_build_array((ps->0->>'full_name')||' & '||(ps->1->>'full_name'),(ps->2->>'full_name')||' & '||(ps->3->>'full_name')) into team_names;
 member_stamp:=md5(ps::text||coalesce(t.settings->>'logo',''));select md5(string_agg(id::text||':'||revision::text,',' order by id)) into tour_stamp from public.hh_tournament_tables where tournament_id=t.id;
 if b.revision=p_revision and member_stamp=p_member_stamp then return jsonb_build_object('unchanged',true,'revision',b.revision,'member_stamp',member_stamp,'tour_stamp',tour_stamp,'current_stage',t.stage,'status',t.status,'done',b.done,'is_creator',t.created_by=auth.uid(),'started_at',coalesce(b.table_started_at,t.created_at));end if;
 select coalesce(jsonb_agg(value||jsonb_build_object('gameType','Bierkopf','teams',team_names,'members','[[1,2],[3,4]]'::jsonb,'rounds',(select coalesce(jsonb_agg(r||jsonb_build_object('teams',team_names)),'[]') from jsonb_array_elements(value->'rounds') r)) order by ordinality),'[]') into gs from jsonb_array_elements(b.games) with ordinality;
 payload:=jsonb_build_object('people',ps,'sessions',jsonb_build_array(jsonb_build_object('id',b.stage,'date',t.created_at,'gameType','Bierkopf','nextGameType','Bierkopf','teams',team_names,'members','[[1,2],[3,4]]'::jsonb,'games',gs,'current',jsonb_build_object('scores',to_jsonb(b.scores),'rounds',(select coalesce(jsonb_agg(r||jsonb_build_object('teams',team_names)),'[]') from jsonb_array_elements(b.rounds) r),'closed',b.done),'dismissed',false)));
 return jsonb_build_object('tournament_logo',t.settings->'logo','member_stamp',member_stamp,'tour_stamp',tour_stamp,'table_id',b.id,'tournament_id',t.id,'title','Turnier '||t.title||' · Tisch '||b.table_no,'table_no',b.table_no,'stage',b.stage,'current_stage',t.stage,'status',t.status,'done',b.done,'created_at',t.created_at,'started_at',coalesce(b.table_started_at,t.created_at),'is_creator',t.created_by=auth.uid(),'target',(t.settings->>'target')::int,'revision',b.revision,'players',to_jsonb(b.players),'payload',payload);
end $function$;
create or replace function public.hh_table_capture_state(p_table uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare b public.hh_tournament_tables;t public.hh_tournaments;people jsonb;begin
 select * into b from public.hh_tournament_tables where id=p_table;select * into t from public.hh_tournaments where id=b.tournament_id;
 select jsonb_agg(jsonb_build_object('name',coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,g.first_name||' '||g.last_name,'Spieler'),'photo',p.avatar) order by n) into people from unnest(b.players) with ordinality a(uid,n) left join public.hh_profiles p on p.user_id=a.uid left join public.hh_account_details d on d.user_id=p.user_id left join public.hh_tournament_guests g on g.id=a.uid;
 return jsonb_build_object('tournament_logo',t.settings->'logo','game',coalesce(t.settings->>'game','Bierkopf'),'table_id',b.id,'schaf_scores',to_jsonb(b.scores),'schaf_games',b.games,'allowed_games',t.settings->'variants','capture_colors',coalesce((t.settings->>'capture_colors')::boolean,false),'title','Turnier '||t.title||' · Tisch '||b.table_no,'stage',b.stage,'target',(t.settings->>'target')::int,'revision',b.revision,'scores',to_jsonb(b.scores),'rounds',b.rounds,'games',jsonb_array_length(b.games),'done',b.done,'people',people,'started_at',coalesce(b.table_started_at,t.created_at));
end$$;

commit;
