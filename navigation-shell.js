/* Navigation belongs to the viewport, outside scrollable panels. */
(() => {
  'use strict';
  function mount() {
    const gate = document.getElementById('hhGate'), panel = gate?.querySelector('.hh-auth-panel'), lobby = document.getElementById('hhLobbyNav'), room = document.querySelector('.bottom-nav'), tournament = document.getElementById('hhTournamentPlayNav');
    if (!gate || !panel || !lobby)
      return;
    const host = document.createElement('div');
    host.id = 'hhNavigationHost';
    host.className = 'hh-auth-panel';
    document.body.append(host);
    host.append(lobby);
    if (room)
      document.body.append(room);
    if (tournament)
      document.body.append(tournament);
    function sync() {
      const opened = !gate.classList.contains('hide'), inLobby = opened && panel.classList.contains('hh-lobby'), inTournament = document.body.classList.contains('hh-tournament-playing');
      host.hidden = !inLobby;
      if (room)
        room.hidden = opened || inTournament;
      if (tournament)
        tournament.hidden = opened || !inTournament;
      gate.setAttribute('aria-modal', String(!inLobby));
    }
    const observer = new MutationObserver(sync);
    observer.observe(gate, {
      attributes: true,
      attributeFilter: ['class']
    });
    observer.observe(panel, {
      attributes: true,
      attributeFilter: ['class']
    });
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ['class']
    });
    sync();
  }
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', mount, { once: true });
  else
    mount();
})();
