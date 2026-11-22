begin;
create table if not exists public.hh_tv_sessions(
 id uuid primary key default gen_random_uuid(),created_by uuid not null references auth.users(id) on delete cascade,
 room_id uuid references public.hh_rooms(id) on delete cascade,table_id uuid references public.hh_tournament_tables(id) on delete cascade,
 token_hash bytea not null,source_hash bytea not null,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '24 hours',revoked_at timestamptz,
 check((room_id is null)<>(table_id is null))
);
alter table public.hh_tv_sessions enable row level security;
revoke all on public.hh_tv_sessions from public,anon,authenticated;
create or replace function public.hh_tv_control(p_action text,p_target uuid default null,p_kind text default 'room') returns jsonb language plpgsql security definer set search_path='' as $$
declare raw text;source text;identifier uuid;ticket public.hh_tv_sessions;begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 if p_action='status' then select * into ticket from public.hh_tv_sessions where created_by=auth.uid() and ((p_kind='room' and room_id=p_target) or (p_kind='table' and table_id=p_target)) and revoked_at is null and expires_at>now() order by created_at desc limit 1;return case when ticket.id is null then null else jsonb_build_object('id',ticket.id,'expires_at',ticket.expires_at) end;end if;
 if p_action='stop' then update public.hh_tv_sessions set revoked_at=now() where id=p_target and created_by=auth.uid() and revoked_at is null;return jsonb_build_object('stopped',found);end if;
 if p_action<>'create' or p_kind is null or p_kind not in('room','table') then raise exception 'Ungültige TV-Aktion';end if;
 if p_kind='room' then
  perform 1 from public.hh_rooms where id=p_target and created_by=auth.uid() and ended_at is null;if not found then raise exception 'Nur der Ersteller eines aktiven Raums kann TV freigeben';end if;
  perform public.hh_room_score_qr(p_target,false);source:=public.hh_room_score_token(p_target);
 else
  perform 1 from public.hh_tournament_tables b join public.hh_tournaments t on t.id=b.tournament_id where b.id=p_target and t.created_by=auth.uid() and t.status='running' and b.stage=t.stage;if not found then raise exception 'Nur der Turnierersteller kann diesen Tisch freigeben';end if;
  perform public.hh_table_score_qr(p_target);source:=public.hh_table_score_token(p_target);
 end if;
 -- At most one active TV session per creator/target. Reissuing ends its old link.
 update public.hh_tv_sessions set revoked_at=now() where created_by=auth.uid() and (room_id=p_target or table_id=p_target) and revoked_at is null;
 raw:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.hh_tv_sessions(created_by,room_id,table_id,token_hash,source_hash) values(auth.uid(),case when p_kind='room' then p_target else null end,case when p_kind='table' then p_target else null end,extensions.digest(raw,'sha256'),extensions.digest(source,'sha256')) returning * into ticket;
 return jsonb_build_object('id',ticket.id,'token',raw,'expires_at',ticket.expires_at);
end$$;
revoke all on function public.hh_tv_control(text,uuid,text) from public,anon;
grant execute on function public.hh_tv_control(text,uuid,text) to authenticated;
create or replace function public.hh_tv_read(p_session uuid,p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare ticket public.hh_tv_sessions;source text;payload jsonb;begin
 if p_token is null or p_token!~'^[a-f0-9]{64}$' then raise exception 'TV-Freigabe nicht verfügbar';end if;
 select * into ticket from public.hh_tv_sessions where id=p_session and token_hash=extensions.digest(p_token,'sha256') and revoked_at is null and expires_at>now();
 if not found then raise exception 'TV-Freigabe beendet oder abgelaufen';end if;
 if ticket.room_id is not null then
  source:=public.hh_room_score_token(ticket.room_id);if source is null or extensions.digest(source,'sha256')<>ticket.source_hash then raise exception 'TV-Freigabe beendet';end if;
  payload:=public.hh_public_room_score(ticket.room_id,source);
 else
  source:=public.hh_table_score_token(ticket.table_id);if source is null or extensions.digest(source,'sha256')<>ticket.source_hash then raise exception 'TV-Freigabe beendet';end if;
  payload:=public.hh_public_table_score(ticket.table_id,source);
 end if;
 return jsonb_build_object('kind',case when ticket.room_id is not null then 'room' else 'table' end,'data',payload,'expires_at',ticket.expires_at);
end$$;
revoke all on function public.hh_tv_read(uuid,text) from public;
grant execute on function public.hh_tv_read(uuid,text) to anon,authenticated;
create or replace function public.hh_clean_tv_sessions() returns void language plpgsql security definer set search_path='' as $$begin
 delete from public.hh_tv_sessions where expires_at<now()-interval '1 day' or revoked_at<now()-interval '1 day';
end$$;
revoke all on function public.hh_clean_tv_sessions() from public,anon,authenticated;
select cron.schedule('kartabend-tv-retention','27 3 * * *','select public.hh_clean_tv_sessions();');
notify pgrst,'reload schema';
commit;
