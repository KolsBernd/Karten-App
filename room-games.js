/* Additional room games use the same shared payload and server rule validation.
   Point previews are pure; history only changes through the normal room writer. */
(() => {
  'use strict';
  const TYPES = [
      '21 rückwärts',
      'Schafkopf',
      'Krawallo'
    ], SUITS = [
      'Eichel',
      'Gras',
      'Herz',
      'Schellen'
    ];
  const el = (tag, cls, text) => {
    const n = document.createElement(tag);
    if (cls)
      n.className = cls;
    if (text !== undefined)
      n.textContent = String(text);
    return n;
  };
  function backwards(players, rounds) {
    const scores = new Map(players.map(id => [
      id,
      21
    ]));
    for (const round of rounds)
      for (const result of round.results || [])
        scores.set(result.id, result.points);
    return players.map(id => ({
      id,
      points: scores.get(id)
    }));
  }
  function backwardRound(players, rounds, suit, choices) {
    if (!SUITS.includes(suit))
      throw Error('Bitte eine Farbe wählen.');
    const previous = backwards(players, rounds), factor = suit === 'Herz' ? 2 : 1;
    const results = previous.map(p => {
      const choice = choices.get(p.id) || {
        tricks: 0,
        excluded: false
      };
      if (!Number.isInteger(choice.tricks) || choice.tricks < 0 || choice.tricks > 5 || suit === 'Eichel' && choice.excluded)
        throw Error('Ungültige Stichzahl oder Eichel-Auswahl.');
      return {
        id: p.id,
        tricks: choice.tricks,
        excluded: !!choice.excluded,
        points: p.points + (choice.excluded ? 0 : choice.tricks === 0 ? 5 * factor : -choice.tricks * factor)
      };
    });
    if (results.every(r => r.excluded))
      throw Error('Mindestens ein Spieler muss mitspielen.');
    return {
      suit,
      entry_format: 'tricks-v2',
      trick_sum_confirmed: false,
      results,
      date: new Date().toISOString()
    };
  }
  function statistics(record) {
    if (record.gameType === 'Krawallo') return window.HHKrawallo.statistics(record);
    if (record.gameType === '21 rückwärts') {
      const scores = backwards(record.players, record.rounds), best = Math.min(...scores.map(p => p.points));
      return scores.map(p => ({
        id: p.id,
        points: 21 - p.points,
        won: p.points === best
      }));
    }
    const scores = record.rounds?.[0]?.results || [];
    const best = Math.max(0, ...scores.map(p => p.points));
    return scores.map(p => ({
      id: p.id,
      points: p.points,
      won: p.points === best && best > 0
    }));
  }
  function create(c) {
    let entryBusy = false;
    let draftKey = '', suit = 'Eichel', choices = new Map(), busy = false, schafMounted = false, settingsDraft = null, settingsKey = '';
    const krawallo = window.HHKrawallo.create({...c,requireWrite,finish,newGame,undo,history});
    const root = el('section', 'hide');
    root.id = 'hhExtraGame';
    document.getElementById('play').before(root);
    const settings = el('section', 'panel');
    settings.id = 'hhRoomSchafSettings';
    document.getElementById('roomsettings').append(settings);
    const defaultSettings = () => ({
      variants: [
        'King',
        'Solo',
        'Wenz',
        'Geier',
        'Sau',
        'Kreuzspiel',
        'Tout'
      ],
      capture_colors: false
    });
    function sheet() {
      const a = c.session(), kind = c.type();
      a.extraGames ??= {};
      return a.extraGames[kind] ??= {
        id: Date.now(),
        players: c.people().filter(p => !p.deleted).slice(0, ['Schafkopf','Krawallo'].includes(kind) ? 4 : 8).map(p => p.id),
        rounds: [],
        closed: false,
        settings: structuredClone(a.schafSettings || defaultSettings())
      };
    }
    function button(text, action, cls = 'ghost') {
      const b = el('button', cls, text);
      b.type = 'button';
      b.onclick = () => act(action);
      return b;
    }
    function requireWrite() {
      if (!c.room() || !c.user() || c.pending() || navigator.onLine === false)
        throw Error('Bitte anmelden und das Speichern mit Internetverbindung abwarten.');
      if (busy)
        throw Error('Bitte kurz warten.');
    }
    async function act(action) {
      try {
        await action();
      } catch (error) {
        c.fail(error);
      }
    }
    function roster(st) {
      const area = el('div', 'panel extra-roster');
      area.append(el('h2', '', 'Spieler auswählen'));
      for (const p of c.people().filter(p => !p.deleted)) {
        const b = button('', () => {
          requireWrite();
          if (st.rounds.length)
            throw Error('Spieler erst vor der nächsten Partie ändern.');
          st.players = st.players.includes(p.id) ? st.players.filter(id => id !== p.id) : [
            ...st.players,
            p.id
          ];
          if (st.players.length > (c.type() === 'Schafkopf' ? 4 : 32)) {
            st.players.pop();
            throw Error('Für Schafkopf genau vier Spieler wählen.');
          }
          c.save();
        });
        b.className = 'hh-avatar-choice extra-player-choice';
        b.setAttribute('aria-pressed', String(st.players.includes(p.id)));
        b.innerHTML = c.selection(p);
        area.append(b);
      }
      return area;
    }
    function scores(st) {
      if (c.type() === '21 rückwärts')
        return backwards(st.players, st.rounds);
      const result = new Map(st.players.map(id => [
        id,
        0
      ]));
      for (const record of c.session().extraHistory || [])
        if (record.gameType === 'Schafkopf')
          for (const p of statistics(record))
            if (result.has(p.id))
              result.set(p.id, result.get(p.id) + p.points);
      if (!st.closed)
        for (const round of st.rounds)
          for (const p of round.results)
            if (result.has(p.id))
              result.set(p.id, result.get(p.id) + p.points);
      return st.players.map(id => ({
        id,
        points: result.get(id)
      }));
    }
    function header(st) {
      const holder = document.getElementById('hhSoloScore');
      holder.classList.remove('hide');
      document.querySelector('.dock-score').classList.add('hide');
      holder.replaceChildren();
      for (const p of scores(st)) {
        const cell = el('div', 'hh-score-person');
        cell.innerHTML = c.avatar(p.id, true);
        cell.append(el('span', '', c.name(p.id)), el('strong', '', p.points));
        holder.append(cell);
      }
    }
    function finish(st) {
      st.closed = true;
      st.gameType = c.type();
      st.date = new Date().toISOString();
      (c.session().extraHistory ??= []).push(structuredClone(st));
      c.save();
      if (c.type() === '21 rückwärts')
        resultDialog(st);
    }
    function newGame(st) {
      requireWrite();
      c.session().extraGames[c.type()] = {
        id: Date.now(),
        players: st.players.filter(id => c.people().some(p => p.id === id && !p.deleted)),
        rounds: [],
        closed: false,
        settings: structuredClone(c.session().schafSettings || defaultSettings())
      };
      c.save();
    }
    async function undo(confirmed = false) {
      requireWrite();
      const st = sheet();
      if (!st.rounds.length)
        return;
      if (st.closed)
        return c.reopen(c.type(), confirmed);
      if (!confirmed && !await c.confirm('Letzte Partie zurücknehmen?', 'Der letzte Eintrag wird entfernt. Fortfahren?'))
        return;
      st.rounds.pop();
      c.save();
    }
    function resultDialog(st) {
      let d = document.getElementById('hhBackwardResult');
      if (!d) {
        d = el('dialog', 'hh-confirm-dialog');
        d.id = 'hhBackwardResult';
        document.body.append(d);
      }
      d.replaceChildren(el('h2', '', '21 rückwärts \xB7 Ergebnis'));
      const list = backwards(st.players, st.rounds).sort((a, b) => a.points - b.points), best = list[0]?.points;
      for (const p of list) {
        const row = el('div', 'entry');
        row.innerHTML = c.avatar(p.id, true);
        row.append(el('span', '', c.name(p.id) + (p.points === best ? ' \xB7 Gewonnen' : '')), el('strong', '', p.points + ' Punkte'));
        d.append(row);
      }
      d.append(button('Schließen', () => d.close(), 'primary hh-wide-button'));
      if (!d.open)
        d.showModal();
    }
    function backwardUI(st) {
      header(st);
      root.replaceChildren();
      if (!st.rounds.length && !st.closed)
        root.append(roster(st));
      const panel = el('div', 'panel');
      panel.append(el('h2', '', '21 rückwärts'));
      if (st.closed) {
        panel.append(el('p', 'tt-running', 'Partie beendet'), button('Ergebnis anzeigen', () => resultDialog(st)), button('Neue Partie', () => newGame(st), 'primary hh-wide-button'));
      } else {
        const key = c.room() + ':' + st.id + ':' + st.rounds.length;
        if (key !== draftKey) {
          draftKey = key;
          suit = 'Eichel';
          choices = new Map();
        }
        const suits = el('div', 'extra-suits');
        for (const name of SUITS) {
          const b = button(name, () => {
            suit = name;
            if (name === 'Eichel')
              for (const v of choices.values())
                v.excluded = false;
            backwardUI(st);
          });
          b.setAttribute('aria-pressed', String(suit === name));
          const image = el('img');
          image.src = 'cards/' + name.toLowerCase() + '.svg';
          image.alt = '';
          b.prepend(image);
          suits.append(b);
        }
        panel.append(suits);
        for (const id of st.players) {
          const state = choices.get(id) || {
            tricks: 0,
            excluded: false
          };
          choices.set(id, state);
          const row = el('div', 'extra-score-row' + (state.excluded ? ' extra-excluded' : '')), name = el('div', 'extra-score-name');
          name.innerHTML = c.avatar(id, true);
          name.append(el('span', '', c.name(id)));
          const nums = el('div', 'extra-numbers');
          for (let n = 0; n <= 5; n++) {
            const b = button(n, () => {
              state.tricks = n;
              backwardUI(st);
            });
            b.disabled = state.excluded;
            b.setAttribute('aria-pressed', String(n === state.tricks));
            nums.append(b);
          }
          const exclude = button('X', () => {
            state.excluded = !state.excluded;
            backwardUI(st);
          });
          exclude.setAttribute('aria-label', c.name(id) + ' für dieses Spiel aussetzen');
          exclude.setAttribute('aria-pressed', String(state.excluded));
          exclude.disabled = suit === 'Eichel';
          row.append(name, nums, exclude);
          panel.append(row);
        }
        panel.append(button('Partie eintragen', async () => {
          if (entryBusy) return;
          requireWrite();
          if (st.players.length < 2) throw Error('Mindestens zwei Spieler auswählen.');
          entryBusy = true;
          try {
            const round = backwardRound(st.players, st.rounds, suit, choices);
            const count = st.rounds.length;
            const sum = round.results.filter(p => !p.excluded).reduce((n,p) => n+p.tricks,0);
            if (sum !== 5) {
              if (!await c.confirm('Stichsumme prüfen', 'Es sind '+sum+' statt 5 Stiche eingetragen. Möchtest du die Punkte trotzdem speichern?')) return;
              round.trick_sum_confirmed = true;
            }
            requireWrite();
            if (c.type() !== '21 rückwärts' || sheet() !== st || st.rounds.length !== count || st.closed) throw Error('Spielstand geändert. Bitte erneut erfassen.');
            st.rounds.push(round);
            if (round.results.some(p => p.points <= 0)) finish(st); else c.save();
          } finally { entryBusy = false; }
        }, 'primary hh-wide-button'));
      }
      const back = button('Letzte Partie zurücknehmen', undo, 'ghost hh-wide-button');
      back.disabled = !st.rounds.length;
      panel.append(back);
      root.append(panel);
      history(st);
    }
    function history(st) {
      const panel = el('div', 'panel');
      panel.append(el('h2', '', 'Aktuelle Runden'));
      for (const [i, round] of [...st.rounds.entries()].reverse()) {
        const row = el('div', 'entry');
        row.append(el('span', '', i + 1 + '. ' + (round.suit || round.variant || 'Partie') + ' \xB7 ' + (round.actor_name || '') + ' ' + (round.duration_seconds == null ? '' : round.duration_seconds + ' Sek.')), el('strong', '', round.results.map(p => p.points).join(' : ')));
        panel.append(row);
      }
      root.append(panel);
    }
    function schafUI(st) {
      if (st.players.length !== 4 || !st.rounds.length && !st.closed) {
        root.replaceChildren(roster(st));
        header(st);
        if (st.players.length !== 4) {
          root.append(el('p', 'small muted', 'Genau vier Spieler auswählen.'));
          return;
        }
      }
      const people = st.players.map(id => ({
        ...c.people().find(p => p.id === id),
        name: c.name(id)
      }));
      const model = {
        table_id: 'room:' + c.room() + ':' + st.id,
        title: c.title(),
        people,
        schaf_scores: scores(st).map(p => p.points),
        schaf_games: st.rounds.map(r => ({
          scores: r.results.map(p => p.points),
          rounds: [r],
          winners: r.results.flatMap((p, i) => p.points > 0 ? [i] : [])
        })),
        allowed_games: st.settings.variants,
        capture_colors: st.settings.capture_colors,
        started_at: c.session().date,
        target: 1,
        done: st.closed
      };
      window.HHSchafkopf.render(model, async (action, body) => {
        if (action === 'undo')
          return undo(true);
        requireWrite();
        const awards = window.HHSchafkopf.awards(body.seat, body.variant, body.won, body.bonus, body.partner);
        st.rounds.push({
          ...body,
          results: st.players.map((id, i) => ({
            id,
            points: awards[i]
          })),
          awards,
          date: new Date().toISOString()
        });
        finish(st);
      }, {
        confirm: c.confirm,
        room: true
      });
      schafMounted = true;
      const gameRoot = document.getElementById('hhTournamentSchafView');
      root.replaceChildren();
      if (!st.rounds.length)
        root.append(roster(st));
      if (st.closed)
        gameRoot.prepend(button('Nächste Partie', () => newGame(st), 'primary hh-wide-button'));
    }
    function renderSettings() {
      settings.replaceChildren(el('h2', '', 'Schafkopfeinstellungen'));
      if (!c.room())
        return;
      const cfg = c.session().schafSettings || defaultSettings();
      const signature = c.room() + ':' + c.session().id + ':' + JSON.stringify(cfg);
      if (signature !== settingsKey) {
        settingsKey = signature;
        settingsDraft = structuredClone(cfg);
      }
      const editing = settingsDraft;
      if (!c.owner()) {
        settings.append(el('p', 'small muted', 'Nur der Raumersteller kann diese Einstellungen ändern.'));
        return;
      }
      const form = el('form');
      const map = new Map();
      for (const type of defaultSettings().variants) {
        const label = el('label', 'hh-check'), input = el('input');
        input.type = 'checkbox';
        input.checked = editing.variants.includes(type);
        input.onchange = () => {
          editing.variants = input.checked ? [...new Set([
              ...editing.variants,
              type
            ])] : editing.variants.filter(v => v !== type);
        };
        map.set(type, input);
        label.append(input, document.createTextNode(type));
        form.append(label);
      }
      const colors = el('input');
      colors.type = 'checkbox';
      colors.checked = editing.capture_colors;
      colors.onchange = () => {
        editing.capture_colors = colors.checked;
      };
      const label = el('label', 'hh-check');
      label.append(colors, document.createTextNode('Farben erfassen'));
      const submit = el('button', 'primary hh-wide-button', 'Einstellungen speichern');
      submit.type = 'submit';
      form.append(label, submit);
      form.onsubmit = event => {
        event.preventDefault();
        act(() => {
          requireWrite();
          const current = c.session().extraGames?.Schafkopf;
          if (current?.rounds.length && !current.closed)
            throw Error('Bitte die laufende Partie zuerst abschließen.');
          const variants = [...map].filter(([, input]) => input.checked).map(([name]) => name);
          if (!variants.some(name => name !== 'Tout'))
            throw Error('Mindestens ein Spiel wählen.');
          c.session().schafSettings = {
            variants,
            capture_colors: colors.checked
          };
          if (current && !current.rounds.length)
            current.settings = structuredClone(c.session().schafSettings);
          c.save();
        });
      };
      settings.append(form);
    }
    function renderArchive() {
      let box = document.getElementById('hhExtraHistory');
      if (!box) {
        box = el('div');
        box.id = 'hhExtraHistory';
        document.getElementById('sessions')?.after(box);
      }
      const open = new Set([...box.querySelectorAll('details[open]')].map(n => n.dataset.key));
      box.replaceChildren();
      for (const session of c.sessions())
        for (const g of [...session.extraHistory || []].reverse()) {
          const item = el('details', 'panel');
          item.dataset.key = session.id + ':' + g.id + ':' + g.date;
          item.open = open.has(item.dataset.key);
          item.append(el('summary', '', g.gameType + ' \xB7 ' + new Date(g.date).toLocaleString('de-DE')));
          for (const p of statistics(g)) {
            const row = el('div', 'entry');
            row.innerHTML = c.avatar(p.id, true);
            row.append(el('span', '', c.name(p.id) + (p.won ? ' \xB7 Gewonnen' : '')), el('strong', '', g.gameType === '21 rückwärts' ? 21 - p.points + ' Restpunkte' : p.points + ' Punkte'));
            item.append(row);
          }
          for (const [i, r] of g.rounds.entries())
            item.append(el('p', 'small muted', i + 1 + '. ' + (r.suit || r.variant) + ' \xB7 ' + r.results.map(p => c.name(p.id) + ': ' + p.points).join(' \xB7 ') + ' \xB7 ' + (r.actor_name || '') + ' \xB7 ' + (r.duration_seconds || 0) + ' Sek.'));
          box.append(item);
        }
    }
    function render() {
      renderArchive();
      const kind = c.type();
      krawallo.renderTeams(kind === 'Krawallo' ? sheet() : null);
      const active = TYPES.includes(kind) && !window.HHPlayTournament?.active(), playing = active && document.getElementById('tabPlay').classList.contains('active');
      root.classList.toggle('hide', !playing);
      if (schafMounted && (!playing || kind !== 'Schafkopf')) {
        window.HHSchafkopf.clear();
        schafMounted = false;
      }
      if (!active) {
        root.replaceChildren();
        renderSettings();
        return;
      }
      document.querySelectorAll('#play > .panel').forEach(p => p.classList.add('hide'));
      document.getElementById('schniffel').classList.add('hide');
      document.getElementById('klopfer').classList.add('hide');
      const st = sheet();
      document.querySelectorAll('#gameSegments button').forEach(b => b.disabled = !!(st.rounds.length && !st.closed));
      if (playing) {
        if (kind === 'Krawallo')
          krawallo.render(st, root);
        else if (kind === '21 rückwärts')
          backwardUI(st);
        else
          schafUI(st);
      }
      renderSettings();
    }
    function canSwitch() {
      if (!TYPES.includes(c.type()))
        return true;
      const st = sheet();
      return !st.rounds.length || st.closed;
    }
    return {
      render,
      sheet,
      undo,
      canSwitch,
      clear() {
        draftKey = '';
        krawallo.clear();
        choices.clear();
        document.getElementById('hhBackwardResult')?.close();
      }
    };
  }
  window.HHRoomGames = {
    create,
    statistics,
    backwards,
    backwardRound,
    TYPES
  };
})();
