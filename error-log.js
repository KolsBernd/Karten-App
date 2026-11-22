/* Privacy-preserving diagnostics: fixed codes, counts and timestamps only.
 * The queue survives offline use for seven days. A random batch ID makes retries
 * idempotent; neither raw error text nor account/room identifiers enter storage.
 */
(() => {
  'use strict';
  const KEY = 'hh_error_queue_v1', TTL = 7 * 86400000, BUILD = '40.0';
  const CODES = new Set([
    'NETWORK',
    'JS_TYPE',
    'JS_REFERENCE',
    'JS_ERROR',
    'RESOURCE_LOAD',
    'AUTH_FAILED',
    'VALIDATION',
    'RPC_RULE',
    '23505',
    '23503',
    '42501',
    '40001',
    'PGRST202',
    'PGRST301'
  ]);
  const seen = new WeakSet();
  let client = null, identity = () => null, timer = null, sending = false, queue = [], reportRequest = 0;
  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify(queue));
    } catch {
    }
  }
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) || '[]');
    if (Array.isArray(saved))
      queue = saved.filter(x => CODES.has(x.code) && [
        'ui',
        'global',
        'resource'
      ].includes(x.source) && /^\d{1,3}\.\d{1,3}$/.test(x.build) && /^[0-9a-f-]{36}$/.test(x.id) && Number.isInteger(x.count) && x.count > 0 && x.count <= 500 && Number.isFinite(Date.parse(x.first)) && Number.isFinite(Date.parse(x.last)) && Date.parse(x.last) > Date.now() - TTL).slice(-20).map(x => ({
        id: x.id,
        code: x.code,
        source: x.source,
        build: x.build,
        count: x.count,
        first: x.first,
        last: x.last,
        sealed: true
      }));
  } catch {
    queue = [];
  }
  function classify(error) {
    if (CODES.has(String(error?.code)))
      return String(error.code);
    if (error?.name === 'TypeError')
      return /fetch|network|load failed/i.test(error.message || '') ? 'NETWORK' : 'JS_TYPE';
    if (error?.name === 'ReferenceError')
      return 'JS_REFERENCE';
    if (/network|fetch|offline|timeout/i.test(error?.message || ''))
      return 'NETWORK';
    if (/invalid_credentials|invalid_grant/i.test(error?.code || ''))
      return 'AUTH_FAILED';
    if (error?.code === 'P0001')
      return 'RPC_RULE';
    return 'JS_ERROR';
  }
  function record(error, source = 'ui') {
    if (error && typeof error === 'object') {
      if (seen.has(error))
        return;
      seen.add(error);
    }
    if (![
        'ui',
        'global',
        'resource'
      ].includes(source))
      source = 'ui';
    const code = source === 'resource' ? 'RESOURCE_LOAD' : classify(error), now = new Date().toISOString();
    queue = queue.filter(x => Date.parse(x.last) > Date.now() - TTL);
    const row = queue.find(x => !x.sealed && x.code === code && x.source === source && x.build === BUILD && x.count < 500);
    if (row) {
      row.count++;
      row.last = now;
    } else if (queue.length < 20 && crypto.randomUUID)
      queue.push({
        id: crypto.randomUUID(),
        code,
        source,
        build: BUILD,
        count: 1,
        first: now,
        last: now,
        sealed: false
      });
    save();
    schedule();
  }
  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(flush, 2000);
  }
  async function flush() {
    if (sending || !client || !identity()?.id || navigator.onLine === false)
      return;
    queue = queue.filter(x => Date.parse(x.first) > Date.now() - TTL);
    save();
    sending = true;
    try {
      for (const row of [...queue]) {
        if (!identity()?.id)
          break;
        row.sealed = true;
        save();
        const result = await client.rpc('hh_record_error', {
          p_batch: row.id,
          p_code: row.code,
          p_source: row.source,
          p_build: row.build,
          p_count: row.count,
          p_first: row.first,
          p_last: row.last
        });
        if (result.error || result.data === false)
          break;
        queue = queue.filter(x => x.id !== row.id);
        save();
      }
    } catch {
    } finally {
      sending = false;
      if (queue.length && identity()?.id) {
        clearTimeout(timer);
        timer = setTimeout(flush, 60000);
      }
    }
  }
  async function openReport() {
    const request = ++reportRequest;
    let dialog = document.getElementById('hhErrorReport');
    if (!dialog) {
      dialog = document.createElement('dialog');
      dialog.id = 'hhErrorReport';
      dialog.className = 'hh-confirm-dialog hh-error-report';
      document.body.append(dialog);
    }
    const heading = document.createElement('h2'), body = document.createElement('div'), close = document.createElement('button');
    heading.textContent = 'Fehlerprotokoll';
    body.textContent = 'Wird geladen \u2026';
    close.type = 'button';
    close.className = 'ghost hh-wide-button';
    close.textContent = 'Schließen';
    close.onclick = () => dialog.close();
    dialog.replaceChildren(heading, body, close);
    if (!dialog.open)
      dialog.showModal();
    dialog.onclose=()=>{reportRequest++;dialog.replaceChildren()};
    const account = identity()?.id;
    try {
      await flush();
      const result = await client.rpc('hh_error_report');
      if (!dialog.open || identity()?.id !== account || request!==reportRequest)
        return;
      if (result.error)
        throw result.error;
      body.replaceChildren();
      const note = document.createElement('p');
      note.className = 'small muted';
      note.textContent = 'Letzte 30 Tage. Bereinigte Fehlercodes mit Anzahl und erstem/letztem Auftreten. Keine Fehlermeldungen oder persönlichen Inhalte.';
      body.append(note);
      const wrap = document.createElement('div');
      wrap.className = 'hh-table-scroll';
      const table = document.createElement('table');
      table.className = 'hh-stat-table';
      const head = table.createTHead().insertRow();
      for (const name of [
          'Code',
          'Bereich',
          'Version',
          'Häufigkeit',
          'Erstmals',
          'Zuletzt'
        ]) {
        const th = document.createElement('th');
        th.textContent = name;
        head.append(th);
      }
      const rows = table.createTBody();
      for (const row of result.data || []) {
        const tr = rows.insertRow();
        for (const value of [
            row.code,
            row.source,
            row.build,
            row.occurrences,
            new Date(row.first_seen).toLocaleString('de-DE'),
            new Date(row.last_seen).toLocaleString('de-DE')
          ])
          tr.insertCell().textContent = String(value);
      }
      wrap.append(table);
      body.append(wrap);
      if (!rows.rows.length)
        body.append(document.createTextNode('Noch keine Fehler erfasst.'));
    } catch {
      if(!dialog.open||request!==reportRequest||identity()?.id!==account)return;
      body.textContent = 'Fehlerprotokoll nicht verfügbar. Nur Kolsbernd hat Zugriff.';
    }
  }
  addEventListener('error', event => record(event.error || {}, event.target !== window ? 'resource' : 'global'), true);
  addEventListener('unhandledrejection', event => record(event.reason, 'global'));
  addEventListener('online', schedule);
  window.HHErrorLog = {
    record,
    flush,
    openReport,
    clearReport(){reportRequest++;const dialog=document.getElementById('hhErrorReport');if(dialog?.open)dialog.close();dialog?.replaceChildren()},
    bind(service, getIdentity) {
      client = service;
      identity = getIdentity;
      schedule();
    }
  };
})();
