/* Room transitions and optimistic server revisions. The injected live state adapter preserves the existing single source of truth during gradual extraction.
 * Live getters keep room revisions, identity and rendering in sync with the entry point.
 */
(() => {
  'use strict';
  function create(c) {
    function adopt(value) {
      if (!value || !Array.isArray(value.people) || !Array.isArray(value.sessions) || !value.sessions.length)
        throw Error('Ungültiger Online-Datensatz');
      c.data = structuredClone(c.validateGameData(value));
      c.render();
    }
    async function fetchState(id = c.room) {
      const {
        data: rows,
        error
      } = await c.client.from('hh_states').select('payload,revision').eq('room_id', id).single();
      if (error)
        throw error;
      return rows;
    }
    async function loadRoom(id) {
      if (c.pending || c.dirty)
        throw Error('Bitte erst das Speichern abwarten.');
      const selected = c.rooms.find(r => r.id === id);
      if (selected?.ended_at) {
        c.showEndedRoom(selected);
        return;
      }
      if (selected?.is_member === false)
        throw Error('Bitte dem Kartabend zuerst per Einladung oder bestätigter Anfrage beitreten.');
      clearInterval(c.lobbyTimer);
      await c.client.rpc('hh_leave_lobby', { p_session: c.presenceSession });
      stopPresence();
      if (c.realtime) {
        await c.client.removeChannel(c.realtime);
        c.realtime = null;
      }
      c.room = null;
      c.rev = null;
      c.gate(true);
      c.setupState();
      const enteringUser = c.user?.id;
      const st = await fetchState(id);
      await c.ensureSharingChoice('room', id);
      if (c.user?.id !== enteringUser)
        return;
      c.room = id;
      c.admin = c.rooms.find(r => r.id === id)?.created_by === c.user.id;
      localStorage.setItem('hh_last_room', id);
      c.rev = Number(st.revision);
      c.committed = structuredClone(st.payload);
      adopt(st.payload);
      c.gate(false);
      c.setupState();
      c.renderLobbyStatistics();
      c.updateElapsed();
      c.status('Verbunden \xB7 Revision ' + c.rev);
      heartbeat();
      c.presenceTimer = setInterval(heartbeat, 25000);
      c.realtime = c.client.channel('hh-' + id).on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'hh_states',
        filter: 'room_id=eq.' + id
      }, async event => {
        if (c.room !== id || Number(event.new.revision) <= c.rev)
          return;
        if (c.pending || c.dirty) {
          c.status('Neue Änderungen vorhanden \u2013 Synchronisierung läuft \u2026');
          return;
        }
        try {
          const fresh = await fetchState();
          if (Number(fresh.revision) > c.rev) {
            c.rev = Number(fresh.revision);
            c.committed = structuredClone(fresh.payload);
            adopt(fresh.payload);
            c.status('Live aktualisiert \xB7 Revision ' + c.rev);
          }
        } catch (e) {
          c.fail(e);
        }
      }).subscribe();
    }
    async function flush() {
      if (c.pending || !c.dirty || !c.room)
        return;
      c.pending = true;
      c.dirty = false;
      const payload = c.snapshot();
      const expected = c.rev;
      c.status('Speichere \u2026');
      try {
        const {
          data: next,
          error
        } = await c.client.rpc('hh_update_state', {
          p_room: c.room,
          p_revision: expected,
          p_payload: payload
        });
        if (error)
          throw error;
        c.rev = Number(next);
        const confirmed = await fetchState();
        if (Number(confirmed.revision) >= c.rev) {
          c.rev = Number(confirmed.revision);
          c.committed = structuredClone(confirmed.payload);
          if (!c.dirty)
            adopt(confirmed.payload);
        }
        c.status('Gespeichert \xB7 Revision ' + c.rev);
        if (c.dirty)
          queueMicrotask(flush);
      } catch (e) {
        c.dirty = false;
        c.exportConflict(payload);
        try {
          const fresh = await fetchState();
          c.rev = Number(fresh.revision);
          c.committed = structuredClone(fresh.payload);
          adopt(fresh.payload);
        } catch (loadErr) {
          c.fail(loadErr);
          c.gate(true);
        }
        alert('Online-Speicherung fehlgeschlagen. Deine Änderungen wurden als JSON-Datei gesichert. Die aktuelle Serverversion wird angezeigt. Ursache: ' + (e.message || e));
        c.fail(e);
      } finally {
        c.pending = false;
        if (c.dirty)
          queueMicrotask(flush);
      }
    }
    async function heartbeat() {
      if (document.hidden)
        return;
      const id = c.room;
      if (!id)
        return;
      try {
        const {
          data: members,
          error
        } = await c.client.rpc('hh_ping_room', {
          p_room: id,
          p_session: c.presenceSession
        });
        if (error)
          throw error;
        if (c.room === id) {
          c.roomMembers = c.displayData(members || []);
          for (const button of document.querySelectorAll('.avatar-action[data-user-id]')) {
            const m = c.roomMembers.find(m => m.user_id === button.dataset.userId);
            let dot = button.querySelector('.hh-game-presence');
            if (m) {
              if (!dot) {
                dot = document.createElement('span');
                button.append(dot);
              }
              dot.className = 'hh-game-presence ' + (m.online ? 'online' : 'offline');
              dot.setAttribute('aria-label', m.online ? 'Online' : 'Offline');
            } else if (dot)
              dot.remove();
          }
          c.$('hhOnlineMembers').textContent = c.roomMembers.filter(m => m.online).map(m => m.username || m.nickname).join(' \xB7 ') || 'Keine aktiven Mitglieder';
          c.renderMembers();
        }
      } catch (e) {
        if (c.room === id) {
          c.$('hhOnlineMembers').textContent = 'Online-Status derzeit nicht verfügbar';
          if (String(e.message || '').includes('beendet')) {
            try {
              await c.refreshRooms();
              if (!c.pending && !c.dirty) {
                await c.leaveView();
                c.$('hhLobbyNotice').textContent = 'Der Kartabend wurde beendet und ist jetzt offline.';
                c.$('hhLobbyNotice').classList.remove('hide');
              }
            } catch (error) {
              c.fail(error);
            }
          }
        }
      }
    }
    function stopPresence() {
      clearInterval(c.presenceTimer);
      c.presenceTimer = null;
      c.roomMembers = [];
      c.$('hhOnlineMembers').textContent = 'Noch kein Raum geöffnet';
    }
    return {
      adopt,
      fetchState,
      loadRoom,
      flush,
      heartbeat,
      stopPresence
    };
  }
  window.HHRoomState = { create };
})();
