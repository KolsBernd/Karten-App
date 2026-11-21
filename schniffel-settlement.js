/* Schniffelkopf result and voluntary settlement preview.
 * Money is calculated in whole cents, never with floating-point euros.
 * The preview does not change scores, store debts or initiate payments.
 */
(() => {
  'use strict';
  const RATES = [3, 5, 10];
  const euro = cents => new Intl.NumberFormat('de-DE', {style:'currency', currency:'EUR'}).format(cents / 100);

  function calculate(scores, rate) {
    if (!RATES.includes(rate)) throw new Error('Bitte x3, x5 oder x10 wählen.');
    if (!Array.isArray(scores) || !scores.length || new Set(scores.map(p=>String(p.id))).size!==scores.length || scores.some(p=>!Number.isSafeInteger(p.points)||p.points<0)) throw new Error('Ungültiges Schniffelkopf-Ergebnis.');
    const rows=scores.map(p=>({id:p.id,points:p.points})).sort((a,b)=>b.points-a.points);
    const best=rows[0].points, leaders=rows.filter(p=>p.points===best);
    let total=0;
    rows.forEach((p,index)=>{
      p.rank=index&&rows[index-1].points===p.points?rows[index-1].rank:index+1;
      p.difference=best-p.points;
      p.payCents=p.difference*rate;
      p.receiveCents=0;
      total+=p.payCents;
    });
    if (!Number.isSafeInteger(total)) throw new Error('Der Betrag ist zu groß.');
    // An indivisible cent is assigned in the displayed leaders' order. The
    // sum received always equals the sum owed, including a shared first place.
    const share=Math.floor(total/leaders.length), remainder=total%leaders.length;
    leaders.forEach((p,index)=>{p.receiveCents=share+Number(index<remainder)});
    return {rows,rate,best,total,leaderCount:leaders.length,remainder};
  }

  function open(scores, presentation) {
    if (!scores?.length) return;
    const dialog=document.getElementById('snWinnerDialog');
    const title=document.getElementById('snWinnerTitle');
    const content=document.getElementById('snWinnerContent');
    const highest=Math.max(...scores.map(p=>p.points));
    const leaders=scores.filter(p=>p.points===highest);
    title.textContent=leaders.length>1?'Geteilter erster Platz!':'Herzlichen Glückwunsch!';
    content.replaceChildren();
    const intro=document.createElement('p');intro.className='small muted';intro.textContent='Schniffelkopf · Partie abgeschlossen';
    const photos=document.createElement('div');photos.className='winner-photos';
    for(const winner of leaders){const person=document.createElement('div');person.className='winner-person';const image=document.createElement('span');image.innerHTML=presentation.avatar(winner.id);const name=document.createElement('strong');name.textContent=presentation.name(winner.id);person.append(image,name);photos.append(person)}
    const heading=document.createElement('h3');heading.textContent='Ausgleich berechnen';
    const explanation=document.createElement('p');explanation.className='small muted';explanation.textContent='Abstand zum ersten Platz × 3, 5 oder 10 Cent je Punkt.';
    const buttons=document.createElement('div');buttons.className='sn-settlement-rates';buttons.setAttribute('role','group');buttons.setAttribute('aria-label','Cent je Differenzpunkt');
    const tableArea=document.createElement('div');tableArea.className='hh-table-scroll sn-settlement-table';
    const summary=document.createElement('p');summary.className='small';summary.setAttribute('role','status');summary.setAttribute('aria-live','polite');
    const draw=rate=>{
      const result=calculate(scores,rate||3);
      tableArea.replaceChildren();
      const table=document.createElement('table');table.className='hh-stat-table';
      const head=table.createTHead().insertRow();
      for(const text of ['Platz / Spieler','Punkte','Abstand','Betrag']){const cell=document.createElement('th');cell.scope='col';cell.textContent=text;head.append(cell)}
      const body=table.createTBody();
      for(const player of result.rows){
        const row=body.insertRow(),name=document.createElement('th');name.scope='row';name.textContent=player.rank+'. '+presentation.name(player.id);row.append(name);
        for(const value of [player.points,player.difference,rate?(player.difference?'Zahlt '+euro(player.payCents):'Erhält '+euro(player.receiveCents)):'—'])row.insertCell().textContent=String(value);
        if(!player.difference)row.className='sn-settlement-leader';
      }
      tableArea.append(table);
      summary.textContent=!rate?'Wähle einen Faktor für die Eurobeträge.':result.total===0?'Alle Spieler liegen gleichauf. Es ist kein Ausgleich nötig.':'Gesamtausgleich: '+euro(result.total)+(result.leaderCount>1?' · Gleichmäßig auf '+result.leaderCount+' Erstplatzierte verteilt.':' an den ersten Platz.')+(result.remainder?' Unteilbare Restcents erhalten die Erstplatzierten in der angezeigten Reihenfolge.':'');
    };
    for(const rate of RATES){const button=document.createElement('button');button.type='button';button.textContent='x'+rate;button.setAttribute('aria-label',rate+' Cent je Differenzpunkt');button.setAttribute('aria-pressed','false');button.onclick=()=>{for(const other of buttons.children)other.setAttribute('aria-pressed',String(other===button));draw(rate)};buttons.append(button)}
    content.append(intro,photos,heading,explanation,buttons,tableArea,summary);draw(null);
    if(!dialog.open)dialog.showModal();
  }
  window.HHSchniffelSettlement={calculate,open,clear(){const dialog=document.getElementById('snWinnerDialog');if(dialog?.open)dialog.close();document.getElementById('snWinnerContent')?.replaceChildren()}};
})();
