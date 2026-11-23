begin;
-- Preserve the existing authentication, visibility and revision checks. Only
-- extend the explicit room-game allowlists and the shared award calculator.
do $migration$
declare def text; updated text;
begin
 select pg_get_functiondef('public.hh_schaf_awards(integer,text,boolean,text,integer)'::regprocedure) into def;
 if position('variant=''Bettel''' in def)=0 then
  updated:=replace(def,'elsif variant in(''Kreuzspiel'',''Sau'') then',
  'elsif variant=''Bettel'' then
   if not won or bonus not in(''normal'',''schneider'',''durch'') then raise exception ''Bettel: Gewinner und gültiges Ergebnis wählen'';end if;
   a[seat+1]:=case bonus when ''normal'' then 1 when ''schneider'' then 2 else 3 end;
  elsif variant in(''Kreuzspiel'',''Sau'') then');
  if updated=def then raise exception 'Unerwartete Schafkopf-Regelversion';end if;
  execute updated;
 end if;
 select pg_get_functiondef('public.hh_rule_extra_v40(jsonb,text,jsonb,boolean)'::regprocedure) into def;
 updated:=replace(replace(def,'''Sau'',''Kreuzspiel'',''Tout''','''Sau'',''Kreuzspiel'',''Bettel'',''Tout'''),'''Sau'',''Kreuzspiel''))','''Sau'',''Kreuzspiel'',''Bettel''))');
 if position('''Bettel''' in updated)=0 then raise exception 'Unerwartete Raumeinstellungen-Version';end if;
 execute updated;
 select pg_get_functiondef('public.hh_evening_action(text,uuid,jsonb)'::regprocedure) into def;
 updated:=replace(def,'array[''Bierkopf'',''Schniffelkopf'',''Schleifer'',''Klopfen'',''Schafkopf'']','array[''Bierkopf'',''Schniffelkopf'',''Schleifer'',''Klopfen'',''Schafkopf'',''21 rückwärts'',''Krawallo'']');
 if position('''Krawallo''' in updated)=0 then raise exception 'Unerwartete Anfrage-Regelversion';end if;
 execute updated;
 select pg_get_functiondef('public.hh_open_evening(uuid,boolean)'::regprocedure) into def;
 updated:=replace(def,'when ''Klopfen''=any(e.games) then ''Klopfer'' else ''Bierkopf'' end',
 'when ''Klopfen''=any(e.games) then ''Klopfer'' when ''Schafkopf''=any(e.games) then ''Schafkopf'' when ''21 rückwärts''=any(e.games) then ''21 rückwärts'' when ''Krawallo''=any(e.games) then ''Krawallo'' else ''Bierkopf'' end');
 if position('when ''Krawallo''=any(e.games)' in updated)=0 then raise exception 'Unerwartete Anfrage-Startversion';end if;
 execute updated;
end $migration$;
-- Assertions run in the same transaction; a failed assertion rolls everything back.
do $checks$
begin
 if public.hh_schaf_awards(0,'Bettel',true,'normal',1)<>array[1,0,0,0]
 or public.hh_schaf_awards(1,'Bettel',true,'schneider',0)<>array[0,2,0,0]
 or public.hh_schaf_awards(3,'Bettel',true,'durch',0)<>array[0,0,0,3]
 or public.hh_schaf_awards(0,'Sau',true,'durch',1)<>array[3,3,0,0]
 or public.hh_schaf_awards(0,'Kreuzspiel',true,'schneider',2)<>array[2,0,2,0]
 then raise exception 'Schafkopf-Regressionsprüfung fehlgeschlagen';end if;
end $checks$;
commit;
