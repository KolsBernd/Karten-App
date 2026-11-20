/* Shared, accessible feedback for the app and the restricted QR capture page.
 * All text goes through textContent. Cancellation never executes a mutation. */
(() => {
  'use strict';
  let dialogPending = false;
  function dialog(title, message, confirm) {
    if (dialogPending) return Promise.resolve(false);
    dialogPending = true;
    return new Promise(resolve => {
      const box = document.createElement('dialog');
      box.className = 'hh-confirm-dialog hh-action-dialog';
      box.setAttribute('aria-label', title);
      const heading = document.createElement('h2');
      heading.textContent = title;
      const copy = document.createElement('p');
      copy.textContent = message;
      const actions = document.createElement('div');
      actions.className = 'hh-dialog-actions';
      const finish = value => { box.close(); box.remove(); dialogPending = false; resolve(value); };
      for (const [label, value] of confirm ? [['Nein', false], ['Ja', true]] : [['Verstanden', true]]) {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = label;
        button.className = value && confirm ? 'primary' : 'ghost';
        button.onclick = () => finish(value);
        actions.append(button);
      }
      box.append(heading, copy, actions);
      box.oncancel = event => { event.preventDefault(); finish(false); };
      document.body.append(box);
      box.showModal();
      actions.firstElementChild.focus();
    });
  }
  window.HHDialogs = {
    confirm: (title, text) => window.hhAppConfirm ? window.hhAppConfirm(title, text) : dialog(title, text, true),
    notice: (title, text) => dialog(title, text, false)
  };
  // Reuse the navigation's visual language; no external images or icon service.
  window.HHRoomIcons = {
    create(kind) {
      const source = kind === 'tournament' ? document.querySelector('#hhNavTournaments svg')
        : kind === 'game' ? document.querySelector('button[aria-label="Spiel"] svg') : null;
      if (source) {
        const icon = source.cloneNode(true);
        icon.classList.add('hh-room-kind');
        icon.setAttribute('aria-hidden', 'true');
        return icon;
      }
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 24 24');
      svg.setAttribute('class', 'hh-room-kind');
      svg.setAttribute('fill', 'none');
      svg.setAttribute('stroke', 'currentColor');
      svg.setAttribute('stroke-width', '1.8');
      svg.setAttribute('aria-hidden', 'true');
      // The question mark identifies a request even without colour perception.
      svg.innerHTML = '<circle cx="12" cy="12" r="9"/><path d="M9.5 8.5a2.5 2.5 0 0 1 5 0c0 2-2.5 2-2.5 4.5"/><circle cx="12" cy="16.5" r=".7" fill="currentColor" stroke="none"/>';
      return svg;
    }
  };
  window.dispatchEvent(new Event('hh-ui-ready'));
})();
