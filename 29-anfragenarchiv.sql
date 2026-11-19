begin;
alter table public.hh_evenings add column if not exists archived_at timestamptz;
create index if not exists hh_evening_archive_deadline on public.hh_evenings(starts_at) where archived_at is null and status<>'started';
create or replace function public.hh_process_evenings() returns void language plpgsql security definer set search_path='' as $$declare e public.hh_evenings;counter int;begin
 for e in select * from public.hh_evenings where status<>'started' and archived_at is null and starts_at<=clock_timestamp() order by starts_at for update skip locked loop
  if e.starts_at+interval '4 hours'<=clock_timestamp() then
   update public.hh_evenings set archived_at=now() where id=e.id;
   update public.hh_evening_players set status='declined',updated_at=now() where evening_id=e.id and status='pending';
  else
   select count(*) into counter from public.hh_evening_players where evening_id=e.id and status='accepted';
   if counter>=e.capacity then perform public.hh_open_evening(e.id,false);end if;
  end if;
 end loop;
end$$;
revoke all on function public.hh_process_evenings() from public,anon,authenticated;
create or replace function public.hh_evening_action(p_action text,p_id uuid default null,p_body jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();e public.hh_evenings;u uuid;result jsonb;d timestamptz;gs text[];n int;lat double precision;lon double precision;
begin
 if uid is null or not exists(select 1 from public.hh_profiles where user_id=uid) then raise exception 'Bitte mit einem vollständigen Konto anmelden';end if;
 perform public.hh_process_evenings();
 if p_action='blocks' then select coalesce(jsonb_agg(jsonb_build_object('user_id',p.user_id,'username',p.username,'avatar',p.avatar)),'[]') into result from public.hh_user_blocks b join public.hh_profiles p on p.user_id=b.blocked where b.blocker=uid;return result;
 elsif p_action='unblock' then delete from public.hh_user_blocks where blocker=uid and blocked=p_id;return '{}';
 elsif p_action='block' then
  if p_id=uid or not exists(select 1 from public.hh_profiles where user_id=p_id) then raise exception 'Nutzer nicht verfügbar';end if;
  insert into public.hh_user_blocks(blocker,blocked) values(uid,p_id) on conflict do nothing;
  update public.hh_friendships set status=case when status='accepted' then 'removed' else 'declined' end,updated_at=now() where uid in(sender_id,receiver_id) and p_id in(sender_id,receiver_id) and status in('pending','accepted');
  update public.hh_evening_players x set status='blocked',updated_at=now() from public.hh_evenings q where x.evening_id=q.id and q.status<>'started' and ((q.created_by=uid and x.user_id=p_id) or(q.created_by=p_id and x.user_id=uid));
  return '{}';
 elsif p_action='create' then
  perform public.hh_social_throttle();
  d:=(p_body->>'starts_at')::timestamptz;
  if d is null or d<=clock_timestamp() or d>clock_timestamp()+interval '2 years' then raise exception 'Bitte einen zukünftigen Termin innerhalb von zwei Jahren wählen';end if;
  if not exists(select 1 from pg_timezone_names where name=coalesce(p_body->>'timezone','Europe/Berlin')) then raise exception 'Ungültige Zeitzone';end if;
  select array_agg(distinct value) into gs from jsonb_array_elements_text(p_body->'games');
  if cardinality(gs) is null or cardinality(gs)<1 or not gs<@array['Bierkopf','Schniffelkopf','Schleifer','Klopfen','Schafkopf'] then raise exception 'Bitte gültige Spielvarianten auswählen';end if;
  lat:=nullif(p_body->>'latitude','')::double precision;lon:=nullif(p_body->>'longitude','')::double precision;
  if (lat is null)<>(lon is null) or(lat is not null and(not(lat between -90 and 90) or not(lon between -180 and 180))) then raise exception 'Ungültiger Kartenpunkt';end if;
  insert into public.hh_evenings(title,created_by,starts_at,location,games,timezone,capacity,address,latitude,longitude) values(trim(p_body->>'title'),uid,d,trim(p_body->>'location'),gs,coalesce(p_body->>'timezone','Europe/Berlin'),case when gs=array['Schleifer'] then 6 else 4 end,trim(coalesce(p_body->>'address','')),lat,lon) returning id into u;
  insert into public.hh_evening_players(evening_id,user_id,status) values(u,uid,'accepted');return jsonb_build_object('id',u);
 elsif p_action='inbox' then
  select coalesce(jsonb_agg(jsonb_build_object('evening_id',q.id,'title',q.title,'user_id',p.user_id,'username',p.username,'avatar',p.avatar,'status',x.status,'outgoing',q.created_by<>uid,'starts_at',q.starts_at) order by x.updated_at desc),'[]') into result from public.hh_evening_players x join public.hh_evenings q on q.id=x.evening_id join public.hh_profiles p on p.user_id=case when q.created_by=uid then x.user_id else q.created_by end where q.archived_at is null and (q.created_by=uid and x.user_id<>uid or x.user_id=uid and q.created_by<>uid) and x.status in('pending','accepted','declined') and not public.hh_pair_blocked(q.created_by,x.user_id);return result;
 elsif p_action='list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'title',q.title,'created_by',q.created_by,'creator_username',(select coalesce(display_username,username) from public.hh_profiles where user_id=q.created_by),'address',q.address,'latitude',q.latitude,'longitude',q.longitude,'blocked_creator',exists(select 1 from public.hh_user_blocks where blocker=uid and blocked=q.created_by),'blocked_participants',(select coalesce(jsonb_agg(coalesce(p.display_username,p.username)),'[]') from public.hh_evening_players x join public.hh_user_blocks b on b.blocker=uid and b.blocked=x.user_id join public.hh_profiles p on p.user_id=x.user_id where x.evening_id=q.id and x.status='accepted' and x.user_id<>q.created_by),'starts_at',q.starts_at,'location',q.location,'timezone',q.timezone,'games',q.games,'status',q.status,'archived_at',q.archived_at,'capacity',q.capacity,'allow_extra',q.allow_extra,'server_now',clock_timestamp(),'room_id',case when exists(select 1 from public.hh_evening_players where evening_id=q.id and user_id=uid and status='accepted') then q.room_id else null end,'own_status',(select status from public.hh_evening_players where evening_id=q.id and user_id=uid),'accepted',(select coalesce(jsonb_agg(jsonb_build_object('user_id',p.user_id,'username',p.username,'avatar',p.avatar) order by x.created_at),'[]') from public.hh_evening_players x join public.hh_profiles p using(user_id) where x.evening_id=q.id and x.status='accepted')) order by q.starts_at),'[]') into result from public.hh_evenings q where not q.converted and (q.archived_at is null or q.created_by=uid or exists(select 1 from public.hh_evening_players z where z.evening_id=q.id and z.user_id=uid and z.status='accepted')) and public.hh_can_see_evening(q.id) and(q.status<>'started' or exists(select 1 from public.hh_evening_players where evening_id=q.id and user_id=uid and status='accepted'));return result;
 end if;
 select * into e from public.hh_evenings where id=p_id for update;
 if not found or public.hh_pair_blocked(uid,e.created_by) or not public.hh_can_see_evening(e.id) then raise exception 'Kartabendanfrage nicht verfügbar';end if;
 if e.archived_at is not null and p_action<>'remove' then raise exception 'Diese Kartabendanfrage ist archiviert';end if;
 if p_action='allow_extra' then
  if uid<>e.created_by or e.status='started' or jsonb_typeof(p_body->'allow') is distinct from 'boolean' then raise exception 'Nur der Ersteller kann zusätzliche Plätze freigeben';end if;
  if not (p_body->>'allow')::boolean and (select count(*) from public.hh_evening_players where evening_id=e.id and status='accepted')>e.capacity then raise exception 'Zusätzliche Spieler sind bereits bestätigt. Ihre Zusagen bleiben bestehen';end if;
  update public.hh_evenings set allow_extra=(p_body->>'allow')::boolean where id=e.id;
 elsif p_action='convert' then
  if uid<>e.created_by or e.status='started' then raise exception 'Nur der Ersteller kann diese Anfrage umwandeln';end if;
  u:=public.hh_open_evening(e.id,true);return jsonb_build_object('room_id',u);
 elsif p_action='edit' then
  if uid<>e.created_by or e.status='started' or e.starts_at<=clock_timestamp() then raise exception 'Nur der Ersteller kann eine noch nicht gestartete Anfrage bearbeiten';end if;
  d:=(p_body->>'starts_at')::timestamptz;
  if d is null or d<=clock_timestamp() or d>clock_timestamp()+interval '2 years' then raise exception 'Bitte einen zukünftigen Termin innerhalb von zwei Jahren wählen';end if;
  if not exists(select 1 from pg_timezone_names where name=coalesce(p_body->>'timezone',e.timezone)) then raise exception 'Ungültige Zeitzone';end if;
  select array_agg(distinct value) into gs from jsonb_array_elements_text(p_body->'games');
  if cardinality(gs) is null or cardinality(gs)<1 or not gs<@array['Bierkopf','Schniffelkopf','Schleifer','Klopfen','Schafkopf'] then raise exception 'Bitte gültige Spielvarianten auswählen';end if;
  n:=case when gs=array['Schleifer'] then 6 else 4 end;
  if not e.allow_extra and (select count(*) from public.hh_evening_players where evening_id=e.id and status='accepted')>n then raise exception 'Es sind bereits mehr Spieler bestätigt. Zusagen können nicht durch Bearbeitung entfernt werden.';end if;
  lat:=nullif(p_body->>'latitude','')::double precision;lon:=nullif(p_body->>'longitude','')::double precision;
  if (lat is null)<>(lon is null) or(lat is not null and(not(lat between -90 and 90) or not(lon between -180 and 180))) then raise exception 'Ungültiger Kartenpunkt';end if;
  update public.hh_evenings set title=trim(p_body->>'title'),starts_at=d,location=trim(p_body->>'location'),games=gs,timezone=coalesce(p_body->>'timezone',e.timezone),capacity=n,address=trim(coalesce(p_body->>'address','')),latitude=lat,longitude=lon where id=e.id;
 elsif p_action='remove' then
  if uid<>e.created_by or e.status='started' then raise exception 'Nur der Ersteller kann eine noch nicht gestartete Anfrage absagen';end if;
  delete from public.hh_evenings where id=e.id;return '{}';
 elsif p_action='request' then
  if e.status='started' or e.starts_at+interval '4 hours'<=clock_timestamp() then raise exception 'Anfrage bereits beendet';end if;
  if exists(select 1 from public.hh_evening_players where evening_id=e.id and user_id=uid and status in('pending','accepted')) then raise exception 'Du bist bereits vorgemerkt';end if;
  if (select count(*) from public.hh_evening_players where evening_id=e.id and status='accepted')>=(case when e.allow_extra then 32 else e.capacity end) then raise exception 'Alle Plätze sind bereits vergeben';end if;
  if exists(select 1 from public.hh_evening_players where evening_id=e.id and user_id=uid and updated_at>now()-interval '1 day') then raise exception 'Bitte nach einer abgelehnten Anfrage einen Tag warten';end if;
  perform public.hh_social_throttle();insert into public.hh_evening_players(evening_id,user_id,status) values(e.id,uid,'pending') on conflict(evening_id,user_id) do update set status='pending',updated_at=now();
 elsif p_action='respond' then
  if uid<>e.created_by or e.status='started' or e.starts_at+interval '4 hours'<=clock_timestamp() then raise exception 'Nur der Ersteller kann vor dem Start antworten';end if;
  u:=(p_body->>'user_id')::uuid;
  if public.hh_pair_blocked(uid,u) then raise exception 'Nutzer blockiert';end if;
  if jsonb_typeof(p_body->'accept') is distinct from 'boolean' then raise exception 'Bitte annehmen oder ablehnen';end if;
  if (p_body->>'accept')::boolean and (select count(*) from public.hh_evening_players where evening_id=e.id and status='accepted')>=(case when e.allow_extra then 32 else e.capacity end) then raise exception 'Alle Plätze sind bereits vergeben';end if;
  update public.hh_evening_players set status=case when (p_body->>'accept')::boolean then 'accepted' else 'declined' end,updated_at=now() where evening_id=e.id and user_id=u and status='pending';
  if not found then raise exception 'Anfrage nicht mehr offen';end if;
 elsif p_action='cancel' then
  if uid=e.created_by then raise exception 'Der Ersteller kann seine Zusage nicht zurückziehen';end if;
  if e.status='started' or e.starts_at+interval '4 hours'<=clock_timestamp() then raise exception 'Der Kartabend hat bereits begonnen';end if;
  update public.hh_evening_players set status='cancelled',updated_at=now() where evening_id=e.id and user_id=uid;
 else raise exception 'Unbekannte Aktion';end if;
 update public.hh_evenings set status=case when(select count(*) from public.hh_evening_players where evening_id=e.id and status='accepted')>=e.capacity then 'ready' else 'planning' end where id=e.id;
 return '{}';
end $$;
create or replace function public.hh_badge_count_for(p_user uuid) returns integer language sql stable security definer set search_path='' as $$
 select least(9999,((select count(*) from public.hh_notifications n where n.user_id=p_user and n.kind in('new_room','friend_accepted','evening_cancelled') and n.read_at is null and not exists(select 1 from public.hh_message_dismissals d where d.user_id=p_user and d.message_key='note:'||n.id::text))+(select count(*) from public.hh_friendships f where f.receiver_id=p_user and f.status='pending')+(select count(*) from public.hh_join_requests j join public.hh_rooms r on r.id=j.room_id where r.created_by=p_user and j.status='pending')+(select count(*) from public.hh_evening_players x join public.hh_evenings e on e.id=x.evening_id where e.created_by=p_user and x.status='pending' and e.archived_at is null and e.starts_at>now()-interval '4 hours' and not public.hh_pair_blocked(p_user,x.user_id)))::integer)
$$;
revoke all on function public.hh_badge_count_for(uuid) from public,anon,authenticated;
-- Archived chats remain readable, but cannot receive new messages/reactions.
create or replace function public.hh_archived_chat_guard() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.evening_id is not null and exists(select 1 from public.hh_evenings where id=new.evening_id and archived_at is not null) then raise exception 'Diese Kartabendanfrage ist archiviert. Der Chat bleibt lesbar';end if;return new;
end$$;
revoke all on function public.hh_archived_chat_guard() from public,anon,authenticated;
drop trigger if exists hh_archived_chat_guard on public.hh_evening_messages;
create trigger hh_archived_chat_guard before insert on public.hh_evening_messages for each row execute function public.hh_archived_chat_guard();
drop trigger if exists hh_archived_chat_guard on public.hh_chat_reactions;
create trigger hh_archived_chat_guard before insert on public.hh_chat_reactions for each row execute function public.hh_archived_chat_guard();
notify pgrst,'reload schema';
commit;
