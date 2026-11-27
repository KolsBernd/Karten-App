begin;
-- Euro amounts deliberately never enter hh_states, saved profile results or
-- tournament tables. All mutations are server-calculated and room-member scoped.
create table if not exists public.hh_euro_writers(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.hh_euro_writers enable row level security;
revoke all on public.hh_euro_writers from public,anon,authenticated;
insert into public.hh_euro_writers(user_id) select user_id from public.hh_profiles where lower(username) in('kolsbernd','yannik') on conflict do nothing;
create table if not exists public.hh_euro_rooms(
 room_id uuid primary key references public.hh_rooms(id) on delete cascade,
 revision bigint not null default 0 check(revision>=0),
 data jsonb not null,
 requests jsonb not null default '{}',
 updated_at timestamptz not null default now()
);
alter table public.hh_euro_rooms enable row level security;
revoke all on public.hh_euro_rooms from public,anon,authenticated;

create or replace function public.hh_euro_can_write() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.hh_euro_writers w join auth.users u on u.id=w.user_id where w.user_id=auth.uid() and u.email_confirmed_at is not null)
$$;
create or replace function public.hh_euro_defaults() returns jsonb language sql immutable set search_path='' as $$
 select jsonb_object_agg(k,jsonb_build_object('enabled',k<>'Ramsch','cents',c)) from(values
 ('King',20),('Wenz',20),('Geier',20),('Solo',20),('Sau',5),('Bagga',30),('Spitz',40),('Ramsch',10),('Kreuzspiel',5),('Bettel',15),('Schneider',5),('Durch',5),('Tout',null::int),('Light',null::int),('Jungfrau',null::int),('Legen',null::int)) x(k,c)
$$;
create or replace function public.hh_euro_config(cfg jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;v jsonb;out jsonb:='{}';c numeric;begin
 if jsonb_typeof(cfg) is distinct from 'object' or exists(select 1 from jsonb_object_keys(cfg) x where not public.hh_euro_defaults() ? x) then raise exception 'Ungültige Euro-Einstellungen';end if;
 for k,v in select * from jsonb_each(public.hh_euro_defaults()) loop
  if jsonb_typeof(cfg->k) is distinct from 'object' or jsonb_typeof(cfg->k->'enabled') is distinct from 'boolean' then raise exception 'Spieloption fehlt: %',k;end if;
  if v->'cents'<>'null'::jsonb then
   if jsonb_typeof(cfg->k->'cents') is distinct from 'number' then raise exception 'Ungültiger Eurobetrag';end if;c:=(cfg->k->>'cents')::numeric;
   if c<>trunc(c) or c<0 or c>100000 then raise exception 'Grundbetrag: 0 bis 1.000 Euro';end if;
  else c:=null;end if;
  out:=out||jsonb_build_object(k,jsonb_build_object('enabled',(cfg->k->>'enabled')::boolean,'cents',c));
 end loop;
 if (out->'Ramsch'->>'enabled')::boolean and (out->'Kreuzspiel'->>'enabled')::boolean then raise exception 'Ramsch und Kreuzspiel sind Alternativen';end if;
 if not exists(select 1 from jsonb_each(out) where key in('King','Wenz','Geier','Solo','Sau','Bagga','Spitz','Ramsch','Kreuzspiel','Bettel') and (value->>'enabled')::boolean) then raise exception 'Mindestens ein Spiel freigeben';end if;
 return out;
end$$;
create or replace function public.hh_euro_int(v jsonb,lo int,hi int) returns int language plpgsql immutable set search_path='' as $$declare n numeric;begin
 if jsonb_typeof(v) is distinct from 'number' then raise exception 'Ungültige Zahl';end if;n:=v::numeric;if n<>trunc(n) or n<lo or n>hi then raise exception 'Zahl außerhalb des erlaubten Bereichs';end if;return n::int;
end$$;
create or replace function public.hh_euro_value(cfg jsonb,input jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare game text:=input->>'game';solo boolean;team boolean;result_used boolean;spikes text:='';spike int:=4;bonus bigint:=0;special numeric:=1;ann int;laid int;knock int:=0;seat int;partner int;won boolean;v numeric;balances bigint[]:=array[0::bigint,0,0,0];i int;j jsonb;canonical jsonb;begin
 if jsonb_typeof(input) is distinct from 'object' or game is null or game not in('King','Wenz','Geier','Solo','Sau','Bagga','Spitz','Ramsch','Kreuzspiel','Bettel') or coalesce((cfg->game->>'enabled')::boolean,false) is not true then raise exception 'Dieses Spiel ist nicht freigegeben';end if;
 solo:=game in('King','Wenz','Geier','Solo');team:=game in('Sau','Kreuzspiel');
 if jsonb_typeof(input->'tout') is distinct from 'boolean' or jsonb_typeof(input->'light') is distinct from 'boolean' or jsonb_typeof(input->'won') is distinct from 'boolean' then raise exception 'Ungültiger Spielausgang';end if;
 if (input->>'tout')::boolean and (input->>'light')::boolean then raise exception 'Tout und Light sind Alternativen';end if;
 if (input->>'tout')::boolean and(not (cfg->'Tout'->>'enabled')::boolean or not(solo or game in('Bagga','Bettel'))) then raise exception 'Tout ist hier nicht freigegeben';end if;
 if (input->>'light')::boolean and(not (cfg->'Light'->>'enabled')::boolean or not solo) then raise exception 'Light ist hier nicht freigegeben';end if;
 if solo and not(input->>'light')::boolean then
  if jsonb_typeof(input->'spikes') is distinct from 'array' or jsonb_array_length(input->'spikes')>4 or exists(select 1 from jsonb_array_elements_text(input->'spikes') x where x not in('A','B','C','D')) then raise exception 'Ungültige Spitzen';end if;
  select coalesce(string_agg(x,'' order by x),'') into spikes from(select distinct value x from jsonb_array_elements_text(input->'spikes')) a;
 end if;
 spike:=case spikes when 'AB' then 6 when 'ABC' then 7 when 'ABCD' then 8 when 'CD' then 7 when 'D' then 8 else 4 end;
 result_used:=game not in('Ramsch','Spitz','Bagga','Bettel') and not(input->>'tout')::boolean and not(input->>'light')::boolean;
 if result_used then
  if input->>'result' is null or input->>'result' not in('normal','schneider','durch') then raise exception 'Spielergebnis wählen';end if;
  if input->>'result'<>'normal' then if not(cfg->'Schneider'->>'enabled')::boolean then raise exception 'Schneider ist nicht freigegeben';end if;bonus:=(cfg->'Schneider'->>'cents')::bigint;end if;
  if input->>'result'='durch' then if not(cfg->'Durch'->>'enabled')::boolean then raise exception 'Durch ist nicht freigegeben';end if;bonus:=bonus+(cfg->'Durch'->>'cents')::bigint;end if;
 end if;
 ann:=public.hh_euro_int(input->'announcement',1,8);if ann not in(1,2,4,8) then raise exception 'Ungültige Ansage';end if;
 laid:=public.hh_euro_int(input->'laid',0,4);if laid>0 and not(cfg->'Legen'->>'enabled')::boolean then raise exception 'Legen ist nicht freigegeben';end if;
 if game='Ramsch' then knock:=public.hh_euro_int(coalesce(input->'knockers','0'),0,4);end if;
 if(input->>'tout')::boolean then special:=case when game='Bettel' then 1.5 else 2 end;elsif(input->>'light')::boolean then special:=2;end if;
 v:=((cfg->game->>'cents')::bigint*spike+bonus*4)*special*ann*power(2,laid+knock);
 if v<>trunc(v) or v<0 or v>1000000000000 then raise exception 'Spielwert zu groß';end if;
 seat:=public.hh_euro_int(input->'seat',0,3);won:=(input->>'won')::boolean;
 if team then partner:=public.hh_euro_int(input->'partner',0,3);if partner=seat or(game='Kreuzspiel' and partner<>(seat+2)%4) then raise exception 'Bitte das korrekte Zweierteam wählen';end if;end if;
 j:=case when game='Ramsch' and not won and(cfg->'Jungfrau'->>'enabled')::boolean then coalesce(input->'jungfrauen','[]') else '[]' end;
 if jsonb_typeof(j) is distinct from 'array' or jsonb_array_length(j)>3 then raise exception 'Ungültige Jungfrau-Auswahl';end if;
 for i in select public.hh_euro_int(value,0,3) from jsonb_array_elements(j) loop if i=seat then raise exception 'Der Ramsch-Verlierer kann keine Jungfrau sein';end if;end loop;
 if game='Ramsch' and not won then
  for i in 0..3 loop if i<>seat then balances[i+1]:=v*(case when j @> jsonb_build_array(i) then 2 else 1 end);balances[seat+1]:=balances[seat+1]-balances[i+1];end if;end loop;
 else
  for i in 0..3 loop balances[i+1]:=v*(case when not team and i=seat then 3 else 1 end)*(case when ((i=seat or(team and i=partner))=won) then 1 else -1 end);end loop;
 end if;
 canonical:=jsonb_build_object('game',game,'seat',seat,'partner',partner,'spikes',to_jsonb(case when spikes='' then array[]::text[] else regexp_split_to_array(spikes,'') end),'result',case when result_used then input->>'result' else 'normal' end,'tout',(input->>'tout')::boolean,'light',(input->>'light')::boolean,'won',won,'announcement',ann,'laid',laid,'knockers',knock,'jungfrauen',j);
 return jsonb_build_object('input',canonical,'quarters',v,'balances',to_jsonb(balances));
end$$;
create or replace function public.hh_euro_totals(rounds jsonb) returns jsonb language plpgsql immutable set search_path='' as $$declare out bigint[]:=array[0::bigint,0,0,0];r jsonb;i int;begin
 for r in select value from jsonb_array_elements(rounds) loop for i in 0..3 loop out[i+1]:=out[i+1]+(r->'balances'->>i)::bigint;end loop;end loop;return to_jsonb(out);
end$$;
create or replace function public.hh_euro_transfers(totals jsonb) returns jsonb language plpgsql immutable set search_path='' as $$declare b bigint[];d int;c int;v bigint;out jsonb:='[]';i int;begin
 select array_agg(value::bigint order by ordinality) into b from jsonb_array_elements_text(totals) with ordinality;
 if cardinality(b)<>4 or(select sum(x) from unnest(b)x)<>0 then raise exception 'Ungültige Abrechnungssalden';end if;
 for i in 1..3 loop
  select idx into d from generate_subscripts(b,1) idx where b[idx]<0 order by b[idx] limit 1;
  select idx into c from generate_subscripts(b,1) idx where b[idx]>0 order by b[idx] desc limit 1;
  exit when d is null or c is null;v:=least(-b[d],b[c]);out:=out||jsonb_build_array(jsonb_build_object('from',d-1,'to',c-1,'quarters',v));b[d]:=b[d]+v;b[c]:=b[c]-v;
 end loop;return out;
end$$;
create or replace function public.hh_euro_series(players jsonb,cfg jsonb) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('id',gen_random_uuid(),'players',players,'config',cfg,'rounds','[]'::jsonb,'closed',false,'started_at',clock_timestamp(),'totals','[0,0,0,0]'::jsonb,'transfers','[]'::jsonb)
$$;
create or replace function public.hh_euro_other_running(payload jsonb) returns boolean language sql immutable set search_path='' as $$
 select exists(select 1 from jsonb_array_elements(coalesce(payload->'sessions','[]')) a cross join lateral(select a->'current' sheet union all select a->'snSheet' union all select a->'klSheet' union all select value from jsonb_each(coalesce(a->'extraGames','{}')) union all select value from jsonb_each(coalesce(a->'teamCurrentByType','{}'))) sheets where coalesce((sheet->>'closed')::boolean,false)=false and(jsonb_array_length(coalesce(sheet->'rounds','[]'))>0 or jsonb_array_length(coalesce(sheet->'entries','[]'))>0))
$$;
create or replace function public.hh_euro_players(ids jsonb,people jsonb) returns jsonb language plpgsql immutable set search_path='' as $$begin
 if jsonb_typeof(ids) is distinct from 'array' or jsonb_array_length(ids)<>4 or(select count(distinct value) from jsonb_array_elements(ids))<>4 or exists(select 1 from jsonb_array_elements(ids) id where not exists(select 1 from jsonb_array_elements(people) p where p->'id'=id and coalesce(p->>'deleted','false')<>'true')) then raise exception 'Genau vier verschiedene, vorhandene Spieler auswählen';end if;return ids;
end$$;
create or replace function public.hh_euro_room(p_action text,p_room uuid default null,p_revision bigint default null,p_request uuid default null,p_body jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();writer boolean;state_row public.hh_euro_rooms;payload jsonb;ended timestamptz;cur jsonb;hist jsonb;cfg jsonb;players jsonb;v jsonb;rs jsonb;rec jsonb;name text;request_hash text;known jsonb;nonce text:=p_request::text;result jsonb;begin
 if uid is null then raise exception 'Bitte anmelden' using errcode='42501';end if;writer:=public.hh_euro_can_write();
 if p_action='capabilities' then return jsonb_build_object('can_write',writer);end if;
 if p_action='list' then return coalesce((select jsonb_agg(jsonb_build_object('room_id',e.room_id,'active',coalesce((e.data->>'active')::boolean,false),'running',coalesce((e.data->>'active')::boolean,false) and not(e.data->'current'->>'closed')::boolean and jsonb_array_length(e.data->'current'->'rounds')>0)) from public.hh_euro_rooms e join public.hh_members m on m.room_id=e.room_id and m.user_id=uid),'[]');end if;
 if p_room is null or not public.hh_is_member(p_room) then raise exception 'Nur bestätigte Mitglieder dieses Raums' using errcode='42501';end if;
 if p_action not in('get','activate','deactivate','configure','new','add','undo','finish') then raise exception 'Unbekannte Euro-Aktion';end if;
 if p_action<>'get' then
  perform pg_advisory_xact_lock_shared(194717,29);
  if p_action<>'deactivate' and not writer then raise exception 'Nur Kolsbernd und Yannik dürfen Euro-Ergebnisse bearbeiten' using errcode='42501';end if;
  perform 1 from public.hh_rooms where id=p_room for update;
 end if;
 select r.ended_at,s.payload into ended,payload from public.hh_rooms r join public.hh_states s on s.room_id=r.id where r.id=p_room;
 if payload is null then raise exception 'Raum nicht vorhanden';end if;
 if p_action<>'get' and ended is not null then raise exception 'Dieser Kartabend ist beendet';end if;
 if p_action='get' then select * into state_row from public.hh_euro_rooms where room_id=p_room;else select * into state_row from public.hh_euro_rooms where room_id=p_room for update;end if;
 if p_action='get' then
  if state_row.room_id is null then return jsonb_build_object('data',null,'revision',0,'can_write',writer,'ended',ended is not null);end if;
  if p_revision=state_row.revision then return jsonb_build_object('unchanged',true,'revision',state_row.revision,'can_write',writer,'ended',ended is not null);end if;
 else
  if p_request is null or jsonb_typeof(p_body) is distinct from 'object' or octet_length(p_body::text)>12000 then raise exception 'Ungültige Euro-Anfrage';end if;
  request_hash:=encode(extensions.digest(p_action||':'||p_body::text,'sha256'),'hex');known:=state_row.requests->nonce;
  if known is not null then
   if known->>'hash'<>request_hash then raise exception 'Anfragekennung wurde wiederverwendet';end if;
   return jsonb_build_object('data',state_row.data,'revision',state_row.revision,'can_write',writer,'applied_requests',(select jsonb_agg(key) from jsonb_each(state_row.requests)),'ended',false);
  end if;
  if p_revision is null or p_revision<>coalesce(state_row.revision,0) then raise exception 'Spielstand wurde geändert. Bitte Eingabe prüfen' using errcode='40001';end if;
  if state_row.room_id is null then
   if p_action<>'activate' then raise exception 'Bitte Schafkopf (€) zuerst öffnen';end if;
   select coalesce(jsonb_agg(p->'id' order by n),'[]') into players from(select value p,ordinality n from jsonb_array_elements(payload->'people') with ordinality where coalesce(value->>'deleted','false')<>'true' order by ordinality limit 4) x;
   cfg:=public.hh_euro_defaults();cur:=public.hh_euro_series(players,cfg);
   state_row.room_id:=p_room;state_row.revision:=0;state_row.requests:='{}';state_row.data:=jsonb_build_object('active',false,'current',cur,'history','[]'::jsonb,'draft',jsonb_build_object('players',players,'config',cfg));
  end if;
  cur:=state_row.data->'current';hist:=coalesce(state_row.data->'history','[]');cfg:=cur->'config';players:=cur->'players';rs:=cur->'rounds';
  if p_action in('activate','new') and public.hh_euro_other_running(payload) then raise exception 'Bitte die andere laufende Partie zuerst beenden';end if;
  if p_action in('configure','new','add','undo','finish') and p_body->>'series_id' is distinct from cur->>'id' then raise exception 'Abrechnung wurde gewechselt. Bitte neu prüfen' using errcode='40001';end if;
  if p_action='activate' then state_row.data:=jsonb_set(state_row.data,'{active}','true');
  elsif p_action='deactivate' then
   if jsonb_array_length(rs)>0 and not(cur->>'closed')::boolean then raise exception 'Bitte zuerst abrechnen';end if;state_row.data:=jsonb_set(state_row.data,'{active}','false');
  elsif p_action='configure' then
   if jsonb_array_length(rs)>0 and not(cur->>'closed')::boolean then raise exception 'Einstellungen sind während der Abrechnung gesperrt';end if;
   cfg:=public.hh_euro_config(p_body->'config');players:=public.hh_euro_players(p_body->'players',payload->'people');
   state_row.data:=jsonb_set(state_row.data,'{draft}',jsonb_build_object('config',cfg,'players',players));
   if not(cur->>'closed')::boolean then cur:=cur||jsonb_build_object('config',cfg,'players',players);end if;
  elsif p_action='new' then
   if jsonb_array_length(rs)>0 and not(cur->>'closed')::boolean then raise exception 'Bitte die aktuelle Abrechnung zuerst abschließen';end if;
   cfg:=public.hh_euro_config(state_row.data->'draft'->'config');players:=public.hh_euro_players(state_row.data->'draft'->'players',payload->'people');cur:=public.hh_euro_series(players,cfg);state_row.data:=jsonb_set(state_row.data,'{active}','true');
  elsif p_action='add' then
   if (cur->>'closed')::boolean or not(state_row.data->>'active')::boolean then raise exception 'Bitte eine neue Abrechnung starten';end if;
   if jsonb_array_length(rs)>=2000 then raise exception 'Bitte nach 2.000 Spielen abrechnen';end if;
   perform public.hh_euro_players(players,payload->'people');cfg:=public.hh_euro_config(cfg);v:=public.hh_euro_value(cfg,p_body->'input');
   select coalesce(display_username,username,'Nutzer') into name from public.hh_profiles where user_id=uid;
   rec:=v||jsonb_build_object('id',p_request,'actor',uid,'actor_name',name,'recorded_at',clock_timestamp(),'duration_seconds',greatest(0,floor(extract(epoch from(clock_timestamp()-coalesce((rs->-1->>'recorded_at')::timestamptz,(cur->>'started_at')::timestamptz))))));
   rs:=rs||jsonb_build_array(rec);cur:=cur||jsonb_build_object('rounds',rs,'totals',public.hh_euro_totals(rs));
  elsif p_action='undo' then
   rec:=rs->-1;
   if jsonb_array_length(rs)=0 then raise exception 'Kein Eintrag vorhanden';end if;
   if (cur->>'closed')::boolean then
    if jsonb_array_length(hist)=0 or hist->-1->>'id'<>cur->>'id' then raise exception 'Nur die letzte Abrechnung kann wieder geöffnet werden';end if;
    hist:=hist-(jsonb_array_length(hist)-1);cur:=cur-array['closed_at','closed_by'];cur:=cur||jsonb_build_object('closed',false,'transfers','[]'::jsonb);state_row.data:=jsonb_set(state_row.data,'{active}','true');
   end if;
   rs:=rs-(jsonb_array_length(rs)-1);cur:=cur||jsonb_build_object('rounds',rs,'totals',public.hh_euro_totals(rs));
  elsif p_action='finish' then
   if (cur->>'closed')::boolean or jsonb_array_length(rs)=0 then raise exception 'Keine offene Abrechnung mit Spielen';end if;
   cur:=cur||jsonb_build_object('closed',true,'closed_at',clock_timestamp(),'closed_by',uid,'totals',public.hh_euro_totals(rs),'transfers',public.hh_euro_transfers(public.hh_euro_totals(rs)));hist:=hist||jsonb_build_array(cur);
  end if;
  state_row.data:=state_row.data||jsonb_build_object('current',cur,'history',hist);
  if octet_length(state_row.data::text)>3000000 then raise exception 'Raum-Abrechnungen zu groß. Bitte sichern und Raumstatistiken zurücksetzen';end if;
  select coalesce(display_username,username,'Nutzer') into name from public.hh_profiles where user_id=uid;
  state_row.data:=jsonb_set(state_row.data,'{events}',coalesce(state_row.data->'events','[]')||jsonb_build_array(jsonb_build_object('action',p_action,'actor',uid,'actor_name',name,'at',clock_timestamp(),'request',p_request,'series_id',cur->>'id','removed',case when p_action='undo' then rec else null end)));
  if p_action='add' and octet_length((state_row.data||jsonb_build_object('history',hist||jsonb_build_array(cur)))::text)>2900000 then raise exception 'Bitte diese Abrechnung abschließen und danach einen neuen Kartabend verwenden';end if;
  if octet_length(state_row.data::text)>3000000 then raise exception 'Abrechnungsspeicher voll';end if;
  state_row.revision:=state_row.revision+1;state_row.requests:=state_row.requests||jsonb_build_object(nonce,jsonb_build_object('hash',request_hash,'revision',state_row.revision));
  select coalesce(jsonb_object_agg(key,value),'{}') into state_row.requests from(select key,value from jsonb_each(state_row.requests) order by(value->>'revision')::bigint desc limit 60) x;
  insert into public.hh_euro_rooms(room_id,revision,data,requests) values(state_row.room_id,state_row.revision,state_row.data,state_row.requests) on conflict(room_id) do update set revision=excluded.revision,data=excluded.data,requests=excluded.requests,updated_at=clock_timestamp();
  update public.hh_rooms set last_activity_at=clock_timestamp() where id=p_room;
 end if;
 return jsonb_build_object('data',state_row.data,'revision',state_row.revision,'can_write',writer,'applied_requests',(select coalesce(jsonb_agg(key),'[]') from jsonb_each(state_row.requests)),'ended',ended is not null);
end$$;

-- Keep the established reset confirmations/permissions. This trigger runs only
-- after a confirmed existing room reset, in the same transaction.
create or replace function public.hh_euro_clear_room(rid uuid) returns void language plpgsql security definer set search_path='' as $$begin
 update public.hh_euro_rooms set data=jsonb_build_object('active',false,'current',public.hh_euro_series(data->'draft'->'players',data->'draft'->'config'),'draft',data->'draft','history','[]'::jsonb),requests='{}',revision=revision+1,updated_at=clock_timestamp() where room_id=rid;
end$$;
create or replace function public.hh_euro_after_reset() returns trigger language plpgsql security definer set search_path='' as $$declare rid uuid;begin
 if tg_table_name='hh_audit' then if new.action='reset' and old.action is distinct from new.action then perform public.hh_euro_clear_room(new.room_id);end if;
 elsif new.generation>old.generation then for rid in select room_id from public.hh_euro_rooms loop perform public.hh_euro_clear_room(rid);end loop;end if;return new;
end$$;
drop trigger if exists hh_euro_room_reset on public.hh_audit;
create trigger hh_euro_room_reset after update of action on public.hh_audit for each row execute function public.hh_euro_after_reset();
drop trigger if exists hh_euro_global_reset on public.hh_reset_control;
create trigger hh_euro_global_reset after update of generation on public.hh_reset_control for each row execute function public.hh_euro_after_reset();

-- Prevent a second, ordinary score writer from starting another game during an
-- open Euro series, without changing ordinary global statistics at all.
create or replace function public.hh_euro_state_guard() returns trigger language plpgsql security definer set search_path='' as $$declare d jsonb;a jsonb;b jsonb;k text;begin
 if current_setting('hh.euro_reset',true)='yes' then return new;end if;
 select data into d from public.hh_euro_rooms where room_id=new.room_id;if d is null then return new;end if;
 if exists(select 1 from jsonb_array_elements(coalesce(d->'history','[]')||jsonb_build_array(d->'current')) series cross join lateral jsonb_array_elements(series->'players') id where not exists(select 1 from jsonb_array_elements(new.payload->'people') p where p->'id'=id)) then raise exception 'Spieler mit Euro-Verläufen dürfen nicht aus dem Raumdatensatz entfernt werden';end if;
 if current_setting('hh.validated_admin',true)='yes' then return new;end if;
 if coalesce((d->>'active')::boolean,false) and not coalesce((d->'current'->>'closed')::boolean,false) and jsonb_array_length(d->'current'->'rounds')>0 then
  a:=old.payload->'sessions';b:=new.payload->'sessions';
  if jsonb_array_length(a)<>jsonb_array_length(b) then raise exception 'Bitte Schafkopf (€) zuerst abrechnen';end if;
  for k in select unnest(array['current','snSheet','klSheet','extraGames','games','snHistory','klHistory','extraHistory','gameType','members','teamSetups','teamCurrentByType']) loop if a->-1->k is distinct from b->-1->k then raise exception 'Bitte Schafkopf (€) zuerst abrechnen';end if;end loop;
 end if;return new;
end$$;
drop trigger if exists hh_euro_state_guard on public.hh_states;
create trigger hh_euro_state_guard before update of payload on public.hh_states for each row execute function public.hh_euro_state_guard();
-- The existing global-reset lock already serializes Euro mutations. Mark the
-- trusted reset transaction so its state cleanup is not mistaken for gameplay.
do $$declare def text;begin
 select pg_get_functiondef('public.hh_admin_reset(text,text,text)'::regprocedure) into def;
 if position('hh.euro_reset' in def)=0 then
  if position('perform pg_advisory_xact_lock(194717,29);' in def)=0 then raise exception 'Globale Rücksetzfunktion unerwartet; Aktivierung abgebrochen';end if;
  execute replace(def,'perform pg_advisory_xact_lock(194717,29);','perform pg_advisory_xact_lock(194717,29); perform set_config(''hh.euro_reset'',''yes'',true);');
 end if;
end$$;
-- Manual closing keeps the existing owner check and requires a completed Euro
-- settlement. Automatic idle archiving still preserves an unfinished series.
do $$declare def text;begin
 select pg_get_functiondef('public.hh_set_room_status(uuid,boolean)'::regprocedure) into def;
 if position('hh_euro_rooms' in def)=0 then
  if def !~* '\mbegin\M' then raise exception 'Raumabschlussfunktion unerwartet';end if;
  execute regexp_replace(def,'\mbegin\M','begin if p_end and public.hh_is_member(p_room) and exists(select 1 from public.hh_euro_rooms where room_id=p_room and (data->>''active'')::boolean and not(data->''current''->>''closed'')::boolean and jsonb_array_length(data->''current''->''rounds'')>0) then raise exception ''Bitte Schafkopf (€) zuerst abrechnen'';end if;','i');
 end if;
end$$;
-- All helpers are private. Only the one membership-checked RPC is callable.
revoke all on function public.hh_euro_can_write(),public.hh_euro_defaults(),public.hh_euro_config(jsonb),public.hh_euro_int(jsonb,int,int),public.hh_euro_value(jsonb,jsonb),public.hh_euro_totals(jsonb),public.hh_euro_transfers(jsonb),public.hh_euro_series(jsonb,jsonb),public.hh_euro_other_running(jsonb),public.hh_euro_players(jsonb,jsonb),public.hh_euro_clear_room(uuid),public.hh_euro_after_reset(),public.hh_euro_state_guard(),public.hh_euro_room(text,uuid,bigint,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.hh_euro_room(text,uuid,bigint,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
