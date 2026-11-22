/* Numeric Schniffelkopf cells and compact Klopfer controls. Stored legacy
   bid/actual fields remain compatible; buttons are only the input presentation. */
(() => {
  'use strict';
  const drafts = new Map();
  function klMaximum(players) {
    return Math.max(0, 11 - players);
  }
  function decorateSchniffel(context) {
    const input = document.getElementById('snInputArea');
    if (input)
      input.hidden = true;
    const table = document.getElementById('snTable');
    if (!table)
      return;
    let actions = document.getElementById('snCellActions');
    if (!actions) {
      actions = document.createElement('div');
      actions.id = 'snCellActions';
      actions.className = 'sn-actions';
      const undo = document.createElement('button');
      undo.type = 'button';
      undo.className = 'ghost hh-wide-button';
      undo.textContent = 'Letzte Partie zurücknehmen';
      undo.onclick = () => window.snUndo();
      actions.append(undo);
      table.closest('.sn-table-wrap')?.after(actions);
      if (!actions.isConnected)
        table.after(actions);
    }
    actions.hidden = context.sheet.closed;
    actions.firstElementChild.disabled = !context.sheet.entries.length;
    for (const button of table.querySelectorAll('button.sn-available,button.sn-selected')) {
      const match = button.getAttribute('onclick')?.match(/snChoose\((\d+)\)/);
      if (!match || button.disabled)
        continue;
      const category = Number(match[1]);
      button.removeAttribute('onclick');
      button.textContent = '0';
      button.classList.add('sn-cell-input');
      button.onclick = () => openCell(context, category);
    }
  }
  function openCell(context, category) {
    const initial = context.read(), turn = initial.next, entryCount = initial.sheet.entries.length;
    if (!turn || initial.sheet.closed)
      return;
    let dialog = document.getElementById('snCellDialog');
    if (!dialog) {
      dialog = document.createElement('dialog');
      dialog.id = 'snCellDialog';
      dialog.className = 'hh-confirm-dialog';
      document.body.append(dialog);
    }
    const form = document.createElement('form'), title = document.createElement('h2'), label = document.createElement('label'), field = document.createElement('input'), message = document.createElement('p'), actions = document.createElement('div'), save = document.createElement('button'), cancel = document.createElement('button');
    title.textContent = initial.name(turn.id) + ' \xB7 ' + initial.category(category);
    field.id = 'snCellPoints';
    field.type = 'text';
    field.inputMode = 'numeric';
    field.pattern = '[0-9]{1,3}';
    field.maxLength = 3;
    field.autocomplete = 'off';
    field.value = '0';
    field.required = true;
    label.htmlFor = field.id;
    label.textContent = 'Punkte (0\u2013120)';
    message.className = 'small muted';
    message.setAttribute('role', 'status');
    save.type = 'submit';
    save.className = 'primary';
    save.textContent = 'Punkte eintragen';
    cancel.type = 'button';
    cancel.className = 'ghost';
    cancel.textContent = 'Abbrechen';
    cancel.onclick = () => dialog.close();
    actions.className = 'hh-dialog-actions';
    actions.append(cancel, save);
    form.append(title, label, field, message, actions);
    dialog.replaceChildren(form);
    form.onsubmit = async event => {
      event.preventDefault();
      if (!/^\d{1,3}$/.test(field.value) || Number(field.value) > 120) {
        message.textContent = 'Bitte 0 bis 120 Punkte eingeben.';
        field.focus();
        return;
      }
      const now = context.read();
      if (now.type !== initial.type || now.session !== initial.session || now.room !== initial.room || now.next?.id !== turn.id || now.sheet.entries.length !== entryCount || now.sheet.closed) {
        message.textContent = 'Der Spielstand wurde geändert. Bitte erneut auswählen.';
        save.disabled = true;
        return;
      }
      save.disabled = true;
      try {
        window.snChoose(category);
        document.getElementById('snPoints').value = field.value;
        await window.snAdd();
        dialog.close();
      } catch (error) {
        message.textContent = error.message;
        save.disabled = false;
      }
    };
    dialog.showModal();
    field.focus();
    field.select();
  }
  function decorateKlopfer(sheet, session) {
    const root = document.getElementById('klInputs');
    if (!root || sheet.closed)
      return;
    const key = String(session) + ':' + sheet.rounds.length + ':' + sheet.players.join(',');
    for (const old of drafts.keys())
      if (old !== key)
        drafts.delete(old);
    const chosen = drafts.get(key) || new Map();
    drafts.set(key, chosen);
    for (const id of sheet.players) {
      const bid = document.getElementById('klBid-' + id), actual = document.getElementById('klActual-' + id);
      if (!bid || !actual)
        continue;
      const row = bid.parentElement;
      bid.hidden = true;
      actual.hidden = true;
      row.querySelector('.kl-button-entry')?.remove();
      const max = klMaximum(sheet.players.length);
      for (const select of [
          bid,
          actual
        ]) {
        select.replaceChildren();
        for (let n = 0; n <= Math.max(1, max); n++) {
          const option = document.createElement('option');
          option.value = String(n);
          option.textContent = String(n);
          select.append(option);
        }
      }
      let state = chosen.get(id) || {
        number: 0,
        correct: null
      };
      if (state.number > max)
        state = {
          number: 0,
          correct: null
        };
      chosen.set(id, state);
      const box = document.createElement('div');
      box.className = 'kl-button-entry';
      const numbers = document.createElement('div');
      numbers.className = 'kl-number-buttons';
      numbers.setAttribute('role', 'group');
      numbers.setAttribute('aria-label', 'Stiche');
      const verdict = document.createElement('div');
      verdict.className = 'kl-verdict-buttons';
      verdict.setAttribute('role', 'group');
      verdict.setAttribute('aria-label', 'Ansage richtig');
      function update() {
        bid.value = String(state.number);
        actual.value = String(state.correct ? state.number : state.number === 0 ? 1 : 0);
        numbers.querySelectorAll('button').forEach(button => button.setAttribute('aria-pressed', String(Number(button.textContent) === state.number)));
        verdict.querySelectorAll('button').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.correct === String(state.correct))));
        const preview = document.getElementById('klPreview-' + id);
        if (preview)
          preview.textContent = state.correct === null ? '\u2014' : '+' + (state.correct ? 5 + state.number : 0);
      }
      for (let n = 0; n <= max; n++) {
        const b = document.createElement('button');
        b.type = 'button';
        b.textContent = String(n);
        b.onclick = () => {
          state.number = n;
          update();
        };
        numbers.append(b);
      }
      for (const [value, text] of [
          [
            true,
            'Richtig'
          ],
          [
            false,
            'Falsch'
          ]
        ]) {
        const b = document.createElement('button');
        b.type = 'button';
        b.textContent = text;
        b.dataset.correct = String(value);
        b.onclick = () => {
          state.correct = value;
          update();
        };
        verdict.append(b);
      }
      box.append(numbers, verdict);
      row.append(box);
      update();
    }
  }
  function klResults(sheet, session) {
    const key = String(session) + ':' + sheet.rounds.length + ':' + sheet.players.join(',');
    const states = drafts.get(key);
    return sheet.players.map(id => {
      const state = states?.get(id);
      if (!state || state.correct === null)
        throw Error('Bitte für jeden Spieler Richtig oder Falsch wählen.');
      return {
        id,
        bid: state.number,
        correct: state.correct,
        points: state.correct ? 5 + state.number : 0
      };
    });
  }
  window.HHScoreEntry = {
    decorateSchniffel,
    decorateKlopfer,
    klMaximum,
    klResults,
    clear() {
      drafts.clear();
      document.getElementById('snCellDialog')?.close();
    }
  };
})();
