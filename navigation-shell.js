/* Navigation belongs to the viewport. Lobby and tournament controls can be
 * created after DOMContentLoaded or replaced by a subsequent account render. */
(() => {
  'use strict';
  function mount() {
    let host;
    function sync() {
      if (typeof document === 'undefined' || !document.body) return;
      const gate = document.getElementById('hhGate');
      const panel = gate?.querySelector('.hh-auth-panel');
      const lobby = document.getElementById('hhLobbyNav');
      const room = document.querySelector('.bottom-nav');
      const tournament = document.getElementById('hhTournamentPlayNav');
      if (!gate || !panel) return;
      if (lobby && !host) {
        host = document.createElement('div');
        host.id = 'hhNavigationHost';
        host.className = 'hh-auth-panel';
        document.body.append(host);
      }
      if (lobby && lobby.parentElement !== host) host.append(lobby);
      for (const nav of [room, tournament])
        if (nav && nav.parentElement !== document.body) document.body.append(nav);
      const opened = !gate.classList.contains('hide');
      const inLobby = opened && panel.classList.contains('hh-lobby');
      const inTournament = document.body.classList.contains('hh-tournament-playing');
      const hide = (node, value) => { if (node && node.hidden !== value) node.hidden = value; };
      hide(host, !inLobby);
      hide(room, opened || inTournament);
      hide(tournament, opened || !inTournament);
      gate.setAttribute('aria-modal', String(!inLobby));
    }
    // Reconcile late-created/replaced menus as well as navigation transitions.
    // Idempotent moves avoid observer loops while results and chats rerender.
    new MutationObserver(sync).observe(document.body, {
      childList: true, subtree: true, attributes: true, attributeFilter: ['class']
    });
    sync();
  }
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', mount, { once: true });
  else mount();
})();
