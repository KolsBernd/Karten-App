begin;
create or replace function public.hh_rule_extra(sheet jsonb,kind text,people jsonb,finished boolean default false) returns void language plpgsql immutable set search_path='' as $$
declare ids jsonb:=sheet->'players';r jsonb;x jsonb;expected jsonb;totals jsonb:='{}';pid text;pts int;n int;factor int;awards int[];idx int;done boolean:=false;excluded boolean;tricks int;cfg jsonb:=sheet->'settings';begin
 if kind is null or kind not in('21 rückwärts','Schafkopf') or jsonb_typeof(sheet) is distinct from 'object' or jsonb_typeof(sheet->'rounds') is distinct from 'array' or jsonb_array_length(sheet->'rounds')>10000 then raise exception 'Ungültige Zusatzpartie';end if;
 perform public.hh_rule_roster(ids,people,0,32);n:=jsonb_array_length(ids);
 if jsonb_array_length(sheet->'rounds')>0 or finished then perform public.hh_rule_roster(ids,people,case when kind='Schafkopf' then 4 else 2 end,case when kind='Schafkopf' then 4 else 32 end);end if;
 if kind='Schafkopf' and (jsonb_typeof(cfg->'variants') is distinct from 'array' or not exists(select 1 from jsonb_array_elements_text(cfg->'variants') v where v in('King','Solo','Wenz','Geier','Sau','Kreuzspiel')) or exists(select 1 from jsonb_array_elements_text(cfg->'variants') v where v not in('King','Solo','Wenz','Geier','Sau','Kreuzspiel','Tout')) or jsonb_typeof(cfg->'capture_colors') is distinct from 'boolean') then raise exception 'Ungültige Schafkopfeinstellungen';end if;
 for r in select value from jsonb_array_elements(sheet->'rounds') loop
  if done then raise exception 'Partie bereits beendet';end if;
  if jsonb_typeof(r->'results') is distinct from 'array' or jsonb_array_length(r->'results')<>n then raise exception 'Ergebnis für alle Spieler erforderlich';end if;
  select jsonb_agg(value->'id') into expected from jsonb_array_elements(r->'results');if expected is distinct from ids then raise exception 'Spielerreihenfolge stimmt nicht';end if;
  if kind='21 rückwärts' then
   if coalesce(r->>'suit','') not in('Eichel','Gras','Herz','Schellen') then raise exception 'Farbe wählen';end if;factor:=case when r->>'suit'='Herz' then 2 else 1 end;
   if not exists(select 1 from jsonb_array_elements(r->'results') e where e->>'excluded'='false') then raise exception 'Mindestens ein aktiver Spieler';end if;
   for x in select value from jsonb_array_elements(r->'results') loop
    pid:=x->>'id';tricks:=public.hh_rule_int(x->'tricks',0,5);if jsonb_typeof(x->'excluded') is distinct from 'boolean' then raise exception 'Aussetzen ungültig';end if;excluded:=(x->>'excluded')::boolean;
    if excluded and r->>'suit'='Eichel' then raise exception 'Bei Eichel müssen alle mitspielen';end if;
    pts:=coalesce((totals->>pid)::int,21)+case when excluded then 0 when tricks=0 then 5*factor else -tricks*factor end;
    if public.hh_rule_int(x->'points',-100,1000000)<>pts then raise exception 'Falsche Rückwärts-Punkte';end if;totals:=jsonb_set(totals,array[pid],to_jsonb(pts));
   end loop;
   select exists(select 1 from jsonb_each_text(totals) q where value::int<=0) into done;
  else
   if not(cfg->'variants' ? (r->>'variant')) or r->>'bonus'='tout' and not(cfg->'variants' ? 'Tout') then raise exception 'Spiel nicht freigegeben';end if;
   if jsonb_typeof(r->'won') is distinct from 'boolean' then raise exception 'Ausgang wählen';end if;
   if r->>'bonus'='tout' and r->>'tout_confirmed' is distinct from 'true' then raise exception 'Tout bestätigen';end if;
   if (cfg->>'capture_colors')::boolean and coalesce(r->>'suit','') not in('Eichel','Gras','Herz','Schellen') then raise exception 'Farbe wählen';end if;
   awards:=public.hh_schaf_awards(public.hh_rule_int(r->'seat',0,3),r->>'variant',(r->>'won')::boolean,r->>'bonus',public.hh_rule_int(r->'partner',0,3));
   idx:=0;for x in select value from jsonb_array_elements(r->'results') loop idx:=idx+1;if public.hh_rule_int(x->'points',0,12)<>awards[idx] then raise exception 'Falsche Schafkopfpunkte';end if;end loop;
   if r->'awards' is distinct from to_jsonb(awards) then raise exception 'Falsche Schafkopfwertung';end if;done:=true;
  end if;
 end loop;
 if jsonb_typeof(sheet->'closed') is distinct from 'boolean' or (sheet->>'closed')::boolean is distinct from done or finished and not done then raise exception 'Falscher Partieabschluss';end if;
end$$;
revoke all on function public.hh_rule_extra(jsonb,text,jsonb,boolean) from public,anon,authenticated;

create or replace function public.hh_extra_statistics(g jsonb) returns jsonb language sql immutable set search_path='' as $$
with scores as(select (x->'id') id,case when g->>'gameType'='21 rückwärts' then 21-(x->>'points')::numeric else (x->>'points')::numeric end points from jsonb_array_elements(coalesce(g->'rounds'->-1->'results','[]')) x)
select coalesce(jsonb_agg(jsonb_build_object('id',id,'points',points,'won',points=(select max(points) from scores))),'[]') from scores;
$$;
revoke all on function public.hh_extra_statistics(jsonb) from public,anon,authenticated;

create or replace function public.hh_reopen_last_game(p_room uuid,p_revision bigint,p_game text) returns jsonb language plpgsql security definer set search_path='' as $$
declare previous jsonb;body jsonb;a jsonb;g jsonb;st jsonb;last_r jsonb;history_key text;sheet_key text;entry_key text;idx int;n int;newrev bigint;begin
 if auth.uid() is null or not public.hh_is_member(p_room) then raise exception 'Nur Raummitglieder';end if;
 perform 1 from public.hh_rooms where id=p_room and ended_at is null for update;if not found then raise exception 'Raum ist nicht aktiv';end if;
 select payload into previous from public.hh_states where room_id=p_room and revision=p_revision for update;if not found then raise exception 'KONFLIKT: Spielstand inzwischen geändert';end if;
 body:=previous;idx:=jsonb_array_length(body->'sessions')-1;a:=body->'sessions'->idx;
 if a->>'gameType' is distinct from p_game then raise exception 'Nur die aktuell gewählte Spielart';end if;
 if p_game in('Bierkopf','Schleifer') then history_key:='games';sheet_key:='current';entry_key:='rounds';
 elsif p_game='Schniffelkopf' then history_key:='snHistory';sheet_key:='snSheet';entry_key:='entries';
 elsif p_game='Klopfer' then history_key:='klHistory';sheet_key:='klSheet';entry_key:='rounds';
 elsif p_game in('21 rückwärts','Schafkopf') then history_key:='extraHistory';sheet_key:='extraGames';entry_key:='rounds';
 else raise exception 'Unbekannte Spielart';end if;
 st:=case when sheet_key='extraGames' then a->sheet_key->p_game else a->sheet_key end;g:=a->history_key->-1;n:=jsonb_array_length(coalesce(g->entry_key,'[]'));
 if st->>'closed' is distinct from 'true' or n=0 or st->entry_key is distinct from g->entry_key or coalesce(g->>'gameType',p_game)<>p_game then raise exception 'Keine zuletzt abgeschlossene Partie zum Wiederöffnen';end if;
 last_r:=g->entry_key->-1;st:=jsonb_set(st,ARRAY[entry_key],(g->entry_key)-(n-1))||jsonb_build_object('closed',false);
 if p_game in('Bierkopf','Schleifer') then st:=st||jsonb_build_object('scores',jsonb_build_array((g->'scores'->>0)::int-case when last_r->>'winner'='0' then (last_r->>'points')::int else 0 end,(g->'scores'->>1)::int-case when last_r->>'winner'='1' then (last_r->>'points')::int else 0 end));a:=a||jsonb_build_object('teams',coalesce(g->'teams',a->'teams'),'members',coalesce(g->'members',a->'members'));a:=jsonb_set(a,ARRAY['teamSetups'],coalesce(a->'teamSetups','{}')||jsonb_build_object(p_game,jsonb_build_object('teams',a->'teams','members',a->'members')));a:=jsonb_set(a,ARRAY['teamCurrentByType'],coalesce(a->'teamCurrentByType','{}')||jsonb_build_object(p_game,st));end if;
 a:=jsonb_set(a,ARRAY[history_key],(a->history_key)-(jsonb_array_length(a->history_key)-1));
 if sheet_key='extraGames' then a:=jsonb_set(a,ARRAY[sheet_key,p_game],st);else a:=jsonb_set(a,ARRAY[sheet_key],st);end if;
 body:=jsonb_set(body,ARRAY['sessions',idx::text],a);body:=public.hh_prepare_room_payload(p_room,body,previous);perform public.hh_validate_room_rules(body,previous,true);
 update public.hh_states set payload=body,revision=revision+1,changed_by=auth.uid(),updated_at=now() where room_id=p_room returning revision into newrev;
 insert into public.hh_audit(room_id,actor,revision,action,previous_payload,new_payload) values(p_room,auth.uid(),newrev,'reopen_last',previous,body);
 return jsonb_build_object('payload',body,'revision',newrev);
end$$;
revoke all on function public.hh_reopen_last_game(uuid,bigint,text) from public,anon;
grant execute on function public.hh_reopen_last_game(uuid,bigint,text) to authenticated;
create or replace function public.hh_rule_solo(sheet jsonb,kind text,people jsonb,finished boolean default false) returns void language plpgsql immutable set search_path='' as $$declare ids jsonb:=sheet->'players';rs jsonb:=case when kind='Schniffelkopf' then sheet->'entries' else sheet->'rounds' end;r jsonb;x jsonb;totals jsonb:='{}';seen text[]:='{}';n int;i int:=0;p int;bid int;actual int;cat int;pid text;k text;done boolean:=false;expected jsonb;begin
 if jsonb_typeof(sheet) is distinct from 'object' or jsonb_typeof(rs) is distinct from 'array' then raise exception 'Regelprüfung: ungültige Einzelspieler-Partie';end if;
 perform public.hh_rule_roster(ids,people,0,32);n:=jsonb_array_length(ids);
 if jsonb_array_length(rs)>0 or finished then perform public.hh_rule_roster(ids,people,case when kind='Schniffelkopf' then 4 else 2 end,32);end if;
 for r in select value from jsonb_array_elements(rs) loop
  if done then raise exception 'Regelprüfung: Partie war bereits beendet';end if;
  if kind='Schniffelkopf' then
   if r->'player' is distinct from ids->(i%n) then raise exception 'Regelprüfung: falsche Spielreihenfolge';end if;
   cat:=public.hh_rule_int(r->'category',0,9);p:=public.hh_rule_int(r->'points',0,120);k:=(r->>'player')||':'||cat;
   if k=any(seen) then raise exception 'Regelprüfung: Kategorie doppelt erfasst';end if;seen:=seen||k;
   select jsonb_agg(ids->((i+j)%n) order by j) into expected from generate_series(1,3) j;
   if r->'opponents' is distinct from expected then raise exception 'Regelprüfung: falsche Gegenspieler';end if;
   i:=i+1;done:=i=n*10;
  else
   if jsonb_typeof(r->'results') is distinct from 'array' or jsonb_array_length(r->'results')<>n then raise exception 'Regelprüfung: Ergebnisse aller Spieler erforderlich';end if;
   select jsonb_agg(value->'id') into expected from jsonb_array_elements(r->'results');perform public.hh_rule_roster(expected,people,n,n);
   if exists(select 1 from jsonb_array_elements(expected) q(value) where not ids@>jsonb_build_array(q.value)) then raise exception 'Regelprüfung: fremder Spieler';end if;
   for x in select value from jsonb_array_elements(r->'results') loop
    pid:=x->>'id';if r->>'entry_format'='buttons-v1' then if n not between 4 and 8 or jsonb_typeof(x->'correct') is distinct from 'boolean' then raise exception 'Klopfer: 4–8 Spieler und Richtig/Falsch erforderlich';end if;bid:=public.hh_rule_int(x->'bid',0,11-n);p:=case when (x->>'correct')::boolean then 5+bid else 0 end;else bid:=public.hh_rule_int(x->'bid',0,6);actual:=public.hh_rule_int(x->'actual',0,6);p:=case when bid=actual then 5+bid else 0 end;end if;
    if public.hh_rule_int(x->'points',0,12)<>p then raise exception 'Regelprüfung: falsche Klopfer-Punkte';end if;
    totals:=jsonb_set(totals,array[pid],to_jsonb(coalesce((totals->>pid)::int,0)+p));
   end loop;
   select exists(select 1 from jsonb_each_text(totals) q where value::int>=51) into done;
  end if;
 end loop;
 if jsonb_typeof(sheet->'closed') is distinct from 'boolean' or (sheet->>'closed')::boolean is distinct from done or finished and not done then raise exception 'Regelprüfung: falscher Abschlussstatus';end if;
end$$;
revoke all on function public.hh_rule_solo(jsonb,text,jsonb,boolean) from public,anon,authenticated;
create or replace function public.hh_validate_room_rules(body jsonb,previous jsonb default '{}',admin_replace boolean default false) returns void language plpgsql security definer set search_path='' as $$declare a jsonb;old_a jsonb;g jsonb;old_g jsonb;sheet jsonb;oldsheet jsonb;key text;kind text;variant text;idx int;sid int;members jsonb;people jsonb:=body->'people';begin
 if jsonb_typeof(people) is distinct from 'array' or jsonb_array_length(people)>200 or jsonb_typeof(body->'sessions') is distinct from 'array' or jsonb_array_length(body->'sessions') not between 1 and 1000 then raise exception 'Regelprüfung: ungültiger Raumumfang';end if;
 if exists(select 1 from jsonb_array_elements(people) p where p->>'authUserId' is not null group by p->>'authUserId' having count(*)>1) then raise exception 'Regelprüfung: ein Benutzerkonto darf nur einmal als Spieler erscheinen';end if;
 if not admin_replace and exists(select 1 from jsonb_array_elements(coalesce(previous->'people','[]')) p where not exists(select 1 from jsonb_array_elements(people) n where n->'id'=p->'id')) then raise exception 'Regelprüfung: Spieler nur über die vorgesehene Gastlöschung entfernen';end if;
 if not admin_replace and previous?'sessions' and (jsonb_array_length(body->'sessions')<jsonb_array_length(previous->'sessions') or jsonb_array_length(body->'sessions')>jsonb_array_length(previous->'sessions')+1) then raise exception 'Regelprüfung: Spielabende dürfen hier nicht entfernt oder ersetzt werden';end if;
 for a,sid in select value,(ordinality-1)::int from jsonb_array_elements(body->'sessions') with ordinality loop
  old_a:=previous->'sessions'->sid;
  if not admin_replace and old_a is not null and old_a->'id' is distinct from a->'id' then raise exception 'Regelprüfung: Spielabend darf nicht ersetzt werden';end if;
  if not admin_replace and old_a is null and exists(select 1 from jsonb_array_elements(coalesce(previous->'sessions','[]')) x where x->'id'=a->'id') then raise exception 'Regelprüfung: doppelte Spielabend-Kennung';end if;
  if not admin_replace and old_a->'members' is distinct from a->'members' and old_a->'current'->>'closed'='false' and coalesce(jsonb_array_length(old_a->'current'->'rounds'),0)>0 and coalesce(jsonb_array_length(a->'current'->'rounds'),0)>0 then raise exception 'Regelprüfung: Teams während der Partie geändert';end if;
  kind:=coalesce(a->>'gameType','Bierkopf');if kind not in('Bierkopf','Schleifer','Schniffelkopf','Klopfer','21 rückwärts','Schafkopf') then raise exception 'Regelprüfung: unbekannte Spielart';end if;
  foreach key in array array['games','snHistory','klHistory'] loop
   if jsonb_typeof(coalesce(a->key,'[]'))<>'array' then raise exception 'Regelprüfung: ungültiger Verlauf';end if;
   if not admin_replace and coalesce(jsonb_array_length(a->key),0)<coalesce(jsonb_array_length(old_a->key),0) then raise exception 'Regelprüfung: archivierte Partien dürfen nicht entfernt werden';end if;
   for g,idx in select value,(ordinality-1)::int from jsonb_array_elements(coalesce(a->key,'[]')) with ordinality loop
    old_g:=old_a->key->idx;
    if old_g is not null and public.hh_score_identity(old_g)=public.hh_score_identity(g) then continue;end if;
    if not admin_replace and old_g is not null then raise exception 'Regelprüfung: archivierte Ergebnisse sind unveränderlich';end if;
    if not admin_replace and idx>coalesce(jsonb_array_length(old_a->key),0) then raise exception 'Regelprüfung: nur eine neue Partie je Speicheraktion';end if;
    if nullif(g->>'date','') is null or exists(select 1 from jsonb_array_elements(coalesce(a->key,'[]')) with ordinality q(x,n) where n-1<>idx and x->>'date'=g->>'date' and coalesce(x->>'gameType',key)=coalesce(g->>'gameType',key)) then raise exception 'Regelprüfung: Partiezeitpunkt fehlt oder Partie doppelt';end if;
    if key='games' then variant:=coalesce(g->>'gameType','Bierkopf');if variant not in('Bierkopf','Schleifer') then raise exception 'Regelprüfung: falsche Teamspielart';end if;perform public.hh_rule_team(g,variant,g->'members',people,true);if not admin_replace then perform public.hh_rule_no_replay(g,case when coalesce(old_a->>'gameType','Bierkopf')=variant then old_a->'current' else old_a->'teamCurrentByType'->variant end,previous,'rounds',false);end if;if not admin_replace and coalesce(old_a->>'gameType','Bierkopf')=variant then perform public.hh_rule_progress(old_a->'current',g,'rounds');end if;
    else perform public.hh_rule_solo(g,case when key='snHistory' then 'Schniffelkopf' else 'Klopfer' end,people,true);if not admin_replace then perform public.hh_rule_no_replay(g,old_a->(case when key='snHistory' then 'snSheet' else 'klSheet' end),previous,case when key='snHistory' then 'entries' else 'rounds' end,false);end if;end if;
   end loop;
  end loop;
  foreach key in array array['current','snSheet','klSheet'] loop
   sheet:=a->key;oldsheet:=old_a->key;if sheet is null then continue;end if;
   if oldsheet is not null and public.hh_score_identity(sheet)=public.hh_score_identity(oldsheet) and (key<>'current' or old_a->>'gameType' is not distinct from a->>'gameType') then continue;end if;
   if key='current' then
    if kind in('Bierkopf','Schleifer') then variant:=kind;else variant:='Bierkopf';end if;
    members:=a->'members';perform public.hh_rule_team(sheet,variant,members,people);if not admin_replace then perform public.hh_rule_no_replay(sheet,case when old_a->>'gameType' is not distinct from a->>'gameType' then oldsheet else old_a->'teamCurrentByType'->variant end,previous,'rounds');end if;
    if not admin_replace and old_a->>'gameType'=a->>'gameType' then perform public.hh_rule_progress(oldsheet,sheet,'rounds');if coalesce(jsonb_array_length(oldsheet->'rounds'),0)>0 and oldsheet->>'closed'='false' and coalesce(jsonb_array_length(sheet->'rounds'),0)>0 and old_a->'members' is distinct from a->'members' then raise exception 'Regelprüfung: Teams während der Partie geändert';end if;end if;
   else variant:=case when key='snSheet' then 'Schniffelkopf' else 'Klopfer' end;perform public.hh_rule_solo(sheet,variant,people);if not admin_replace then perform public.hh_rule_progress(oldsheet,sheet,case when key='snSheet' then 'entries' else 'rounds' end);perform public.hh_rule_no_replay(sheet,oldsheet,previous,case when key='snSheet' then 'entries' else 'rounds' end);end if;end if;
  end loop;
  for variant,sheet in select * from jsonb_each(coalesce(a->'teamCurrentByType','{}')) loop
   if variant not in('Bierkopf','Schleifer') then raise exception 'Regelprüfung: unbekannter Teamspielstand';end if;
   oldsheet:=old_a->'teamCurrentByType'->variant;if oldsheet is not null and public.hh_score_identity(sheet)=public.hh_score_identity(oldsheet) then continue;end if;
   members:=a->'teamSetups'->variant->'members';perform public.hh_rule_team(sheet,variant,members,people);
  end loop;

  if jsonb_typeof(coalesce(a->'extraHistory','[]')) is distinct from 'array' then raise exception 'Ungültiger Zusatzverlauf';end if;
  if not admin_replace and coalesce(jsonb_array_length(a->'extraHistory'),0)<coalesce(jsonb_array_length(old_a->'extraHistory'),0) then raise exception 'Abgeschlossene Zusatzpartien sind geschützt';end if;
  for g,idx in select value,(ordinality-1)::int from jsonb_array_elements(coalesce(a->'extraHistory','[]')) with ordinality loop
   old_g:=old_a->'extraHistory'->idx;if old_g is not null and public.hh_score_identity(g)=public.hh_score_identity(old_g) then continue;end if;
   if not admin_replace and old_g is not null then raise exception 'Abgeschlossene Zusatzpartien sind geschützt';end if;
   if not admin_replace and idx<>coalesce(jsonb_array_length(old_a->'extraHistory'),0) then raise exception 'Nur eine neue Partie je Änderung';end if;
   variant:=g->>'gameType';perform public.hh_rule_extra(g,variant,people,true);if not admin_replace and (a->'extraGames'->variant->>'closed' is distinct from 'true' or g->'rounds' is distinct from a->'extraGames'->variant->'rounds' or g->'players' is distinct from a->'extraGames'->variant->'players' or g->'settings' is distinct from a->'extraGames'->variant->'settings') then raise exception 'Zusatzverlauf muss der abgeschlossenen Partie entsprechen';end if;
   if not admin_replace then perform public.hh_rule_no_replay(g,old_a->'extraGames'->variant,previous,'rounds',false);end if;
  end loop;
  for variant,sheet in select * from jsonb_each(coalesce(a->'extraGames','{}')) loop
   oldsheet:=old_a->'extraGames'->variant;if oldsheet is not null and public.hh_score_identity(sheet)=public.hh_score_identity(oldsheet) then continue;end if;
   perform public.hh_rule_extra(sheet,variant,people);
   if variant='Schafkopf' and (coalesce(jsonb_array_length(sheet->'rounds'),0)>0 and (oldsheet is null or oldsheet->>'closed'='true' or jsonb_array_length(coalesce(oldsheet->'rounds','[]'))=0)) and sheet->'settings' is distinct from coalesce(a->'schafSettings','{"variants":["King","Solo","Wenz","Geier","Sau","Kreuzspiel","Tout"],"capture_colors":false}'::jsonb) then raise exception 'Raumeinstellungen stimmen nicht';end if;
   if not admin_replace then perform public.hh_rule_progress(oldsheet,sheet,'rounds');perform public.hh_rule_no_replay(sheet,oldsheet,previous,'rounds');end if;
  end loop;
  if not admin_replace and old_a->'extraGames' is not null and exists(select 1 from jsonb_each(old_a->'extraGames') q where jsonb_array_length(coalesce(q.value->'rounds','[]'))>0 and q.value->>'closed'='false' and (not(coalesce(a->'extraGames','{}')?q.key) or jsonb_array_length(coalesce(a->'extraGames'->q.key->'rounds','[]'))<jsonb_array_length(coalesce(q.value->'rounds','[]'))-1)) then raise exception 'Laufende Zusatzpartie nur rücknehmen oder beenden';end if;
  if not admin_replace and a->'klSheet' is distinct from old_a->'klSheet' and jsonb_array_length(coalesce(a->'klSheet'->'rounds','[]'))>coalesce(jsonb_array_length(old_a->'klSheet'->'rounds'),0) and (jsonb_array_length(a->'klSheet'->'players') not between 4 and 8 or a->'klSheet'->'rounds'->-1->>'entry_format' is distinct from 'buttons-v1') then raise exception 'Klopfer: neue Einträge nur mit 4–8 Spielern und den neuen Stichbuttons';end if;
 end loop;
end$$;
revoke all on function public.hh_validate_room_rules(jsonb,jsonb,boolean) from public,anon,authenticated;
create or replace function public.hh_prepare_room_payload(p_room uuid,body jsonb,previous jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare session jsonb;sid int;p jsonb;oldp jsonb;known jsonb;anchor timestamptz;name text;begin
 for session,sid in select value,(ordinality-1)::int from jsonb_array_elements(body->'sessions') with ordinality loop if session->'schafSettings' is distinct from previous->'sessions'->sid->'schafSettings' and not public.hh_is_room_owner(p_room) then raise exception 'Schafkopfeinstellungen nur durch Raumersteller';end if;end loop;
 for p in select value from jsonb_array_elements(body->'people') loop
  select x into oldp from jsonb_array_elements(coalesce(previous->'people','[]')) x where x->'id'=p->'id';
  if oldp is not null then
   if (p->>'name' is distinct from oldp->>'name' or p->>'authUserId' is distinct from oldp->>'authUserId' or p->'deleted' is distinct from oldp->'deleted') and not(public.hh_is_room_owner(p_room) and oldp->>'authUserId' is null and p->>'deleted'='true' and p->>'name'='Gelöschter Gast') then raise exception 'Spielernamen sind nach dem Anlegen festgelegt';end if;
  else
   if coalesce(p->>'name','')='' or char_length(p->>'name')>70 or coalesce(p->>'deleted','false')<>'false' then raise exception 'Ungültiger Spielername';end if;
   if exists(select 1 from jsonb_array_elements(body->'people') x where x->'id'<>p->'id' and coalesce(x->>'deleted','false')<>'true' and lower(regexp_replace(trim(x->>'name'),'\s+',' ','g'))=lower(regexp_replace(trim(p->>'name'),'\s+',' ','g'))) then raise exception 'Dieser Name ist in diesem Raum bereits vorhanden';end if;
   if p->>'authUserId' is null and public.hh_name_is_registered(p->>'name') then raise exception 'Dieser Benutzername gehört zu einem registrierten Konto';end if;
   if p->>'authUserId' is not null and not exists(select 1 from public.hh_members where room_id=p_room and user_id::text=p->>'authUserId') then raise exception 'Registrierter Spieler muss bestätigtes Raummitglied sein';end if;
  end if;
 end loop;
 select coalesce(jsonb_object_agg(encode(extensions.digest(public.hh_round_key(value)::text,'sha256'),'hex'),value),'{}') into known from(select value from jsonb_path_query(coalesce(previous,'{}'),'$.**.rounds[*]') q(value) union select value from jsonb_path_query(coalesce(previous,'{}'),'$.**.entries[*]') q(value)) q;
 select coalesce(max((x->>'recorded_at')::timestamptz),(select created_at from public.hh_rooms where id=p_room),now()) into anchor from jsonb_each(known) q(k,x);
 select coalesce(display_username,username,'Spieler') into name from public.hh_profiles where user_id=auth.uid();
 return public.hh_stamp_round_tree(body,known,auth.uid(),coalesce(name,'Spieler'),anchor);
end$$;
create or replace function public.hh_canonical_archive_dates(body jsonb,previous jsonb) returns jsonb language plpgsql set search_path='' as $$declare a jsonb;sid int;key text;idx int;old_n int;begin
 if coalesce(current_setting('hh.validated_admin',true),'')='yes' then return body;end if;
 for a,sid in select value,(ordinality-1)::int from jsonb_array_elements(body->'sessions') with ordinality loop
  foreach key in array array['games','snHistory','klHistory','extraHistory'] loop
   old_n:=coalesce(jsonb_array_length(previous->'sessions'->sid->key),0);
   for idx in old_n..coalesce(jsonb_array_length(a->key),0)-1 loop body:=jsonb_set(body,array['sessions',sid::text,key,idx::text,'date'],to_jsonb(now()));end loop;
  end loop;
 end loop;return body;
end$$;
revoke all on function public.hh_canonical_archive_dates(jsonb,jsonb) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.hh_table_apply(p_table uuid, p_revision bigint, p_action text, p_body jsonb, p_actor uuid, p_actor_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare tb public.hh_tournament_tables;t public.hh_tournaments;r jsonb;side int;base int;mult int;points int;need int;n int;begin
 if p_action not in('round','undo','abort') then raise exception 'Ungültige Tischaktion';end if;
 select * into tb from public.hh_tournament_tables where id=p_table;if not found then raise exception 'Tisch nicht verfügbar';end if;
 select * into t from public.hh_tournaments where id=tb.tournament_id for update;

  select * into tb from public.hh_tournament_tables where id=tb.id for update;

  if t.settings->>'game'='Schafkopf' then perform public.hh_schaf_apply(p_table,p_revision,p_action,p_body,p_actor,p_actor_name);return;end if;
  if t.status<>'running' or tb.stage<>t.stage or (tb.done and p_action<>'undo') then raise exception 'Dieser Tisch ist noch nicht aktiv oder bereits fertig';end if;
  if tb.revision is distinct from (p_revision::text)::bigint then raise exception 'Der Tisch wurde inzwischen geändert. Bitte neu laden.';end if;
  if p_action='abort' then
   if jsonb_array_length(tb.rounds)=0 then raise exception 'Keine laufende Partie';end if;tb.scores:=array[0,0];tb.rounds:='[]';
  elsif p_action='undo' then
   if tb.done or jsonb_array_length(tb.rounds)=0 then r:=tb.games->-1;if r is null then raise exception 'Keine Partie zum Zurücknehmen';end if;tb.scores:=ARRAY[(r->'scores'->>0)::int,(r->'scores'->>1)::int];tb.rounds:=r->'rounds';tb.games:=tb.games-(jsonb_array_length(tb.games)-1);tb.done:=false;end if;
   n:=jsonb_array_length(tb.rounds);if n=0 then raise exception 'Keine laufende Runde zum Zurücknehmen';end if;
   r:=tb.rounds->(n-1);side:=(r->>'winner')::int+1;tb.scores[side]:=tb.scores[side]-(r->>'points')::int;tb.rounds:=tb.rounds-(n-1);
  else
   side:=(p_body->>'winner')::int;base:=(p_body->>'base')::int;mult:=(p_body->>'mult')::int;
   if side is null or side not in(0,1) or base is null or base not in(1,2,3) or mult is null or mult not in(1,2,4,8,12) then raise exception 'Ungültiges Ergebnis';end if;
   points:=least(21-tb.scores[side+1],case when mult=12 then 12 else base*mult end);tb.scores[side+1]:=tb.scores[side+1]+points;
   tb.rounds:=tb.rounds||jsonb_build_array(jsonb_build_object('winner',side,'base',base,'mult',mult,'points',points,'scores',to_jsonb(tb.scores),'date',now(),'actor',p_actor,'actor_name',p_actor_name,'duration_seconds',greatest(0,floor(extract(epoch from(now()-tb.round_started_at))))::int));
   if tb.scores[side+1]=21 then
    tb.games:=tb.games||jsonb_build_array(jsonb_build_object('winner',side,'scores',to_jsonb(tb.scores),'rounds',tb.rounds,'date',now()));
    need:=(t.settings->>'target')::int;
    tb.done:=jsonb_array_length(tb.games)>=need;
    if not tb.done then tb.scores:=array[0,0];tb.rounds:='[]';end if;
   end if;
  end if;
  update public.hh_tournament_tables set scores=tb.scores,rounds=tb.rounds,games=tb.games,done=tb.done,revision=revision+1,round_started_at=now() where id=tb.id;

end$function$;

commit;
