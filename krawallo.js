/* Krawallo house rules: https://krawallo.weebly.com/regeln.html.
 * This module calculates previews only. The database independently validates
 * the same rules, team membership, progression and final score. */
(() => {
  'use strict';
  const VARIANTS=['Solo','King','Geier','Wenz'];
  const ANNOUNCEMENTS=['Grundspiel','Schneider angesagt','Schwarz angesagt','Tout','Aufsteher'];
  const RESULTS=['Schneider frei','Schneider','Schwarz'];
  function points(announcement,result,shots=0){
    if(!ANNOUNCEMENTS.includes(announcement)||!RESULTS.includes(result)||!Number.isInteger(shots)||shots<0||shots>10)throw Error('Ungültige Krawallo-Wertung.');
    if(announcement==='Aufsteher'){if(shots!==0||result!=='Schwarz')throw Error('Aufsteher ohne Multiplikator und mit allen Stichen erfassen.');return 31;}
    if(announcement==='Tout'){if(result!=='Schwarz')throw Error('Tout benötigt alle Stiche.');return 12*2**shots;}
    if(announcement==='Schwarz angesagt'&&result!=='Schwarz'||announcement==='Schneider angesagt'&&result==='Schneider frei')throw Error('Das Ergebnis erfüllt die Ansage nicht.');
    const base=announcement==='Grundspiel'?4+RESULTS.indexOf(result):announcement==='Schneider angesagt'?6+Number(result==='Schwarz'):8;
    return base*2**shots;
  }
  function totals(sheet){const score=[0,0];for(const r of sheet.rounds||[])score[r.winner]+=r.points;return score;}
  function statistics(sheet){const score=totals(sheet),best=Math.max(...score);return sheet.players.map((id,i)=>({id,points:score[i<2?0:1],netPoints:score[i<2?0:1]-score[i<2?1:0],won:score[i<2?0:1]===best&&best>=31}));}
  function round(sheet,draft){
    if(sheet.players.length!==4||new Set(sheet.players).size!==4||!VARIANTS.includes(draft.variant)||![0,1].includes(draft.winner))throw Error('Zwei feste Zweierteams und Gewinner wählen.');
    if(draft.variant==='Solo'&&!['Eichel','Gras','Herz','Schellen'].includes(draft.suit))throw Error('Solofarbe wählen.');
    if(draft.announcement==='Aufsteher'&&(draft.variant!=='Solo'||draft.suit!=='Herz'))throw Error('Aufsteher ist ein Herz-Solo.');
    const scores=totals(sheet);if(Math.max(...scores)>=31)throw Error('Partie bereits beendet.');
    const awarded=points(draft.announcement,draft.result,draft.shots);scores[draft.winner]+=awarded;
    return {...draft,points:awarded,scores,results:sheet.players.map((id,i)=>({id,points:scores[i<2?0:1]})),date:new Date().toISOString()};
  }
  function create(c){
    let key='',draft;
    const node=(tag,cls,text)=>{const n=document.createElement(tag);n.className=cls||'';if(text!==undefined)n.textContent=String(text);return n;};
    const button=(text,action,pressed)=>{const b=node('button','ghost',text);b.type='button';if(pressed!==undefined)b.setAttribute('aria-pressed',String(pressed));b.onclick=()=>Promise.resolve().then(action).catch(c.fail);return b;};
    function render(st,root){
      const signature=c.room()+':'+st.id+':'+st.rounds.length;if(key!==signature){key=signature;draft={winner:null,variant:'Solo',suit:'Eichel',announcement:'Grundspiel',result:'Schneider frei',shots:0};}
      root.replaceChildren();
      const header=document.getElementById('hhSoloScore');header.replaceChildren();header.classList.remove('hide');document.querySelector('.dock-score').classList.add('hide');
      const values=totals(st);const visualTeams=!st.rounds.length&&st.teamsDraft?st.teamsDraft:[st.players.slice(0,2),st.players.slice(2,4)];
      for(let side=0;side<2;side++){const team=node('div','hh-score-person kw-team');const faces=node('div','kw-faces');for(const id of visualTeams[side]){const p=node('div','');p.innerHTML=c.avatar(id,true);p.append(node('span','',c.name(id)));faces.append(p);}team.append(faces,node('strong','',values[side]));header.append(team);}
      if(!st.rounds.length&&!st.closed){const roster=node('div','panel');roster.append(node('h2','','Zwei Teams auswählen'));const columns=node('div','kw-teams');for(let side=0;side<2;side++){const box=node('div','kw-roster');box.append(node('h3','','Team '+(side+1)));const teams=st.teamsDraft||[st.players.slice(0,2),st.players.slice(2,4)],selected=teams[side],other=teams[1-side];for(const p of c.people().filter(p=>!p.deleted&&!other.includes(p.id))){const b=button('',()=>{c.requireWrite();if(st.rounds.length)throw Error('Teams sind während der Partie fest.');const mine=selected.includes(p.id)?selected.filter(id=>id!==p.id):[...selected,p.id];if(mine.length>2)throw Error('Je Team zwei Spieler auswählen.');st.teamsDraft??=[st.players.slice(0,2),st.players.slice(2,4)];st.teamsDraft[side]=mine;st.players=[...(st.teamsDraft[0]||[]),...(st.teamsDraft[1]||[])];/* Keep both team arrays even when one is incomplete. */c.save();},selected.includes(p.id));b.className='hh-avatar-choice extra-player-choice';b.innerHTML=c.selection(p);box.append(b);}columns.append(box);}roster.append(columns);root.append(roster);}
      const panel=node('div','panel');panel.append(node('h2','','Krawallo · bis 31'));
      if(st.closed){panel.append(node('p','tt-running','Partie beendet'),button('Ergebnis anzeigen',()=>result(st)),button('Nächste Partie',()=>c.newGame(st)));}
      else{
        const group=(label,values,value,set)=>{panel.append(node('h3','',label));const row=node('div','kw-options');for(const option of values)row.append(button(option,()=>{set(option);render(st,root)},option===value));panel.append(row);};
        group('Wer erhält die Punkte?',['Team 1','Team 2'],draft.winner===null?null:'Team '+(draft.winner+1),v=>draft.winner=Number(v.slice(-1))-1);
        group('Spiel',VARIANTS,draft.variant,v=>{draft.variant=v;if(v!=='Solo'&&draft.announcement==='Aufsteher')draft.announcement='Grundspiel';});
        if(draft.variant==='Solo')group('Farbe',['Eichel','Gras','Herz','Schellen'],draft.suit,v=>draft.suit=v);
        group('Ansage',ANNOUNCEMENTS,draft.announcement,v=>{draft.announcement=v;if(v==='Tout'||v==='Schwarz angesagt'||v==='Aufsteher')draft.result='Schwarz';if(v==='Schneider angesagt'&&draft.result==='Schneider frei')draft.result='Schneider';if(v==='Aufsteher'){draft.variant='Solo';draft.suit='Herz';draft.shots=0;}});
        const available=draft.announcement==='Grundspiel'?RESULTS:draft.announcement==='Schneider angesagt'?RESULTS.slice(1):['Schwarz'];group('Spielergebnis',available,draft.result,v=>draft.result=v);
        if(draft.announcement!=='Aufsteher'){const label=node('label','','Verdopplungen · Schuss / Re / Sup …'),select=node('select');for(let n=0;n<=10;n++){const option=node('option','',n===0?'Ohne · ×1':n+' · ×'+2**n);option.value=n;select.append(option);}select.value=draft.shots;select.onchange=()=>{draft.shots=Number(select.value);render(st,root)};label.append(select);panel.append(label);}
        panel.append(node('p','kw-preview',points(draft.announcement,draft.result,draft.shots)+' Punkte'));
        const add=button('Partie eintragen',async()=>{c.requireWrite();if(c.session&&c.session().extraGames?.Krawallo!==st)throw Error('Spielstand geändert. Bitte erneut erfassen.');if(draft.announcement==='Tout'||draft.announcement==='Aufsteher'){if(!await c.confirm(draft.announcement+' bestätigen?','Bestätigst du das angezeigte Ergebnis?'))return;c.requireWrite();if(c.session&&c.session().extraGames?.Krawallo!==st)throw Error('Spielstand geändert. Bitte erneut erfassen.');}const r=round(st,draft);st.rounds.push(r);if(Math.max(...r.scores)>=31){c.finish(st);result(st);}else c.save();});add.className='primary hh-wide-button';add.disabled=st.players.length!==4||draft.winner===null||st.teamsDraft?.some(t=>t.length!==2);panel.append(add);
      }
      const back=button('Letzte Partie zurücknehmen',()=>c.undo());back.className='ghost hh-wide-button';back.disabled=!st.rounds.length;panel.append(back);root.append(panel);c.history(st);
    }
    function result(st){let dialog=document.getElementById('hhKrawalloResult');if(!dialog){dialog=node('dialog','hh-confirm-dialog');dialog.id='hhKrawalloResult';document.body.append(dialog);}const score=totals(st),winner=score[0]>score[1]?0:1;dialog.replaceChildren(node('h2','','Krawallo · Ergebnis'),node('strong','kw-final-score',score.join(' : ')),node('p','',st.players.slice(winner*2,winner*2+2).map(c.name).join(' & ')+' gewinnt'));dialog.append(button('Schließen',()=>dialog.close()));if(!dialog.open)dialog.showModal();}
    return {render,clear(){key='';document.getElementById('hhKrawalloResult')?.close();}};
  }
  window.HHKrawallo={points,round,totals,statistics,create};
})();
