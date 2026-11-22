/* A TV opens a separate, revocable, read-only viewer. No phone mirroring or
   TV firmware control is implied; native Multi View stays on the TV remote. */
(() => {
  'use strict';
  let context = null, current = null, busy = false;
  async function show() {
    if (!context || busy)
      return;
    let d = document.getElementById('hhTVShare');
    if (!d) {
      d = document.createElement('dialog');
      d.id = 'hhTVShare';
      d.className = 'hh-confirm-dialog';
      document.body.append(d);
    }
    const target = context.target();
    d.replaceChildren();
    const h = document.createElement('h2');
    h.textContent = 'Ergebnisse am Fernseher';
    const p = document.createElement('p');
    p.className = 'small muted';
    p.textContent = 'TV-Link im Browser des Fernsehers oder eines angeschlossenen Geräts öffnen. Die Live-Ansicht läuft unabhängig vom Handy. Bildschirmteilung und Rückkehr zum Fernsehprogramm stellst du am TV ein. Eine Bildschirmspiegelung zeigt hingegen auch andere Handy-Apps.';
    const area = document.createElement('div');
    d.append(h, p, area);
    const button = (text, action, cls = 'ghost hh-wide-button') => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = cls;
      b.textContent = text;
      b.onclick = () => action().catch(context.fail);
      return b;
    };
    async function stop() {
      if (!current)
        return;
      if (!await context.confirm('TV-Freigabe beenden?', 'Dieser TV-Link wird gesperrt. Andere Zuschauer-QR-Codes bleiben gültig. Die TV-Bildschirmteilung beendest du mit der Fernbedienung.'))
        return;
      const r = await context.client().rpc('hh_tv_control', {
        p_action: 'stop',
        p_target: current.id
      });
      if (r.error)
        throw r.error;
      current = null;
      await renderLink();
    }
    async function renderLink() {
      area.replaceChildren();
      if (!current || current.target !== target.id || current.kind !== target.kind || !current.token) {
        const create = button('TV-Link erstellen', async () => {
          if (busy)
            return;
          busy = true;
          create.disabled = true;
          try {
            const owner = context.user();
            const r = await context.client().rpc('hh_tv_control', {
              p_action: 'create',
              p_target: target.id,
              p_kind: target.kind
            });
            if (r.error)
              throw r.error;
            if (!d.open || owner !== context.user())
              return;
            current = {
              ...r.data,
              target: target.id,
              kind: target.kind
            };
            await renderLink();
          } finally {
            busy = false;
            create.disabled = false;
          }
        }, 'primary hh-wide-button');
        if (current?.id) {
          const note = document.createElement('p');
          note.textContent = 'Eine TV-Freigabe ist aktiv. Ein neuer Link beendet die bisherige Freigabe.';
          area.append(note, button('TV-Freigabe beenden', stop));
        }
        area.append(create);
        return;
      }
      const url = new URL('tv.html', location.href);
      url.hash = new URLSearchParams({
        session: current.id,
        code: current.token
      });
      const label = document.createElement('label');
      label.textContent = 'Nur für Zuschauer \xB7 kein Eintragen';
      const input = document.createElement('input');
      input.readOnly = true;
      input.value = url.href;
      input.setAttribute('aria-label', 'TV-Zuschauerlink');
      label.append(input);
      const expiry = document.createElement('p');
      expiry.className = 'small muted';
      expiry.textContent = 'Gültig bis ' + new Date(current.expires_at).toLocaleString('de-DE') + '. Namen und Bilder folgen den vorhandenen Zuschauerfreigaben.';
      area.append(label, expiry, button('Link teilen', async () => {
        if (navigator.share) {
          try {
            await navigator.share({
              title: 'Kartabend Live-Spielstand',
              url: url.href
            });
            return;
          } catch (error) {
            if (error.name === 'AbortError')
              return;
          }
        }
        if (navigator.clipboard?.writeText) {
          await navigator.clipboard.writeText(url.href);
        } else {
          input.focus();
          input.select();
        }
      }), button('TV-Ansicht öffnen', async () => {
        window.open(url.href, '_blank', 'noopener');
      }), button('TV-Freigabe beenden', stop));
    }
    if (!target.id)
      area.textContent = 'Bitte zuerst einen Raum oder Turniertisch öffnen.';
    else if (!target.owner)
      area.textContent = 'Nur der Raum- beziehungsweise Turnierersteller kann einen TV-Link freigeben.';
    else {
      if (!current || current.target !== target.id || current.kind !== target.kind) {
        const state = await context.client().rpc('hh_tv_control', {
          p_action: 'status',
          p_target: target.id,
          p_kind: target.kind
        });
        if (state.error)
          throw state.error;
        current = state.data ? {
          ...state.data,
          target: target.id,
          kind: target.kind
        } : null;
      }
      await renderLink();
    }
    d.append(button('Schließen', async () => d.close()));
    if (!d.open)
      d.showModal();
  }
  function decorate() {
    const target = context?.target();
    let b = document.getElementById('hhResultShare');
    if (!target?.id) {
      b?.remove();
      return;
    }
    if (!b) {
      b = document.createElement('button');
      b.id = 'hhResultShare';
      b.type = 'button';
      b.className = 'ghost hh-result-share';
      b.textContent = 'Teilen';
      b.setAttribute('aria-label', 'Live-Ergebnisse am Fernseher teilen');
      b.onclick = () => show().catch(context.fail);
    }
    const heading = document.querySelector('.tt-schaf-heading') || document.querySelector('.club-header');
    if (heading)
      heading.append(b);
  }
  window.HHTVShare = {
    bind(value) {
      context = value;
    },
    decorate,
    clear() {
      current = null;
      document.getElementById('hhTVShare')?.close();
      document.getElementById('hhResultShare')?.remove();
    }
  };
})();
