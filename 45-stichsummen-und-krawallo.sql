begin;
create or replace function public.hh_validate_room_rules_v42(body jsonb,previous jsonb default '{}',admin_replace boolean default false) returns void language plpgsql security definer set search_path='' as $$declare a jsonb;old_a jsonb;g jsonb;old_g jsonb;sheet jsonb;oldsheet jsonb;key text;kind text;variant text;idx int;sid int;members jsonb;people jsonb:=body->'people';begin
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
  if not admin_replace and a->'klSheet' is distinct from old_a->'klSheet' and jsonb_array_length(coalesce(a->'klSheet'->'rounds','[]'))>coalesce(jsonb_array_length(old_a->'klSheet'->'rounds'),0) and (jsonb_array_length(a->'klSheet'->'players') not between 4 and 8 or coalesce(a->'klSheet'->'rounds'->-1->>'entry_format','') not in('buttons-v1','buttons-v2')) then raise exception 'Klopfer: neue Einträge nur mit 4–8 Spielern und den neuen Stichbuttons';end if;
 end loop;
end$$;
revoke all on function public.hh_validate_room_rules_v42(jsonb,jsonb,boolean) from public,anon,authenticated;
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
   if r->>'entry_format'='buttons-v2' then
    if jsonb_typeof(r->'trick_sum_confirmed') is distinct from 'boolean' then raise exception 'Stichsumme muss geprüft werden';end if;
    if (select coalesce(sum(public.hh_rule_int(e->'bid',0,11-n)),0) from jsonb_array_elements(r->'results') e)<>11-n and r->>'trick_sum_confirmed'<>'true' then raise exception 'Abweichende Klopfer-Stichsumme bestätigen';end if;
   end if;
   if jsonb_typeof(r->'results') is distinct from 'array' or jsonb_array_length(r->'results')<>n then raise exception 'Regelprüfung: Ergebnisse aller Spieler erforderlich';end if;
   select jsonb_agg(value->'id') into expected from jsonb_array_elements(r->'results');perform public.hh_rule_roster(expected,people,n,n);
   if exists(select 1 from jsonb_array_elements(expected) q(value) where not ids@>jsonb_build_array(q.value)) then raise exception 'Regelprüfung: fremder Spieler';end if;
   for x in select value from jsonb_array_elements(r->'results') loop
    pid:=x->>'id';if r->>'entry_format' in('buttons-v1','buttons-v2') then if n not between 4 and 8 or jsonb_typeof(x->'correct') is distinct from 'boolean' then raise exception 'Klopfer: 4–8 Spieler und Richtig/Falsch erforderlich';end if;bid:=public.hh_rule_int(x->'bid',0,11-n);p:=case when (x->>'correct')::boolean then 5+bid else 0 end;else bid:=public.hh_rule_int(x->'bid',0,6);actual:=public.hh_rule_int(x->'actual',0,6);p:=case when bid=actual then 5+bid else 0 end;end if;
    if public.hh_rule_int(x->'points',0,12)<>p then raise exception 'Regelprüfung: falsche Klopfer-Punkte';end if;
    totals:=jsonb_set(totals,array[pid],to_jsonb(coalesce((totals->>pid)::int,0)+p));
   end loop;
   select exists(select 1 from jsonb_each_text(totals) q where value::int>=51) into done;
  end if;
 end loop;
 if jsonb_typeof(sheet->'closed') is distinct from 'boolean' or (sheet->>'closed')::boolean is distinct from done or finished and not done then raise exception 'Regelprüfung: falscher Abschlussstatus';end if;
end$$;
create or replace function public.hh_krawallo_points(announcement text,result text,shots int) returns int language plpgsql immutable set search_path='' as $$declare base int;begin
 if result='Durch' then result:='Schwarz';end if;
 if announcement is null or announcement not in('Grundspiel','Schneider angesagt','Schwarz angesagt','Tout','Aufsteher') or result is null or result not in('Schneider frei','Schneider','Schwarz') or shots is null or shots not between 0 and 10 then raise exception 'Ungültige Krawallo-Wertung';end if;
 if announcement='Aufsteher' then if shots<>0 or result<>'Schwarz' then raise exception 'Ungültiger Aufsteher';end if;return 31;end if;
 if announcement='Tout' then if result<>'Schwarz' then raise exception 'Tout benötigt alle Stiche';end if;return 12*(2^shots)::int;end if;
 if announcement='Schwarz angesagt' and result<>'Schwarz' or announcement='Schneider angesagt' and result='Schneider frei' then raise exception 'Ansage nicht erfüllt';end if;
 base:=case announcement when 'Grundspiel' then 4+case result when 'Schneider' then 1 when 'Schwarz' then 2 else 0 end when 'Schneider angesagt' then 6+case when result='Schwarz' then 1 else 0 end else 8 end;
 return base*(2^shots)::int;
end$$;
create or replace function public.hh_rule_extra(sheet jsonb,kind text,people jsonb,finished boolean default false) returns void language plpgsql immutable set search_path='' as $$
declare r jsonb;x jsonb;ids jsonb:=sheet->'players';expected jsonb;idx int;side int;award int;score int[]:=array[0,0];done boolean:=false;begin
 if kind is distinct from 'Krawallo' then
  perform public.hh_rule_extra_v40(sheet,kind,people,finished);
  if kind='21 rückwärts' then for r in select value from jsonb_array_elements(sheet->'rounds') where value->>'entry_format'='tricks-v2' loop
   if jsonb_typeof(r->'trick_sum_confirmed') is distinct from 'boolean' then raise exception 'Stichsumme muss geprüft werden';end if;
   if (select coalesce(sum(public.hh_rule_int(e->'tricks',0,5)),0) from jsonb_array_elements(r->'results') e where e->>'excluded'='false')<>5 and r->>'trick_sum_confirmed'<>'true' then raise exception 'Abweichende Stichsumme bestätigen';end if;
  end loop;end if;
  return;
 end if;
 if jsonb_typeof(sheet) is distinct from 'object' or jsonb_typeof(sheet->'rounds') is distinct from 'array' or jsonb_array_length(sheet->'rounds')>10000 then raise exception 'Ungültige Krawallo-Partie';end if;
 perform public.hh_rule_roster(ids,people,case when jsonb_array_length(sheet->'rounds')>0 or finished then 4 else 0 end,4);
 for r in select value from jsonb_array_elements(sheet->'rounds') loop
  if done then raise exception 'Krawallo bereits beendet';end if;
  side:=public.hh_rule_int(r->'winner',0,1);
  if coalesce(r->>'variant','') not in('Solo','King','Geier','Wenz','Flatterer') or r->>'entry_format' is distinct from 'krawallo-v2' and r->>'variant'='Solo' and coalesce(r->>'suit','') not in('Eichel','Gras','Herz','Schellen') then raise exception 'Krawallo-Spiel ungültig';end if;
  if r->>'entry_format' is distinct from 'krawallo-v2' and r->>'announcement'='Aufsteher' and (r->>'variant'<>'Solo' or r->>'suit' is distinct from 'Herz') then raise exception 'Aufsteher ist Herz-Solo';end if;
  if r->>'entry_format'='krawallo-v2' then
   perform public.hh_rule_int(r->'shots',0,3);
   if coalesce(r->>'result','') not in('Schneider frei','Schneider','Durch') or r?'suit' then raise exception 'Krawallo: Ergebnis ohne Farberfassung wählen';end if;
  end if;
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
create or replace function public.hh_validate_room_rules(body jsonb,previous jsonb default '{}',admin_replace boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare a jsonb;old_a jsonb;sid int;kind text;st jsonb;old_st jsonb;r jsonb;i int;old_n int;begin
 perform public.hh_validate_room_rules_v42(body,previous,admin_replace);
 if admin_replace then return;end if;
 for a,sid in select value,(ordinality-1)::int from jsonb_array_elements(body->'sessions') with ordinality loop
  old_a:=previous->'sessions'->sid;
  foreach kind in array array['Klopfer','21 rückwärts','Krawallo'] loop
   st:=case when kind='Klopfer' then a->'klSheet' else a->'extraGames'->kind end;
   old_st:=case when kind='Klopfer' then old_a->'klSheet' else old_a->'extraGames'->kind end;
   old_n:=case when old_st->>'closed'='true' then 0 else coalesce(jsonb_array_length(old_st->'rounds'),0) end;
   if st is null or public.hh_score_identity(st)=public.hh_score_identity(old_st) then continue;end if;
   for r,i in select value,(ordinality-1)::int from jsonb_array_elements(coalesce(st->'rounds','[]')) with ordinality loop
    if i<old_n then continue;end if;
    if r->>'entry_format' is distinct from (case kind when 'Klopfer' then 'buttons-v2' when 'Krawallo' then 'krawallo-v2' else 'tricks-v2' end) then raise exception 'Bitte die App aktualisieren und den neuen Eingabedialog verwenden';end if;
   end loop;
  end loop;
 end loop;
end$$;
revoke all on function public.hh_validate_room_rules(jsonb,jsonb,boolean) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
