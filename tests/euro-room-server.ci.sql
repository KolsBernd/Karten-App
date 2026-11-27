\set ON_ERROR_STOP on
-- Entire database is disposable CI data, with no credentials or production calls.
create schema auth;create schema extensions;
create extension pgcrypto with schema extensions;
create role anon;create role authenticated;
create table auth.users(id uuid primary key,email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon;
create table public.hh_profiles(user_id uuid primary key references auth.users,username text unique,display_username text);
create table public.hh_rooms(id uuid primary key,created_by uuid,ended_at timestamptz,last_activity_at timestamptz default now());
create table public.hh_states(room_id uuid primary key references public.hh_rooms on delete cascade,payload jsonb,revision bigint default 0);
create table public.hh_members(room_id uuid references public.hh_rooms on delete cascade,user_id uuid references auth.users,primary key(room_id,user_id));
create table public.hh_audit(room_id uuid,revision bigint,action text);
create table public.hh_reset_control(singleton boolean primary key,generation int default 0);
insert into public.hh_reset_control values(true,0);
create function public.hh_is_member(p_room uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.hh_members where room_id=p_room and user_id=auth.uid())$$;
create function public.hh_set_room_status(p_room uuid,p_end boolean) returns void language plpgsql security definer set search_path='' as $$begin if not public.hh_is_member(p_room) then raise exception 'Kein Zugriff';end if;update public.hh_rooms set ended_at=case when p_end then now() else null end where id=p_room;end$$;
create function public.hh_admin_reset(p_action text,p_scope text default null,p_token text default null) returns jsonb language plpgsql security definer set search_path='' as $$begin perform pg_advisory_xact_lock(194717,29);update public.hh_reset_control set generation=generation+1 where singleton;return '{}';end$$;
insert into auth.users values('00000000-0000-0000-0000-000000000001',now()),('00000000-0000-0000-0000-000000000002',now()),('00000000-0000-0000-0000-000000000003',now()),('00000000-0000-0000-0000-000000000004',now());
insert into public.hh_profiles values('00000000-0000-0000-0000-000000000001','kolsbernd','Kolsbernd'),('00000000-0000-0000-0000-000000000002','yannik','Yannik'),('00000000-0000-0000-0000-000000000003','mitspieler','Mitspieler'),('00000000-0000-0000-0000-000000000004','fremd','Fremd');
insert into public.hh_rooms(id,created_by) values('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003');
insert into public.hh_members values('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002'),('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'),('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003');
insert into public.hh_states select id,'{"people":[{"id":1,"name":"Spieler 1"},{"id":2,"name":"Spieler 2"},{"id":3,"name":"Spieler 3"},{"id":4,"name":"Spieler 4"}],"sessions":[{"id":1,"gameType":"Bierkopf","current":{"scores":[0,0],"rounds":[],"closed":false}}]}'::jsonb,0 from public.hh_rooms;
\i 49-euro-raumspiel.sql
create temporary table vectors(v jsonb);
\copy vectors from 'tests/euro-vectors.ndjson'
do $$declare x jsonb;y jsonb;n int:=0;begin for x in select v from vectors loop y:=public.hh_euro_value(public.hh_euro_config(x->'cfg'),x->'input');assert y->'quarters'=x->'quarters','JS/SQL amount differs';assert y->'balances'=x->'balances','JS/SQL balances differ';n:=n+1;end loop;raise notice '% JS/SQL parity cases passed',n;end$$;
do $$declare r uuid:='10000000-0000-0000-0000-000000000001';state jsonb;before jsonb;body jsonb;nonce uuid:=gen_random_uuid();sid text;revision bigint;begin
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
 select payload into before from public.hh_states where room_id=r;
 state:=public.hh_euro_room('activate',r,0,gen_random_uuid());sid:=state->'data'->'current'->>'id';revision:=(state->>'revision')::bigint;
 body:=jsonb_build_object('series_id',sid,'input','{"game":"Solo","seat":0,"spikes":[],"result":"normal","tout":false,"light":false,"won":true,"announcement":1,"laid":0,"knockers":0,"jungfrauen":[]}'::jsonb);
 state:=public.hh_euro_room('add',r,revision,nonce,body);assert state->'data'->'current'->'totals'='[240,-80,-80,-80]'::jsonb;
 state:=public.hh_euro_room('add',r,revision,nonce,body);assert jsonb_array_length(state->'data'->'current'->'rounds')=1,'Retry duplicated hand';revision:=(state->>'revision')::bigint;
 begin perform public.hh_euro_room('add',r,revision-1,gen_random_uuid(),body);raise exception 'Missing revision guard';exception when serialization_failure then null;end;
 begin perform public.hh_euro_room('configure',r,revision,gen_random_uuid(),jsonb_build_object('series_id',sid,'config',public.hh_euro_defaults(),'players','[1,2,3,4]'::jsonb));raise exception 'Missing settings lock';exception when others then if sqlerrm='Missing settings lock' then raise;end if;end;
 begin perform public.hh_set_room_status(r,true);raise exception 'Missing close guard';exception when others then if sqlerrm='Missing close guard' then raise;end if;end;
 begin update public.hh_states set payload=jsonb_set(payload,'{sessions,0,gameType}','"Schafkopf"') where room_id=r;raise exception 'Missing parallel game guard';exception when others then if sqlerrm='Missing parallel game guard' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
 state:=public.hh_euro_room('get',r);assert (state->>'can_write')::boolean=false;
 begin perform public.hh_euro_room('finish',r,revision,gen_random_uuid(),jsonb_build_object('series_id',sid));raise exception 'Nonwriter closed sheet';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
 begin perform public.hh_euro_room('get',r);raise exception 'Outsider read finance';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
 state:=public.hh_euro_room('finish',r,revision,gen_random_uuid(),jsonb_build_object('series_id',sid));assert (state->'data'->'current'->>'closed')::boolean;assert jsonb_array_length(state->'data'->'history')=1;assert jsonb_array_length(state->'data'->'current'->'transfers')=3;
 revision:=(state->>'revision')::bigint;state:=public.hh_euro_room('undo',r,revision,gen_random_uuid(),jsonb_build_object('series_id',sid));assert not(state->'data'->'current'->>'closed')::boolean;assert jsonb_array_length(state->'data'->'history')=0;assert jsonb_array_length(state->'data'->'current'->'rounds')=0;
 assert (select payload=before from public.hh_states where room_id=r),'Euro modified global statistics payload';
 assert not has_table_privilege('authenticated','public.hh_euro_rooms','select'),'Raw financial table exposed';assert not has_function_privilege('anon','public.hh_euro_room(text,uuid,bigint,uuid,jsonb)','execute'),'Anonymous RPC exposed';
 assert (select last_activity_at>now()-interval '1 minute' from public.hh_rooms where id=r),'Activity not updated';
 insert into public.hh_audit values(r,1,'update');update public.hh_audit set action='reset' where room_id=r;assert not(select(data->>'active')::boolean from public.hh_euro_rooms where room_id=r),'Room reset left Euro active';
 update public.hh_reset_control set generation=generation+1 where singleton;assert (select jsonb_array_length(data->'history')=0 from public.hh_euro_rooms where room_id=r);
 delete from public.hh_rooms where id=r;assert not exists(select 1 from public.hh_euro_rooms where room_id=r),'Room deletion retained finance';
 raise notice 'Euro lifecycle, auth, concurrency, reset and non-global-statistics tests passed';
end$$;
