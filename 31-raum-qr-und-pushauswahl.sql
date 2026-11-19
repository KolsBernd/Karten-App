begin;
create table if not exists public.hh_room_score_links(room_id uuid primary key references public.hh_rooms(id) on delete cascade,nonce uuid not null default gen_random_uuid());
alter table public.hh_room_score_links enable row level security;
revoke all on public.hh_room_score_links from public,anon,authenticated;
create or replace function public.hh_room_score_token(p_room uuid) returns text language sql stable security definer set search_path='' as $$
 select encode(extensions.hmac('room:'||l.room_id::text||':'||l.nonce::text,v.decrypted_secret,'sha256'),'hex') from public.hh_room_score_links l cross join vault.decrypted_secrets v where l.room_id=p_room and v.name='kartabend_table_score_secret' limit 1;
$$;
revoke all on function public.hh_room_score_token(uuid) from public,anon,authenticated;
create or replace function public.hh_room_score_qr(p_room uuid,p_renew boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$declare token text;begin
 perform 1 from public.hh_rooms where id=p_room and created_by=auth.uid() and ended_at is null and public.hh_is_member(id) for update;
 if not found then raise exception 'Nur der Ersteller eines geöffneten Raums darf Zuschauer-Codes erstellen';end if;
 insert into public.hh_room_score_links(room_id) values(p_room) on conflict do nothing;
 if p_renew then update public.hh_room_score_links set nonce=gen_random_uuid() where room_id=p_room;end if;
 token:=public.hh_room_score_token(p_room);if token is null then raise exception 'Zuschauerzugang nicht verfügbar';end if;return jsonb_build_object('token',token);
end$$;
revoke all on function public.hh_room_score_qr(uuid,boolean) from public,anon;
grant execute on function public.hh_room_score_qr(uuid,boolean) to authenticated;
create or replace function public.hh_end_room_score_links() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.ended_at is distinct from old.ended_at then delete from public.hh_room_score_links where room_id=new.id;end if;return new;
end$$;
revoke all on function public.hh_end_room_score_links() from public,anon,authenticated;
drop trigger if exists hh_end_room_score_links on public.hh_rooms;
create trigger hh_end_room_score_links after update of ended_at on public.hh_rooms for each row execute function public.hh_end_room_score_links();
-- Explicit allowlist: never publish raw client payload or account identifiers.
create or replace function public.hh_public_score_fields(v jsonb,depth int default 0) returns jsonb language plpgsql immutable set search_path='' as $$declare k text;x jsonb;out jsonb;begin
 if depth>30 then return 'null';end if;
 if jsonb_typeof(v)='array' then select coalesce(jsonb_agg(public.hh_public_score_fields(value,depth+1)),'[]') into out from jsonb_array_elements(v);return out;
 elsif jsonb_typeof(v)='object' then out:='{}';for k,x in select * from jsonb_each(v) loop
  if k=any(array['id','date','teams','members','gameType','games','current','scores','rounds','closed','winner','points','base','mult','schleiferCount','actor_name','duration_seconds','snSheet','snHistory','klSheet','klHistory','players','entries','player','category','opponents','results','bid','tricks','announced','actual','target']) then out:=out||jsonb_build_object(k,public.hh_public_score_fields(x,depth+1));end if;
 end loop;return out;end if;return v;
end$$;
revoke all on function public.hh_public_score_fields(jsonb,int) from public,anon,authenticated;
create or replace function public.hh_public_room_score(p_room uuid,p_token text) returns jsonb language plpgsql security definer set search_path='' as $$declare r public.hh_rooms;body jsonb;people jsonb;begin
 if p_token is null or p_token!~'^[a-f0-9]{64}$' then raise exception 'Zuschauerzugang nicht verfügbar';end if;
 select * into r from public.hh_rooms where id=p_room and ended_at is null;
 if r.id is null or public.hh_room_score_token(p_room) is null or p_token<>public.hh_room_score_token(p_room) then raise exception 'Zuschauerzugang nicht verfügbar';end if;
 select payload into body from public.hh_states where room_id=p_room;
 select coalesce(jsonb_agg(jsonb_build_object('id',p->'id','name',case when p->>'deleted'='true' then 'Gelöschter Gast' else coalesce(pro.display_username,pro.username,p->>'name','Spieler') end,'photo',case when p->>'deleted'='true' then null else coalesce(pro.avatar,p->>'photo') end) order by n),'[]') into people from jsonb_array_elements(body->'people') with ordinality a(p,n) left join public.hh_profiles pro on pro.user_id::text=p->>'authUserId';
 return jsonb_build_object('title',r.title,'people',people,'sessions',public.hh_public_score_fields(body->'sessions'),'updated_at',clock_timestamp());
end$$;
revoke all on function public.hh_public_room_score(uuid,text) from public;
grant execute on function public.hh_public_room_score(uuid,text) to anon,authenticated;
-- Separate opt-in; preserve current device choice when installing the feature.
alter table public.hh_push_subscriptions add column if not exists evening_requests boolean;
update public.hh_push_subscriptions set evening_requests=new_rooms where evening_requests is null;
alter table public.hh_push_subscriptions alter column evening_requests set default true;
alter table public.hh_push_subscriptions alter column evening_requests set not null;
create or replace function public.hh_subscribe_push_v30(p_subscription jsonb,p_friend_requests boolean default true,p_new_rooms boolean default true,p_evening_requests boolean default true) returns void
language plpgsql security definer set search_path='' as $$declare endpoint text;old_user uuid;digest bytea;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 if octet_length(p_subscription::text)>8192 then raise exception 'Geräteabonnement zu groß';end if;
 endpoint:=p_subscription->>'endpoint';
 if endpoint is null or char_length(endpoint)>4096 or endpoint !~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|([a-z0-9-]+\.)*push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)/[^[:space:]]+$' then raise exception 'Push-Dienst nicht unterstützt';end if;
 if coalesce(p_subscription->'keys'->>'p256dh','') !~ '^[A-Za-z0-9_-]{87}$' or coalesce(p_subscription->'keys'->>'auth','') !~ '^[A-Za-z0-9_-]{22}$' then raise exception 'Ungültiges Geräteabonnement';end if;
 digest:=extensions.digest(endpoint,'sha256');select user_id into old_user from public.hh_push_subscriptions where endpoint_hash=digest for update;
 if old_user is not null and old_user<>auth.uid() then raise exception 'Bitte die Push-Anmeldung dieses Geräts zunächst erneuern';end if;
 if old_user is null and (select count(*) from public.hh_push_subscriptions where user_id=auth.uid())>=10 then raise exception 'Höchstens zehn Geräte pro Konto';end if;
 insert into public.hh_push_subscriptions(user_id,endpoint_hash,subscription_ciphertext,friend_requests,new_rooms,evening_requests)
 values(auth.uid(),digest,extensions.pgp_sym_encrypt(jsonb_build_object('endpoint',endpoint,'keys',p_subscription->'keys')::text,public.hh_push_storage_key(),'cipher-algo=aes256,compress-algo=0'),coalesce(p_friend_requests,true),coalesce(p_new_rooms,true),coalesce(p_evening_requests,true))
 on conflict(endpoint_hash) do update set subscription_ciphertext=excluded.subscription_ciphertext,friend_requests=excluded.friend_requests,new_rooms=excluded.new_rooms,evening_requests=excluded.evening_requests,updated_at=now() where hh_push_subscriptions.user_id=auth.uid();
end $$;
revoke all on function public.hh_subscribe_push_v30(jsonb,boolean,boolean,boolean) from public,anon;
grant execute on function public.hh_subscribe_push_v30(jsonb,boolean,boolean,boolean) to authenticated;
-- Compatibility for older cached clients; preserve the independent preference.
create or replace function public.hh_subscribe_push(p_subscription jsonb,p_friend_requests boolean default true,p_new_rooms boolean default true) returns void language plpgsql security definer set search_path='' as $$declare pref boolean;begin
 select evening_requests into pref from public.hh_push_subscriptions where user_id=auth.uid() and endpoint_hash=extensions.digest(p_subscription->>'endpoint','sha256');
 perform public.hh_subscribe_push_v30(p_subscription,p_friend_requests,p_new_rooms,coalesce(pref,p_new_rooms));end$$;
create or replace function public.hh_push_device(p_endpoint text) returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 select jsonb_build_object('enabled',true,'friend_requests',friend_requests,'new_rooms',new_rooms,'evening_requests',evening_requests) into result from public.hh_push_subscriptions where user_id=auth.uid() and endpoint_hash=extensions.digest(p_endpoint,'sha256');return coalesce(result,'{"enabled":false}'::jsonb);end $$;
create or replace function public.hh_claim_push() returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;begin
 update public.hh_push_jobs set status='failed' where status='pending' and attempts>=5 and coalesce(locked_until,'-infinity')<now();
 update public.hh_push_jobs j set status='cancelled' from public.hh_notifications n,public.hh_push_subscriptions s where n.id=j.notification_id and s.id=j.subscription_id and j.status='pending' and(n.created_at<now()-interval '24 hours' or exists(select 1 from public.hh_message_dismissals d where d.user_id=n.user_id and d.message_key='note:'||n.id::text) or n.kind='friend_request' and(not s.friend_requests or not exists(select 1 from public.hh_friendships f where f.id=n.friendship_id and f.status='pending' and f.receiver_id=n.user_id)) or n.kind='evening_cancelled' and not s.new_rooms or n.kind='new_room' and(not(case when n.event_reason='created' then s.evening_requests else s.new_rooms end) or not public.hh_are_friends(n.actor_id,n.user_id) or (case when n.evening_id is not null then not public.hh_request_notice_allowed(n.evening_id,n.actor_id,n.user_id) else not exists(select 1 from public.hh_rooms r where r.id=n.room_id and r.ended_at is null) end)));
 with due as(select id from public.hh_push_jobs where status='pending' and attempts<5 and next_attempt<=now() and coalesce(locked_until,'-infinity')<now() order by next_attempt limit 10 for update skip locked),claimed as(update public.hh_push_jobs j set attempts=attempts+1,locked_until=now()+interval '60 seconds' from due where j.id=due.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('job_id',c.id,'notification_id',n.id,'kind',n.kind,'badge_count',public.hh_badge_count_for(n.user_id),'badge_at',clock_timestamp(),'subscription',extensions.pgp_sym_decrypt(s.subscription_ciphertext,public.hh_push_storage_key())::jsonb)),'[]'::jsonb) into result from claimed c join public.hh_notifications n on n.id=c.notification_id join public.hh_push_subscriptions s on s.id=c.subscription_id;return result;
end $$;
create or replace function public.hh_queue_notification() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.hh_push_jobs(notification_id,subscription_id) select new.id,s.id from public.hh_push_subscriptions s where s.user_id=new.user_id and ((new.kind='friend_request' and s.friend_requests) or(new.kind in('new_room','evening_cancelled') and (case when new.event_reason='created' then s.evening_requests else s.new_rooms end))) on conflict do nothing;
 perform public.hh_kick_push();return new;
end $$;
notify pgrst,'reload schema';
commit;
