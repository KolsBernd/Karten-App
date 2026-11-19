begin;
create table if not exists public.hh_share_choices(scope text not null check(scope in('room','table')),target_id uuid not null,user_id uuid not null references auth.users(id) on delete cascade,allowed boolean not null default false,notice_version text not null,decided_at timestamptz not null default now(),needs_choice boolean not null default false,primary key(scope,target_id,user_id));
create table if not exists public.hh_share_events(id bigint generated always as identity primary key,scope text not null,target_id uuid not null,user_id uuid not null references auth.users(id) on delete cascade,allowed boolean not null,notice_version text not null,notice_text text not null,decided_at timestamptz not null default now(),reason text not null);
create index if not exists hh_share_events_user_time on public.hh_share_events(user_id,decided_at);
alter table public.hh_share_choices enable row level security;alter table public.hh_share_events enable row level security;
revoke all on public.hh_share_choices,public.hh_share_events from public,anon,authenticated;
create or replace function public.hh_share_notice() returns text language sql immutable set search_path='' as $$select 'Möchtest du deine Ergebnisse gegenüber externen Zuschauern mit deinem Namen zeigen? Mit Ja erlaubst du für diesen Raum bzw. Turniertisch die Anzeige deines Benutzernamens, deines Profilbildes und deiner Spiel- und Schreibergebnisse über den weitergebbaren Zuschauer-QR-Link. Bei Turniertischen kann auch dein Vor- und Nachname erscheinen. Jeder mit dem Link kann diese Angaben ohne Anmeldung lesen und kopieren. Chats, Telefonnummer und E-Mail werden nicht veröffentlicht. Die Freigabe ist freiwillig: Nein verhindert weder Beitritt noch Mitspielen. Ohne Freigabe erscheinen Anonym und kein Profilbild; Ergebnisse bleiben sichtbar und können im kleinen Kreis trotzdem zuordenbar sein. Ändern kannst du die Auswahl jederzeit unter Raum-Einstellungen bzw. Tischstatistik oder alle Freigaben unter Einstellungen widerrufen. Bereits angefertigte Kopien lassen sich nicht zurückholen. Verantwortlicher: Bernd Dinkel; weitere Informationen unter Datenschutz.'::text$$;
revoke all on function public.hh_share_notice() from public,anon,authenticated;
create or replace function public.hh_share_allowed(p_scope text,p_target uuid,p_user uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.hh_share_choices where scope=p_scope and target_id=p_target and user_id=p_user and allowed and not needs_choice and notice_version='share-v1-2026-11-19')$$;
revoke all on function public.hh_share_allowed(text,uuid,uuid) from public,anon,authenticated;
drop function if exists public.hh_share_choice(text,uuid,boolean);
create or replace function public.hh_share_choice(p_scope text,p_target uuid,p_allow boolean default null,p_notice_version text default null) returns jsonb language plpgsql security definer set search_path='' as $$declare uid uuid:=auth.uid();ok boolean;c public.hh_share_choices;stamp timestamptz;begin
 if uid is null then raise exception 'Bitte anmelden';end if;
 if p_allow is not null and p_notice_version is distinct from 'share-v1-2026-11-19' then raise exception 'Der Freigabehinweis hat sich geändert. Bitte erneut öffnen und lesen';end if;
 if p_scope='room' then select exists(select 1 from public.hh_rooms where id=p_target and public.hh_is_member(id) and ended_at is null) into ok;
 elsif p_scope='table' then select exists(select 1 from public.hh_tournament_tables b join public.hh_tournaments t on t.id=b.tournament_id where b.id=p_target and(uid=any(b.players) or t.created_by=uid)) into ok;
 else raise exception 'Ungültiger Bereich';end if;
 if not ok and not(p_allow is false and exists(select 1 from public.hh_share_choices where scope=p_scope and target_id=p_target and user_id=uid)) then raise exception 'Kein Zugang zu diesem Raum oder Tisch';end if;
 select * into c from public.hh_share_choices where scope=p_scope and target_id=p_target and user_id=uid;
 if p_allow is not null and c.allowed=p_allow and c.notice_version='share-v1-2026-11-19' and not c.needs_choice then p_allow:=null;end if;
 if p_allow is true and(select count(*) from public.hh_share_events where user_id=uid and decided_at>clock_timestamp()-interval '1 minute')>=30 then raise exception 'Bitte einen Moment warten. Widerrufen bleibt möglich';end if;
 if p_allow is not null then
  stamp:=clock_timestamp();insert into public.hh_share_choices values(p_scope,p_target,uid,p_allow,'share-v1-2026-11-19',stamp,false) on conflict(scope,target_id,user_id) do update set allowed=excluded.allowed,notice_version=excluded.notice_version,decided_at=excluded.decided_at,needs_choice=false;
  insert into public.hh_share_events(scope,target_id,user_id,allowed,notice_version,notice_text,decided_at,reason) values(p_scope,p_target,uid,p_allow,'share-v1-2026-11-19',public.hh_share_notice(),stamp,case when p_allow then 'grant' else 'refuse_or_withdraw' end);
 end if;
 select * into c from public.hh_share_choices where scope=p_scope and target_id=p_target and user_id=uid;
 return jsonb_build_object('decision',case when c.notice_version='share-v1-2026-11-19' and not c.needs_choice then to_jsonb(c.allowed) else 'null'::jsonb end,'notice',public.hh_share_notice(),'version','share-v1-2026-11-19','decided_at',c.decided_at);
end$$;
revoke all on function public.hh_share_choice(text,uuid,boolean,text) from public,anon;grant execute on function public.hh_share_choice(text,uuid,boolean,text) to authenticated;
create or replace function public.hh_withdraw_all_sharing() returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 insert into public.hh_share_events(scope,target_id,user_id,allowed,notice_version,notice_text,reason) select scope,target_id,user_id,false,'share-v1-2026-11-19',public.hh_share_notice(),'withdraw_all' from public.hh_share_choices where user_id=auth.uid() and allowed;
 update public.hh_share_choices set allowed=false,needs_choice=false,decided_at=clock_timestamp() where user_id=auth.uid();end$$;
revoke all on function public.hh_withdraw_all_sharing() from public,anon;grant execute on function public.hh_withdraw_all_sharing() to authenticated;
create or replace function public.hh_share_scope_lifecycle() returns trigger language plpgsql security definer set search_path='' as $$declare kind text;begin
 kind:=case when tg_table_name='hh_rooms' then 'room' else 'table' end;
 if tg_op='DELETE' then delete from public.hh_share_choices where scope=kind and target_id=old.id;delete from public.hh_share_events where scope=kind and target_id=old.id;return old;end if;
 if new.ended_at is distinct from old.ended_at then
  insert into public.hh_share_events(scope,target_id,user_id,allowed,notice_version,notice_text,reason) select scope,target_id,user_id,false,'share-v1-2026-11-19',public.hh_share_notice(),'room_lifecycle' from public.hh_share_choices where scope='room' and target_id=new.id and allowed;
  update public.hh_share_choices set allowed=false,needs_choice=true where scope='room' and target_id=new.id;
 end if;return new;
end$$;
revoke all on function public.hh_share_scope_lifecycle() from public,anon,authenticated;
drop trigger if exists hh_share_room_end on public.hh_rooms;create trigger hh_share_room_end after update of ended_at on public.hh_rooms for each row execute function public.hh_share_scope_lifecycle();
drop trigger if exists hh_share_room_delete on public.hh_rooms;create trigger hh_share_room_delete after delete on public.hh_rooms for each row execute function public.hh_share_scope_lifecycle();
drop trigger if exists hh_share_table_delete on public.hh_tournament_tables;create trigger hh_share_table_delete after delete on public.hh_tournament_tables for each row execute function public.hh_share_scope_lifecycle();
-- Rebuild names in every public history: no stale team labels or free-text author names.
create or replace function public.hh_shared_history(v jsonb,p_scope text,p_target uuid,p_names jsonb,p_teams jsonb,depth int default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$declare out jsonb;k text;x jsonb;t jsonb;i int;labels jsonb;actor_name text;begin
 if depth>30 then return 'null';end if;
 if jsonb_typeof(v)='array' then select coalesce(jsonb_agg(public.hh_shared_history(value,p_scope,p_target,p_names,p_teams,depth+1)),'[]') into out from jsonb_array_elements(v);return out;
 elsif jsonb_typeof(v)='object' then
  out:='{}';for k,x in select * from jsonb_each(v) loop
   if k='teams' then
    labels:='[]';for i in 0..1 loop
     select to_jsonb(coalesce(string_agg(coalesce(p_names->>(value #>> '{}'),'Anonym'),' & ' order by n),'Team '||(i+1)::text)) into t from jsonb_array_elements(coalesce(v->'members'->i,'[]')) with ordinality a(value,n);
     labels:=labels||jsonb_build_array(t);
    end loop;
    if v?'members' then out:=out||jsonb_build_object(k,labels);else out:=out||jsonb_build_object(k,p_teams);end if;
   elsif k='actor_name' then
    select coalesce(p.display_username,p.username) into actor_name from public.hh_profiles p where p.user_id::text=v->>'actor' and public.hh_share_allowed(p_scope,p_target,p.user_id);
    out:=out||jsonb_build_object(k,coalesce(actor_name,'Anonym'));
   else out:=out||jsonb_build_object(k,public.hh_shared_history(x,p_scope,p_target,p_names,p_teams,depth+1));end if;
  end loop;return out;
 end if;return v;
end$$;
revoke all on function public.hh_shared_history(jsonb,text,uuid,jsonb,jsonb,int) from public,anon,authenticated;
create or replace function public.hh_public_room_score(p_room uuid,p_token text) returns jsonb language plpgsql security definer set search_path='' as $$declare r public.hh_rooms;body jsonb;people jsonb;names jsonb;teams jsonb;begin
 if p_token is null or p_token!~'^[a-f0-9]{64}$' then raise exception 'Zuschauerzugang nicht verfügbar';end if;
 select * into r from public.hh_rooms where id=p_room and ended_at is null;
 if r.id is null or public.hh_room_score_token(p_room) is null or p_token<>public.hh_room_score_token(p_room) then raise exception 'Zuschauerzugang nicht verfügbar';end if;
 select payload into body from public.hh_states where room_id=p_room;
 select coalesce(jsonb_agg(jsonb_build_object('id',p->'id','name',case when p->>'deleted'='true' or not public.hh_share_allowed('room',p_room,pro.user_id) then 'Anonym' else coalesce(pro.display_username,pro.username,'Anonym') end,'photo',case when p->>'deleted'='true' or not public.hh_share_allowed('room',p_room,pro.user_id) then null else pro.avatar end) order by n),'[]') into people from jsonb_array_elements(body->'people') with ordinality a(p,n) left join public.hh_profiles pro on pro.user_id::text=p->>'authUserId';
 select coalesce(jsonb_object_agg(p->>'id',p->'name'),'{}') into names from jsonb_array_elements(people) p;teams:=jsonb_build_array('Team 1','Team 2');
 return jsonb_build_object('title','Kartabend · Spielstand','people',people,'sessions',public.hh_public_score_fields(public.hh_shared_history(body->'sessions','room',p_room,names,teams)),'updated_at',clock_timestamp());
end$$;
create or replace function public.hh_public_table_score(p_table uuid,p_token text) returns jsonb language plpgsql stable security definer set search_path='' as $$declare b public.hh_tournament_tables;t public.hh_tournaments;names jsonb;parties jsonb;begin
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception 'Spielstandsanzeige nicht verfügbar oder QR-Code erneuert';end if;
 select * into b from public.hh_tournament_tables where id=p_table;
 select * into t from public.hh_tournaments where id=b.tournament_id;
 if b.id is null or t.status is distinct from 'running' or b.stage<>t.stage or p_token<>public.hh_table_score_token(p_table) then raise exception 'Spielstandsanzeige nicht verfügbar oder QR-Code erneuert';end if;
 select jsonb_agg(case when public.hh_share_allowed('table',p_table,p.user_id) then coalesce(nullif(trim(d.first_name||' '||d.last_name),''),p.display_username,p.username,'Anonym') else 'Anonym' end order by a.n) into names from unnest(b.players) with ordinality a(uid,n) left join public.hh_profiles p on p.user_id=a.uid left join public.hh_account_details d on d.user_id=p.user_id left join public.hh_tournament_guests g on g.id=a.uid;
 select coalesce(jsonb_agg(jsonb_build_object('scores',g->'scores','winner',g->'winner','rounds',public.hh_public_rounds(public.hh_shared_history(g->'rounds','table',p_table,'{}','["Team 1","Team 2"]'))) order by n),'[]') into parties from jsonb_array_elements(b.games) with ordinality a(g,n);
 return jsonb_build_object('names',names,'parties',parties,'current_rounds',case when b.done then '[]'::jsonb else public.hh_public_rounds(public.hh_shared_history(b.rounds,'table',p_table,'{}','["Team 1","Team 2"]')) end,'table_no',b.table_no,'stage',b.stage,'scores',to_jsonb(b.scores),'completed',jsonb_array_length(b.games),'target',(t.settings->>'target')::int,'round_done',b.done,'wins',jsonb_build_array((select count(*) from jsonb_array_elements(b.games) g where g->>'winner'='0'),(select count(*) from jsonb_array_elements(b.games) g where g->>'winner'='1')),'last_scores',b.games->-1->'scores','revision',b.revision);
end $$;
notify pgrst,'reload schema';
commit;
