begin;
alter table public.hh_saved_player_results drop constraint if exists hh_saved_player_results_game_type_check;
alter table public.hh_saved_player_results add constraint hh_saved_player_results_game_type_check check(game_type in('Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf','21 rückwärts'));
create or replace function public.hh_global_statistics_v10(p_game text,p_days integer) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 if p_game is null or p_game not in ('all','Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf','21 rückwärts') or p_days is null or p_days not in (0,7,30,90,365) then raise exception 'Ungültiger Statistikfilter';end if;
 with sessions as (
 select st.room_id,st.payload->'people' people,a from public.hh_states st cross join lateral jsonb_array_elements(coalesce(st.payload->'sessions','[]')) a
 ), raw_records as (
 select room_id,people,coalesce(g->>'gameType','Bierkopf') type,g, jsonb_array_length(coalesce(g->'rounds','[]')) rounds from sessions cross join lateral jsonb_array_elements(coalesce(a->'games','[]')) g
 union all select room_id,people,'Schniffelkopf',g,jsonb_array_length(coalesce(g->'entries','[]')) from sessions cross join lateral jsonb_array_elements(coalesce(a->'snHistory','[]')) g where g->>'closed'='true'
 union all select room_id,people,'Klopfer',g,jsonb_array_length(coalesce(g->'rounds','[]')) from sessions cross join lateral jsonb_array_elements(coalesce(a->'klHistory','[]')) g where g->>'closed'='true'
 union all select room_id,people,g->>'gameType',g,jsonb_array_length(coalesce(g->'rounds','[]')) from sessions cross join lateral jsonb_array_elements(coalesce(a->'extraHistory','[]')) g where g->>'closed'='true'
 ), records as (select * from raw_records where (p_game='all' or type=p_game) and (p_days=0 or public.hh_record_time(g->>'date')>=now()-make_interval(days=>p_days))), team_results as (
 select r.room_id,r.people,r.type,public.hh_record_time(r.g->>'date') played_at,pid #>> '{}' pid,(side::text=r.g->>'winner') won from records r cross join generate_series(0,1) side cross join lateral jsonb_array_elements(coalesce(r.g->'members'->side,'[]')) pid where r.type in ('Bierkopf','Schleifer')
 ), sheets as (
 select r.*,row_number() over() sheet_id from records r where type in ('Schniffelkopf','Klopfer','Schafkopf','21 rückwärts')
 ), solo_points as (
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}'),0) points from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Schniffelkopf'
 union all
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'rounds','[]')) rnd cross join lateral jsonb_array_elements(coalesce(rnd->'results','[]')) e where e->>'id'=pid #>> '{}'),0) from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Klopfer'
 union all select room_id,people,type,sheet_id,public.hh_record_time(g->>'date'),e->>'id',(e->>'points')::numeric from sheets cross join lateral jsonb_array_elements(public.hh_extra_statistics(g)) e where type in('Schafkopf','21 rückwärts')
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
 union all select room_id,people,g->>'gameType',g from sessions cross join lateral jsonb_array_elements(coalesce(a->'extraHistory','[]')) g where g->>'closed'='true'
), teams as (
 select kind,public.hh_record_time(g->>'date') played_at,coalesce((g->>'winner')::int=side,false) won,
 coalesce((g->'scores'->>side)::numeric,0) points,coalesce((g->'scores'->>side)::numeric,0)-coalesce((g->'scores'->>(1-side))::numeric,0) net
 from records cross join generate_series(0,1) side
 where kind in('Bierkopf','Schleifer') and exists(select 1 from jsonb_array_elements(coalesce(people,'[]')) person where person->>'authUserId'=p_user::text and g->'members'->side @> jsonb_build_array(person->'id'))
), sheets as (
 select r.*,row_number() over() sheet_id from records r where kind in('Schniffelkopf','Klopfer','Schafkopf','21 rückwärts')
), solo as (
 select r.*,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}'),0) points
 from sheets r cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where kind='Schniffelkopf'
 union all
 select r.*,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'rounds','[]')) rnd cross join lateral jsonb_array_elements(coalesce(rnd->'results','[]')) e where e->>'id'=pid #>> '{}'),0)
 from sheets r cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where kind='Klopfer'
 union all select r.*,e->>'id',(e->>'points')::numeric from sheets r cross join lateral jsonb_array_elements(public.hh_extra_statistics(g)) e where kind in('Schafkopf','21 rückwärts')
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
create or replace function public.hh_keep_registered_results() returns trigger language plpgsql security definer set search_path='' as $$
declare body jsonb;a jsonb;g jsonb;person jsonb;pid jsonb;uid uuid;side integer;pts numeric;earned numeric;net numeric;best numeric;si integer:=0;gi integer;kind text;items jsonb;key text;score numeric;winner boolean;side_index integer;extra_result jsonb;
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
 end loop;
 for a in select value from jsonb_array_elements(coalesce(body->'sessions','[]')) loop
  for g,gi in select value,ordinality::int from jsonb_array_elements(coalesce(a->'extraHistory','[]')) with ordinality loop
   for extra_result in select value from jsonb_array_elements(public.hh_extra_statistics(g)) loop
    select p.user_id into uid from jsonb_array_elements(body->'people') pp(value) join public.hh_profiles p on p.user_id::text=pp.value->>'authUserId' join public.hh_members m on m.user_id=p.user_id and m.room_id=old.id where pp.value->'id'=extra_result->'id';
    if uid is null then continue;end if;
    insert into public.hh_saved_player_results(source_room,record_key,user_id,game_type,played_at,won,points,round_count,gross_points,net_points) values(old.id,'extra:'||(a->>'id')||':'||gi,uid,g->>'gameType',public.hh_record_time(g->>'date'),(extra_result->>'won')::boolean,(extra_result->>'points')::numeric,jsonb_array_length(g->'rounds'),(extra_result->>'points')::numeric,null) on conflict do nothing;
   end loop;
  end loop;
 end loop;
return old;
end$$;
create or replace function public.hh_public_score_fields(v jsonb,depth int default 0) returns jsonb language plpgsql immutable set search_path='' as $$declare k text;x jsonb;out jsonb;begin
 if depth>30 then return 'null';end if;
 if jsonb_typeof(v)='array' then select coalesce(jsonb_agg(public.hh_public_score_fields(value,depth+1)),'[]') into out from jsonb_array_elements(v);return out;
 elsif jsonb_typeof(v)='object' then out:='{}';for k,x in select * from jsonb_each(v) loop
  if k=any(array['id','date','teams','members','gameType','games','current','scores','rounds','closed','winner','points','base','mult','schleiferCount','actor_name','duration_seconds','snSheet','snHistory','klSheet','klHistory','players','entries','player','category','opponents','results','bid','tricks','announced','actual','target','correct','entry_format','extraGames','extraHistory','Schafkopf','21 rückwärts','suit','excluded','variant','seat','partner','won','bonus','awards']) then out:=out||jsonb_build_object(k,public.hh_public_score_fields(x,depth+1));end if;
 end loop;return out;end if;return v;
end$$;
revoke all on function public.hh_public_score_fields(jsonb,int) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
