begin;
create or replace function public.hh_rule_extra_v40(sheet jsonb,kind text,people jsonb,finished boolean default false) returns void language plpgsql immutable set search_path='' as $$
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
revoke all on function public.hh_rule_extra_v40(jsonb,text,jsonb,boolean) from public,anon,authenticated;
create or replace function public.hh_krawallo_points(announcement text,result text,shots int) returns int language plpgsql immutable set search_path='' as $$declare base int;begin
 if announcement is null or announcement not in('Grundspiel','Schneider angesagt','Schwarz angesagt','Tout','Aufsteher') or result is null or result not in('Schneider frei','Schneider','Schwarz') or shots is null or shots not between 0 and 10 then raise exception 'Ungültige Krawallo-Wertung';end if;
 if announcement='Aufsteher' then if shots<>0 or result<>'Schwarz' then raise exception 'Ungültiger Aufsteher';end if;return 31;end if;
 if announcement='Tout' then if result<>'Schwarz' then raise exception 'Tout benötigt alle Stiche';end if;return 12*(2^shots)::int;end if;
 if announcement='Schwarz angesagt' and result<>'Schwarz' or announcement='Schneider angesagt' and result='Schneider frei' then raise exception 'Ansage nicht erfüllt';end if;
 base:=case announcement when 'Grundspiel' then 4+case result when 'Schneider' then 1 when 'Schwarz' then 2 else 0 end when 'Schneider angesagt' then 6+case when result='Schwarz' then 1 else 0 end else 8 end;
 return base*(2^shots)::int;
end$$;
revoke all on function public.hh_krawallo_points(text,text,int) from public,anon,authenticated;
create or replace function public.hh_rule_extra(sheet jsonb,kind text,people jsonb,finished boolean default false) returns void language plpgsql immutable set search_path='' as $$
declare r jsonb;x jsonb;ids jsonb:=sheet->'players';expected jsonb;idx int;side int;award int;score int[]:=array[0,0];done boolean:=false;begin
 if kind is distinct from 'Krawallo' then perform public.hh_rule_extra_v40(sheet,kind,people,finished);return;end if;
 if jsonb_typeof(sheet) is distinct from 'object' or jsonb_typeof(sheet->'rounds') is distinct from 'array' or jsonb_array_length(sheet->'rounds')>10000 then raise exception 'Ungültige Krawallo-Partie';end if;
 perform public.hh_rule_roster(ids,people,case when jsonb_array_length(sheet->'rounds')>0 or finished then 4 else 0 end,4);
 for r in select value from jsonb_array_elements(sheet->'rounds') loop
  if done then raise exception 'Krawallo bereits beendet';end if;
  side:=public.hh_rule_int(r->'winner',0,1);
  if coalesce(r->>'variant','') not in('Solo','King','Geier','Wenz') or r->>'variant'='Solo' and coalesce(r->>'suit','') not in('Eichel','Gras','Herz','Schellen') then raise exception 'Krawallo-Spiel ungültig';end if;
  if r->>'announcement'='Aufsteher' and (r->>'variant'<>'Solo' or r->>'suit' is distinct from 'Herz') then raise exception 'Aufsteher ist Herz-Solo';end if;
  award:=public.hh_krawallo_points(r->>'announcement',r->>'result',public.hh_rule_int(r->'shots',0,10));
  if public.hh_rule_int(r->'points',0,40000)<>award then raise exception 'Falsche Krawallo-Punkte';end if;score[side+1]:=score[side+1]+award;
  if r->'scores' is distinct from to_jsonb(score) then raise exception 'Falscher Krawallo-Teamstand';end if;
  if jsonb_typeof(r->'results') is distinct from 'array' or jsonb_array_length(r->'results')<>4 then raise exception 'Vier Spielerergebnisse erforderlich';end if;
  select jsonb_agg(value->'id') into expected from jsonb_array_elements(r->'results');if expected is distinct from ids then raise exception 'Krawallo-Teams geändert';end if;
  idx:=0;for x in select value from jsonb_array_elements(r->'results') loop idx:=idx+1;if public.hh_rule_int(x->'points',0,40000)<>score[case when idx<=2 then 1 else 2 end] then raise exception 'Falsches Krawallo-Spielerergebnis';end if;end loop;
  done:=greatest(score[1],score[2])>=31;
 end loop;
 if jsonb_typeof(sheet->'closed') is distinct from 'boolean' or (sheet->>'closed')::boolean is distinct from done or finished and not done then raise exception 'Falscher Krawallo-Abschluss';end if;
end$$;
revoke all on function public.hh_rule_extra(jsonb,text,jsonb,boolean) from public,anon,authenticated;
create or replace function public.hh_extra_statistics(g jsonb) returns jsonb language sql immutable set search_path='' as $$
with scores as(select (x->'id') id,n,case when g->>'gameType'='21 rückwärts' then 21-(x->>'points')::numeric else (x->>'points')::numeric end points from jsonb_array_elements(coalesce(g->'rounds'->-1->'results','[]')) with ordinality q(x,n))
select coalesce(jsonb_agg(jsonb_build_object('id',id,'points',points,'won',points=(select max(points) from scores),'netPoints',case when g->>'gameType'='Krawallo' then points-coalesce((select points from scores other where other.n=case when scores.n<=2 then 3 else 1 end),0) else null end)),'[]') from scores;
$$;
revoke all on function public.hh_extra_statistics(jsonb) from public,anon,authenticated;

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
  kind:=coalesce(a->>'gameType','Bierkopf');if kind not in('Bierkopf','Schleifer','Schniffelkopf','Klopfer','21 rückwärts','Schafkopf','Krawallo') then raise exception 'Regelprüfung: unbekannte Spielart';end if;
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
 elsif p_game in('21 rückwärts','Schafkopf','Krawallo') then history_key:='extraHistory';sheet_key:='extraGames';entry_key:='rounds';
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
alter table public.hh_saved_player_results drop constraint if exists hh_saved_player_results_game_type_check;
alter table public.hh_saved_player_results add constraint hh_saved_player_results_game_type_check check(game_type in('Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf','21 rückwärts','Krawallo'));
create or replace function public.hh_global_statistics_v10(p_game text,p_days integer) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Bitte anmelden';end if;
 if p_game is null or p_game not in ('all','Bierkopf','Schleifer','Schniffelkopf','Klopfer','Schafkopf','21 rückwärts','Krawallo') or p_days is null or p_days not in (0,7,30,90,365) then raise exception 'Ungültiger Statistikfilter';end if;
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
 select r.*,row_number() over() sheet_id from records r where type in ('Schniffelkopf','Klopfer','Schafkopf','21 rückwärts','Krawallo')
 ), solo_points as (
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'entries','[]')) e where e->>'player'=pid #>> '{}'),0) points from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Schniffelkopf'
 union all
 select room_id,people,type,sheet_id,public.hh_record_time(g->>'date') played_at,pid #>> '{}' pid,coalesce((select sum((e->>'points')::numeric) from jsonb_array_elements(coalesce(g->'rounds','[]')) rnd cross join lateral jsonb_array_elements(coalesce(rnd->'results','[]')) e where e->>'id'=pid #>> '{}'),0) from sheets cross join lateral jsonb_array_elements(coalesce(g->'players','[]')) pid where type='Klopfer'
 union all select room_id,people,type,sheet_id,public.hh_record_time(g->>'date'),e->>'id',(e->>'points')::numeric from sheets cross join lateral jsonb_array_elements(public.hh_extra_statistics(g)) e where type in('Schafkopf','21 rückwärts','Krawallo')
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
 union all select kind,public.hh_record_time(g->>'date'),(e->>'won')::boolean,(e->>'points')::numeric,(e->>'netPoints')::numeric from records cross join lateral jsonb_array_elements(public.hh_extra_statistics(g)) e where kind='Krawallo' and exists(select 1 from jsonb_array_elements(coalesce(people,'[]')) person where person->>'authUserId'=p_user::text and person->'id'=e->'id')
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
 case when kind in('Bierkopf','Schleifer','Krawallo') then coalesce(sum(net),0) else null end net,
 bool_or(points is null) points_incomplete,kind in('Bierkopf','Schleifer','Krawallo') and bool_or(net is null) net_incomplete
 from all_results r where not exists(select 1 from public.hh_statistics_resets x where x.user_id=p_user and(r.played_at is null or r.played_at<=x.since)) group by kind
)
select coalesce(jsonb_object_agg(kind,jsonb_build_object('games',games,'wins',wins,'points',points,'netPoints',net,'pointsIncomplete',points_incomplete,'netIncomplete',net_incomplete)),'{}') from counted;
$$;
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
    insert into public.hh_saved_player_results(source_room,record_key,user_id,game_type,played_at,won,points,round_count,gross_points,net_points) values(old.id,'extra:'||(a->>'id')||':'||gi,uid,g->>'gameType',public.hh_record_time(g->>'date'),(extra_result->>'won')::boolean,(extra_result->>'points')::numeric,jsonb_array_length(g->'rounds'),(extra_result->>'points')::numeric,(extra_result->>'netPoints')::numeric) on conflict do nothing;
   end loop;
  end loop;
 end loop;
return old;
end$$;
create or replace function public.hh_public_score_fields(v jsonb,depth int default 0) returns jsonb language plpgsql immutable set search_path='' as $$declare k text;x jsonb;out jsonb;begin
 if depth>30 then return 'null';end if;
 if jsonb_typeof(v)='array' then select coalesce(jsonb_agg(public.hh_public_score_fields(value,depth+1)),'[]') into out from jsonb_array_elements(v);return out;
 elsif jsonb_typeof(v)='object' then out:='{}';for k,x in select * from jsonb_each(v) loop
  if k=any(array['id','date','teams','members','gameType','games','current','scores','rounds','closed','winner','points','base','mult','schleiferCount','actor_name','duration_seconds','snSheet','snHistory','klSheet','klHistory','players','entries','player','category','opponents','results','bid','tricks','announced','actual','target','correct','entry_format','extraGames','extraHistory','Schafkopf','21 rückwärts','Krawallo','announcement','result','shots','suit','excluded','variant','seat','partner','won','bonus','awards']) then out:=out||jsonb_build_object(k,public.hh_public_score_fields(x,depth+1));end if;
 end loop;return out;end if;return v;
end$$;
notify pgrst,'reload schema';
commit;
