begin;
-- Bind this capability once to the existing account, never to editable profile text.
create table if not exists public.hh_reset_control(singleton boolean primary key default true check(singleton),admin_id uuid not null references auth.users(id),generation integer not null default 0);
alter table public.hh_reset_control enable row level security;
revoke all on public.hh_reset_control from public,anon,authenticated;
insert into public.hh_reset_control(singleton,admin_id) select true,user_id from public.hh_profiles where username='kolsbernd' on conflict(singleton) do nothing;
do $$begin if not exists(select 1 from public.hh_reset_control) then raise exception 'Das bestehende Konto kolsbernd fehlt';end if;end$$;
create table if not exists public.hh_reset_challenges(token_hash bytea primary key,user_id uuid not null references auth.users(id) on delete cascade,scope text not null check(scope in('statistics','app')),expires_at timestamptz not null);
alter table public.hh_reset_challenges enable row level security;
revoke all on public.hh_reset_challenges from public,anon,authenticated;

-- Reuse the neutral new-room push category and its existing opt-in.
alter table public.hh_notifications add column if not exists evening_id uuid references public.hh_evenings(id) on delete set null;
create or replace function public.hh_evening_created_notice() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.hh_notifications(user_id,actor_id,kind,evening_id,event_title,event_starts_at,event_reason,dedupe_key)
 select case when f.sender_id=new.created_by then f.receiver_id else f.sender_id end,new.created_by,'new_room',new.id,new.title,new.starts_at,'created','evening-created:'||new.id::text||':'||f.id::text
 from public.hh_friendships f where f.status='accepted' and new.created_by in(f.sender_id,f.receiver_id) and not public.hh_pair_blocked(f.sender_id,f.receiver_id)
 on conflict(dedupe_key) do nothing;return new;
end$$;
revoke all on function public.hh_evening_created_notice() from public,anon,authenticated;
drop trigger if exists hh_evening_created_notice on public.hh_evenings;
create trigger hh_evening_created_notice after insert on public.hh_evenings for each row execute function public.hh_evening_created_notice();
create or replace function public.hh_request_notice_allowed(p_evening uuid,p_actor uuid,p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.hh_are_friends(p_actor,p_user) and not public.hh_pair_blocked(p_actor,p_user) and exists(select 1 from public.hh_evenings where id=p_evening and created_by=p_actor and archived_at is null and not converted and status<>'started');
$$;
revoke all on function public.hh_request_notice_allowed(uuid,uuid,uuid) from public,anon,authenticated;
create or replace function public.hh_notifications_snapshot() returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 select jsonb_build_object('badge_count',public.hh_badge_count_for(auth.uid()),'badge_at',clock_timestamp(),'unread',(select count(*) from public.hh_notifications where user_id=auth.uid() and (event_reason is distinct from 'created' or public.hh_request_notice_allowed(evening_id,actor_id,user_id) and public.hh_can_see_evening(evening_id)) and not exists(select 1 from public.hh_message_dismissals d where d.user_id=auth.uid() and d.message_key='note:'||hh_notifications.id::text) and kind in('new_room','friend_accepted','evening_cancelled') and read_at is null),'messages',coalesce((select jsonb_agg(to_jsonb(x)) from(
 select n.id,n.kind,n.friendship_id,n.created_at,n.read_at,n.event_title,n.event_starts_at,n.event_reason,n.evening_id,coalesce(p.display_username,p.username,'Nutzer') username,p.avatar,
 case when n.room_id is not null and public.hh_can_discover_room(n.room_id) then n.room_id else null end room_id,
 case when n.room_id is not null and public.hh_can_discover_room(n.room_id) then r.title else null end room_title
 from public.hh_notifications n left join public.hh_profiles p on p.user_id=n.actor_id left join public.hh_rooms r on r.id=n.room_id where n.user_id=auth.uid() and (n.event_reason is distinct from 'created' or public.hh_request_notice_allowed(n.evening_id,n.actor_id,n.user_id) and public.hh_can_see_evening(n.evening_id)) and not exists(select 1 from public.hh_message_dismissals d where d.user_id=auth.uid() and d.message_key='note:'||n.id::text) and n.kind in('new_room','friend_accepted','evening_cancelled') order by n.created_at desc,n.id desc limit 100)x),'[]'::jsonb)) into result;return result;
end $$;


create or replace function public.hh_claim_push() returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;begin
 update public.hh_push_jobs set status='failed' where status='pending' and attempts>=5 and coalesce(locked_until,'-infinity')<now();
 update public.hh_push_jobs j set status='cancelled' from public.hh_notifications n,public.hh_push_subscriptions s where n.id=j.notification_id and s.id=j.subscription_id and j.status='pending' and(n.created_at<now()-interval '24 hours' or exists(select 1 from public.hh_message_dismissals d where d.user_id=n.user_id and d.message_key='note:'||n.id::text) or n.kind='friend_request' and(not s.friend_requests or not exists(select 1 from public.hh_friendships f where f.id=n.friendship_id and f.status='pending' and f.receiver_id=n.user_id)) or n.kind='evening_cancelled' and not s.new_rooms or n.kind='new_room' and(not s.new_rooms or not public.hh_are_friends(n.actor_id,n.user_id) or (case when n.evening_id is not null then not public.hh_request_notice_allowed(n.evening_id,n.actor_id,n.user_id) else not exists(select 1 from public.hh_rooms r where r.id=n.room_id and r.ended_at is null) end)));
 with due as(select id from public.hh_push_jobs where status='pending' and attempts<5 and next_attempt<=now() and coalesce(locked_until,'-infinity')<now() order by next_attempt limit 10 for update skip locked),claimed as(update public.hh_push_jobs j set attempts=attempts+1,locked_until=now()+interval '60 seconds' from due where j.id=due.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('job_id',c.id,'notification_id',n.id,'kind',n.kind,'badge_count',public.hh_badge_count_for(n.user_id),'badge_at',clock_timestamp(),'subscription',extensions.pgp_sym_decrypt(s.subscription_ciphertext,public.hh_push_storage_key())::jsonb)),'[]'::jsonb) into result from claimed c join public.hh_notifications n on n.id=c.notification_id join public.hh_push_subscriptions s on s.id=c.subscription_id;return result;
end $$;
create or replace function public.hh_badge_count_for(p_user uuid) returns integer language sql stable security definer set search_path='' as $$
 select least(9999,((select count(*) from public.hh_notifications n where n.user_id=p_user and (n.event_reason is distinct from 'created' or public.hh_request_notice_allowed(n.evening_id,n.actor_id,p_user)) and n.kind in('new_room','friend_accepted','evening_cancelled') and n.read_at is null and not exists(select 1 from public.hh_message_dismissals d where d.user_id=p_user and d.message_key='note:'||n.id::text))+(select count(*) from public.hh_friendships f where f.receiver_id=p_user and f.status='pending')+(select count(*) from public.hh_join_requests j join public.hh_rooms r on r.id=j.room_id where r.created_by=p_user and j.status='pending')+(select count(*) from public.hh_evening_players x join public.hh_evenings e on e.id=x.evening_id where e.created_by=p_user and x.status='pending' and e.archived_at is null and e.starts_at>now()-interval '4 hours' and not public.hh_pair_blocked(p_user,x.user_id)))::integer)
$$;
revoke all on function public.hh_badge_count_for(uuid) from public,anon,authenticated;

create or replace function public.hh_admin_reset(p_action text,p_scope text default null,p_token text default null) returns jsonb language plpgsql security definer set search_path='' as $$
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
  for st in select * from public.hh_states for update loop
   last_session:=st.payload->'sessions'->-1;
   clean:=jsonb_build_object('id',floor(extract(epoch from clock_timestamp())*1000)::bigint,'date',clock_timestamp(),'teams',coalesce(last_session->'teams','["Team 1","Team 2"]'),'members',coalesce(last_session->'members','[[],[]]'),'teamSetups',coalesce(last_session->'teamSetups','{}'),'gameType',coalesce(last_session->'gameType','"Bierkopf"'),'games','[]'::jsonb,'current',jsonb_build_object('scores','[0,0]'::jsonb,'rounds','[]'::jsonb,'closed',false),'dismissed',false);
   update public.hh_states set payload=jsonb_set(st.payload,'{sessions}',jsonb_build_array(clean)),revision=revision+1,updated_at=now(),changed_by=uid where room_id=st.room_id;
  end loop;
  delete from public.hh_audit;
  delete from public.hh_game_segments;
  insert into public.hh_game_segments(room_id,game_type,started_at) select r.id,coalesce(rs.payload->'sessions'->-1->>'gameType','Bierkopf'),now() from public.hh_rooms r join public.hh_states rs on rs.room_id=r.id where r.ended_at is null;
  delete from public.hh_tournament_tables where stage<>1;
  update public.hh_tournament_tables set games='[]',scores=array[0,0],rounds='[]',done=false,revision=revision+1;
  update public.hh_tournaments set status='draft',stage=1,finished_at=null;
  delete from public.hh_table_capture_sessions;delete from public.hh_table_capture_links;delete from public.hh_tournament_invites;
 else
  delete from public.hh_evenings;
  delete from public.hh_rooms;
  delete from public.hh_tournaments;
  delete from public.hh_tournament_guests;
  delete from public.hh_chat_history_packets;delete from public.hh_chat_reactions;delete from public.hh_evening_messages;
  delete from public.hh_notifications;delete from public.hh_message_dismissals;delete from public.hh_friendships where status<>'accepted';
  delete from public.hh_lobby_presence;
 end if;
 delete from public.hh_saved_player_results;
 insert into public.hh_statistics_resets(user_id,since) select user_id,clock_timestamp() from public.hh_profiles on conflict(user_id) do update set since=excluded.since;
 delete from public.hh_reset_challenges;
 update public.hh_reset_control set generation=generation+1 where singleton returning generation into gen;
 return jsonb_build_object('generation',gen,'scope',scope);
end$$;
revoke all on function public.hh_admin_reset(text,text,text) from public,anon;
grant execute on function public.hh_admin_reset(text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
