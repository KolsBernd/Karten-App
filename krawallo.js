/* Krawallo previews and UI. The database independently checks every award.
 * Team ordering is fixed for a started party: the first two IDs form team 1.
 * v2 entries omit suits, add Flatterer and use the visible term Durch.
 * Legacy Schwarz entries remain readable and retain their original points. */
(() => {
  'use strict';
  const VARIANTS = ['Solo', 'King', 'Geier', 'Wenz', 'Flatterer'];
  const ANNOUNCEMENTS = ['Grundspiel', 'Schneider angesagt', 'Schwarz angesagt', 'Tout', 'Aufsteher'];
  const RESULTS = ['Schneider frei', 'Schneider', 'Durch'];
  function points(announcement, result, shots = 0) {
    const outcome = result === 'Schwarz' ? 'Durch' : result;
    if (!ANNOUNCEMENTS.includes(announcement) || !RESULTS.includes(outcome) || !Number.isInteger(shots) || shots < 0 || shots > 10)
      throw Error('Ungültige Krawallo-Wertung.');
    if (announcement === 'Aufsteher') {
      if (shots !== 0 || outcome !== 'Durch') throw Error('Aufsteher ohne Schuss erfassen.');
      return 31;
    }
    if (announcement === 'Tout') {
      if (outcome !== 'Durch') throw Error('Tout benötigt alle Stiche.');
      return 12 * 2 ** shots;
    }
    if (announcement === 'Schwarz angesagt' && outcome !== 'Durch' || announcement === 'Schneider angesagt' && outcome === 'Schneider frei')
      throw Error('Das Ergebnis erfüllt die Ansage nicht.');
    const base = announcement === 'Grundspiel' ? 4 + RESULTS.indexOf(outcome)
      : announcement === 'Schneider angesagt' ? 6 + Number(outcome === 'Durch') : 8;
    return base * 2 ** shots;
  }
  function totals(sheet) {
    const score = [0, 0];
    for (const r of sheet.rounds || []) score[r.winner] += r.points;
    return score;
  }
  function statistics(sheet) {
    const score = totals(sheet), best = Math.max(...score);
    return sheet.players.map((id, i) => ({ id, points: score[i < 2 ? 0 : 1], netPoints: score[i < 2 ? 0 : 1] - score[i < 2 ? 1 : 0], won: score[i < 2 ? 0 : 1] === best && best >= 31 }));
  }
  // Losses have the declared value but award the opposing team. Resolve the
  // canonical bonus once, shared by preview and saved entry validation.
  function outcomeFor(draft) {
    if (draft.result !== 'Verloren') return draft.result === 'Schwarz' ? 'Durch' : draft.result;
    return ['Tout', 'Schwarz angesagt', 'Aufsteher'].includes(draft.announcement) ? 'Durch'
      : draft.announcement === 'Schneider angesagt' ? 'Schneider' : 'Schneider frei';
  }
  function round(sheet, draft) {
    if (sheet.players.length !== 4 || new Set(sheet.players).size !== 4 || !VARIANTS.includes(draft.variant) || ![0, 1].includes(draft.winner))
      throw Error('Zwei feste Zweierteams und Gewinner wählen.');
    if (!Number.isInteger(draft.shots) || draft.shots < 0 || draft.shots > 3) throw Error('Ohne, Kontra, Re oder Sub wählen.');
    const scores = totals(sheet);
    if (Math.max(...scores) >= 31) throw Error('Partie bereits beendet.');
    // A loss awards the same declared value to the opposing team. Store the
    // canonical result so old clients and the server validate the same points.
    const lost = draft.result === 'Verloren';
    const outcome = outcomeFor(draft);
    const winner = lost ? 1 - draft.winner : draft.winner;
    const awarded = points(draft.announcement, outcome, draft.shots);
    scores[winner] += awarded;
    return {
      entry_format: 'krawallo-v2', winner, variant: draft.variant,
      announcement: draft.announcement, result: outcome, shots: draft.shots,
      points: awarded, scores, results: sheet.players.map((id, i) => ({ id, points: scores[i < 2 ? 0 : 1] })), date: new Date().toISOString()
    };
  }
  function create(c) {
    let key = '', draft, submitting = false, teamPanel, rosterKey = '', rosterDraft = [];
    const node = (tag, cls, text) => { const n = document.createElement(tag); n.className = cls || ''; if (text !== undefined) n.textContent = String(text); return n; };
    const button = (text, action, pressed) => {
      const b = node('button', 'ghost', text); b.type = 'button';
      if (pressed !== undefined) b.setAttribute('aria-pressed', String(pressed));
      b.onclick = () => Promise.resolve().then(action).catch(c.fail); return b;
    };
    const teams = st => !st.rounds.length && st.teamsDraft ? st.teamsDraft : [st.players.slice(0, 2), st.players.slice(2, 4)];
    function live(st) {
      c.requireWrite();
      if (c.session && c.session().extraGames?.Krawallo !== st) throw Error('Spielstand geändert. Bitte erneut erfassen.');
    }
    // This is the only Krawallo roster. It lives in Spieler, not in scoring.
    function renderTeams(st) {
      const people = document.getElementById('people');
      if (!people) return;
      const legacy = document.getElementById('team0')?.closest('.panel');
      if (legacy) { legacy.classList.toggle('kw-legacy-hidden', !!st); }
      if (!teamPanel) {
        teamPanel = node('section', 'panel'); teamPanel.id = 'hhKrawalloTeams';
        if (legacy) legacy.before(teamPanel); else people.append(teamPanel);
      }
      teamPanel.hidden = !st;
      if (!st) { rosterKey = ''; teamPanel.replaceChildren(); return; }
      teamPanel.replaceChildren(node('h2', '', 'Teams konfigurieren · Krawallo'));
      if (st.rounds.length) {
        teamPanel.append(node('p', 'small muted', st.closed ? 'Die gespielten Teams bleiben im Ergebnis erhalten.' : 'Die Teams bleiben während der Partie fest.'));
        if (st.closed) teamPanel.append(button('Nächste Partie vorbereiten', () => c.newGame(st)));
        return;
      }
      const signature = c.room() + ':' + st.id + ':' + JSON.stringify(st.players);
      if (rosterKey !== signature) {
        rosterKey = signature;
        rosterDraft = teams(st).map(ids => [...ids]);
      }
      const selectedTeams = rosterDraft, columns = node('div', 'grid kw-teams');
      for (let side = 0; side < 2; side++) {
        const box = node('div', 'stack kw-roster'), selected = selectedTeams[side], other = selectedTeams[1 - side];
        box.append(node('h3', '', 'Team ' + (side + 1) + ' · ' + selected.length + '/2'));
        for (const p of c.people().filter(p => !p.deleted && !other.includes(p.id))) {
          const b = button('', () => {
            live(st);
            if (st.rounds.length || st.closed) throw Error('Teams sind während der Partie fest.');
            const mine = selected.includes(p.id) ? selected.filter(id => id !== p.id) : [...selected, p.id];
            if (mine.length > 2) throw Error('Je Team zwei Spieler auswählen.');
            rosterDraft = selectedTeams.map(ids => [...ids]); rosterDraft[side] = mine;
            renderTeams(st);
          }, selected.includes(p.id));
          b.className = 'hh-avatar-choice extra-player-choice'; b.title = c.name(p.id); b.setAttribute('aria-label', c.name(p.id)); b.innerHTML = c.selection(p); box.append(b);
        }
        columns.append(box);
      }
      const save = button('Teams speichern', () => {
        live(st);
        if (st.rounds.length || st.closed) throw Error('Teams sind während der Partie fest.');
        if (rosterDraft.some(ids => ids.length !== 2) || new Set(rosterDraft.flat()).size !== 4) throw Error('Genau zwei verschiedene Personen pro Team wählen.');
        st.teamsDraft = rosterDraft.map(ids => [...ids]);
        st.players = st.teamsDraft.flat();
        c.save();
      });
      save.className = 'primary hh-wide-button';
      save.disabled = rosterDraft.some(ids => ids.length !== 2);
      teamPanel.append(columns, node('p', 'small muted', 'Genau zwei Personen pro Team. Ausgewählte Spieler erscheinen nicht beim anderen Team. Änderungen mit Teams speichern übernehmen.'), save);
    }
    function render(st, root) {
      const signature = c.room() + ':' + st.id + ':' + st.rounds.length;
      if (key !== signature) { key = signature; draft = { winner: null, variant: 'Solo', announcement: 'Grundspiel', result: 'Schneider frei', shots: 0 }; }
      root.replaceChildren();
      const header = document.getElementById('hhSoloScore'); header.replaceChildren(); header.classList.remove('hide'); document.querySelector('.dock-score').classList.add('hide');
      const values = totals(st), visualTeams = teams(st);
      for (let side = 0; side < 2; side++) {
        const team = node('div', 'hh-score-person kw-team'), faces = node('div', 'kw-faces');
        for (const id of visualTeams[side]) { const p = node('div', 'kw-person'); p.title = c.name(id); p.innerHTML = c.avatar(id, true); p.append(node('span', '', c.name(id))); faces.append(p); }
        team.append(faces, node('strong', '', values[side])); header.append(team);
      }
      const panel = node('div', 'panel kw-scoring'); panel.append(node('h2', '', 'Krawallo · bis 31'));
      if (st.closed) {
        panel.append(node('p', 'tt-running', 'Partie beendet'), button('Ergebnis anzeigen', () => result(st)), button('Nächste Partie', () => c.newGame(st)));
      } else {
        const group = (label, options, value, set, cls = '', optional = false) => {
          const section = node('div', 'kw-field'), heading = node('h3', '', label), row = node('div', 'kw-options ' + cls);
          if (optional) heading.append(node('small', 'muted', ' · optional'));
          for (const [option, text, image] of options) {
            const b = button(text, () => { set(optional && value === option ? 'Grundspiel' : option); render(st, root); }, option === value);
            if (image) { const img = node('img', 'kw-game-icon'); img.src = image; img.alt = ''; b.prepend(img); }
            row.append(b);
          }
          section.append(heading, row); panel.append(section);
        };
        group('Welches Team spielt?', [[0, 'Team 1'], [1, 'Team 2']], draft.winner, v => draft.winner = v, 'kw-winners');
        group('Spiel', VARIANTS.map(v => [v, v, c.icons?.()[v]]), draft.variant, v => draft.variant = v, 'kw-games');
        group('Ansage', ANNOUNCEMENTS.slice(1).map(v => [v, v]), draft.announcement, v => {
          draft.announcement = v;
          if (draft.result !== 'Verloren' && ['Tout', 'Schwarz angesagt', 'Aufsteher'].includes(v)) draft.result = 'Durch';
          else if (v === 'Schneider angesagt' && draft.result === 'Schneider frei') draft.result = 'Schneider';
          if (v === 'Aufsteher') draft.shots = 0;
        }, 'kw-announcements', true);
        if (draft.announcement !== 'Aufsteher') {
          group('Geschossen', [[0, 'Ohne ×1'], [1, 'Kontra ×2'], [2, 'Re ×4'], [3, 'Sub ×8']], draft.shots, v => draft.shots = v, 'kw-shots');
          const available = draft.announcement === 'Grundspiel' ? RESULTS : draft.announcement === 'Schneider angesagt' ? RESULTS.slice(1) : ['Durch'];
          group('Spielergebnis', [...available, 'Verloren'].map(v => [v, v]), draft.result, v => draft.result = v, 'kw-results');
        }
        if (draft.announcement === 'Aufsteher') group('Spielergebnis', ['Durch', 'Verloren'].map(v => [v, v]), draft.result, v => draft.result = v, 'kw-results');
        const previewResult = outcomeFor(draft);
        panel.append(node('p', 'kw-preview', points(draft.announcement, previewResult, draft.shots) + ' Punkte' + (draft.announcement === 'Aufsteher' ? ' · sofort entschieden' : '')));
        if (!st.rounds.length && (st.players.length !== 4 || st.teamsDraft?.some(t => t.length !== 2))) panel.append(button('Teams unter Spieler auswählen', () => c.openPlayers?.()));
        const add = button('Partie eintragen', async () => {
          if (submitting) return;
          live(st);
          const entry = round(st, draft), count = st.rounds.length;
          submitting = true;
          try {
            if (['Tout', 'Aufsteher'].includes(entry.announcement)) {
              if (!await c.confirm(entry.announcement + ' bestätigen?', 'Bestätigst du das angezeigte Ergebnis?')) return;
              live(st);
              if (st.rounds.length !== count || st.closed) throw Error('Spielstand geändert. Bitte erneut erfassen.');
            }
            st.rounds.push(entry);
            if (Math.max(...entry.scores) >= 31) { c.finish(st); result(st); } else c.save();
          } finally { submitting = false; }
        });
        add.className = 'primary hh-wide-button'; add.disabled = st.players.length !== 4 || draft.winner === null || st.teamsDraft?.some(t => t.length !== 2); panel.append(add);
      }
      const back = button('Letzte Partie zurücknehmen', () => c.undo()); back.className = 'ghost hh-wide-button'; back.disabled = !st.rounds.length; panel.append(back); root.append(panel); c.history(st);
    }
    function result(st) {
      let dialog = document.getElementById('hhKrawalloResult');
      if (!dialog) { dialog = node('dialog', 'hh-confirm-dialog'); dialog.id = 'hhKrawalloResult'; document.body.append(dialog); }
      const score = totals(st), winner = score[0] > score[1] ? 0 : 1;
      dialog.replaceChildren(node('h2', '', 'Krawallo · Ergebnis'), node('strong', 'kw-final-score', score.join(' : ')), node('p', '', st.players.slice(winner * 2, winner * 2 + 2).map(c.name).join(' & ') + ' gewinnt'));
      const faces = node('div', 'kw-final-winners');
      for (const id of st.players.slice(winner * 2, winner * 2 + 2)) { const person = node('div'); person.innerHTML = c.avatar(id, true); person.append(node('span', '', c.name(id))); faces.append(person); }
      dialog.insertBefore(faces, dialog.children[1]);
      dialog.append(button('Schließen', () => dialog.close())); if (!dialog.open) dialog.showModal();
    }
    return { render, renderTeams, clear() { key = ''; document.getElementById('hhKrawalloResult')?.close(); } };
  }
  window.HHKrawallo = { points, round, totals, statistics, create };
})();
