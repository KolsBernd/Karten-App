/* Profile and room statistics. Pure score calculations and DOM rendering use an explicit state adapter; no authentication or room mutations happen here.
 * Live getters keep room revisions, identity and rendering in sync with the entry point.
 */
(() => {
  'use strict';
  function create(c) {
    function recordsForRoom(r) {
      const rows = [];
      for (const session of r.payload?.sessions || []) {
        for (const game of session.games || [])
          if ([
              'Bierkopf',
              'Schleifer'
            ].includes(game.gameType || 'Bierkopf'))
            rows.push({
              type: game.gameType || 'Bierkopf',
              game
            });
        for (const sheet of session.snHistory || [])
          if (sheet.closed)
            rows.push({
              type: 'Schniffelkopf',
              sheet
            });
        for (const kl of session.klHistory || [])
          if (kl.closed)
            rows.push({
              type: 'Klopfer',
              kl
            });
      }
      return rows;
    }
    function roomPlayerStats(r, since = null) {
      const stats = new Map();
      const people = r.payload?.people || [];
      for (const record of recordsForRoom(r).filter(record => !since || new Date(record.game?.date || record.sheet?.date || record.kl?.date || 0) > new Date(since))) {
        let results = [];
        if (record.game) {
          const game = record.game;
          for (let side = 0; side < 2; side++)
            for (const id of new Set(game.members?.[side] || []))
              results.push({
                id,
                won: game.winner === side,
                points: Number(game.scores?.[side] || 0),
                netPoints: Number(game.scores?.[side] || 0) - Number(game.scores?.[1 - side] || 0)
              });
        } else {
          const scores = record.sheet ? c.snResults(record.sheet).scores : c.klTotals(record.kl);
          const maximum = scores.length ? Math.max(...scores.map(x => x.points)) : null;
          results = scores.map(x => ({
            ...x,
            won: x.points === maximum
          }));
        }
        for (const result of results) {
          const id = String(result.id);
          let player = stats.get(id);
          if (!player) {
            const person = people.find(p => String(p.id) === id);
            player = {
              id,
              name: person?.name || 'Unbekannter Spieler',
              authUserId: person?.authUserId || null,
              games: 0,
              wins: 0,
              byGame: {}
            };
            stats.set(id, player);
          }
          player.games++;
          player.wins += Number(result.won);
          const g = player.byGame[record.type] ??= {
            games: 0,
            wins: 0,
            points: 0,
            netPoints: [
              'Bierkopf',
              'Schleifer'
            ].includes(record.type) ? 0 : null
          };
          g.games++;
          g.wins += Number(result.won);
          g.points += Number(result.points) || 0;
          if (g.netPoints !== null)
            g.netPoints += Number(result.netPoints) || 0;
        }
      }
      return [...stats.values()];
    }
    function statTiles(items) {
      return '<div class="hh-stat-tiles">' + items.map(([value, label]) => '<div><strong>' + c.esc(value) + '</strong><small>' + c.esc(label) + '</small></div>').join('') + '</div>';
    }
    function renderLobbyStatistics() {
      if (!c.user)
        return;
      const mine = c.rooms.filter(r => r.is_member !== false && r.payload).map(r => r.id === c.room ? {
        ...r,
        payload: c.snapshot()
      } : r);
      const holder = c.$('hhRoomStatistics');
      holder.replaceChildren();
      for (const r of mine.filter(r => r.id === c.room)) {
        const records = recordsForRoom(r), players = roomPlayerStats(r), maxWins = Math.max(0, ...players.map(p => p.wins));
        const leaders = maxWins ? players.filter(p => p.wins === maxWins).map(p => p.name).join(' & ') : 'Noch keine abgeschlossene Partie';
        const panel = document.createElement('article');
        panel.className = 'hh-stats-panel';
        panel.id = 'hhStatsRoom-' + r.id;
        const totals = c.GAME_TYPES.map(type => [
          type,
          records.filter(x => x.type === type).length
        ]);
        let rows = '';
        for (const [type, count] of totals) {
          const timing = (r.game_times || []).find(x => x.game_type === type);
          rows += '<tr><th scope="row">' + c.esc(type) + '</th><td>' + count + '</td><td>' + c.esc(timing ? c.durationLabel(timing.seconds) : '\u2013') + '</td></tr>';
        }
        const untracked = (r.game_times || []).find(x => x.game_type === 'Nicht erfasst');
        panel.innerHTML = '<h3>' + c.esc(r.title) + '</h3><p class="small muted">' + c.esc(c.elapsedRoom(r)) + ' \xB7 Aktuell: ' + c.esc(c.roomSummary(r).type) + '</p>' + statTiles([
          [
            records.length,
            'Partien'
          ],
          [
            r.members?.length || 0,
            'Mitglieder'
          ]
        ]) + '<p class="hh-leader"><strong>Meiste Siege:</strong> ' + c.esc(leaders) + (maxWins ? ' \xB7 ' + maxWins + ' Siege' : '') + '</p><div class="hh-table-scroll"><table class="hh-stat-table"><thead><tr><th>Spielart</th><th>Partien</th><th>Ausgewählt für</th></tr></thead><tbody>' + rows + '</tbody></table></div><p class="small muted">Spielartzeiten enthalten Pausen.' + (untracked ? ' Historische Zeit vor Einführung der Messung: ' + c.esc(c.durationLabel(untracked.seconds)) + '; keiner Spielart zugeordnet.' : '') + '</p>';
        const perGame = document.createElement('div');
        perGame.className = 'hh-best-players';
        perGame.innerHTML = '<h3>Beste Spieler je Spielart</h3>' + c.statsTable([
          'Spielart',
          'Spieler',
          'Partien',
          'Siege',
          'Quote'
        ], c.GAME_TYPES.map(type => {
          const contenders = players.filter(p => p.byGame[type]?.games);
          const best = Math.max(0, ...contenders.map(p => p.byGame[type].wins));
          const leaders = contenders.filter(p => p.byGame[type].wins === best && best > 0);
          return [
            type,
            leaders.length ? leaders.map(p => p.name).join(' & ') : 'Noch keine Siege',
            leaders.map(p => p.byGame[type].games).join(' / ') || '\u2013',
            best,
            leaders.map(p => Math.round(100 * p.byGame[type].wins / p.byGame[type].games) + ' %').join(' / ') || '\u2013'
          ];
        }));
        panel.append(perGame);
        holder.append(panel);
      }
      const profileHolder = c.$('hhPersonalStatistics');
      const byGame = Object.fromEntries([
        ...c.GAME_TYPES,
        'Schafkopf'
      ].map(type => [
        type,
        {
          games: 0,
          wins: 0,
          points: 0,
          netPoints: [
            'Bierkopf',
            'Schleifer'
          ].includes(type) ? 0 : null
        }
      ]));
      let ownPlayed = 0, ownWins = 0;
      for (const r of mine)
        for (const p of roomPlayerStats(r, c.personalStatsSince))
          if (p.authUserId === c.user.id) {
            ownPlayed += p.games;
            ownWins += p.wins;
            for (const [type, value] of Object.entries(p.byGame)) {
              byGame[type].games += value.games;
              byGame[type].wins += value.wins;
              byGame[type].points += value.points;
              if (byGame[type].netPoints !== null)
                byGame[type].netPoints += value.netPoints || 0;
            }
          }
      for (const result of c.savedPersonalStats) {
        const g = byGame[result.type];
        if (!g)
          continue;
        g.games++;
        g.wins += Number(result.won);
        g.points += Number(result.points) || 0;
        if (result.points === null)
          g.pointsIncomplete = true;
        if (g.netPoints !== null) {
          g.netPoints += Number(result.net_points) || 0;
          if (result.net_points === null)
            g.netIncomplete = true;
        }
        ownPlayed++;
        ownWins += Number(result.won);
      }
      renderProfileMetrics(byGame, ownPlayed, ownWins);
      profileHolder.innerHTML = statTiles([
        [
          new Set([
            ...mine.map(r => r.id),
            ...c.savedPersonalStats.map(r => r.source_room)
          ]).size,
          'Abende / Turniere'
        ],
        [
          c.socialState?.friendships?.length || 0,
          'Freunde'
        ]
      ]) + tableMarkup(byGame);
      c.$('hhPersonalSince').textContent = c.personalStatsSince ? 'Deine Statistik zählt seit ' + new Date(c.personalStatsSince).toLocaleString('de-DE') + '. Raumstatistiken bleiben unverändert.' : '';
      const identity = c.$('hhProfileIdentity');
      identity.replaceChildren();
      identity.append(c.avatarElement({
        username: c.profile?.username,
        avatar: c.profile?.avatar
      }, false));
      const name = document.createElement('strong');
      name.textContent = [
        c.account?.first_name,
        c.account?.last_name
      ].filter(Boolean).join(' ') || c.profile?.username || 'Dein Profil';
      const username = document.createElement('small');
      username.textContent = '@' + (c.profile?.username || '');
      identity.append(name, username);
    }
    function tableMarkup(byGame) {
      const types = Object.keys(byGame), total = types.reduce((sum, type) => {
          const g = byGame[type];
          sum.games += g.games;
          sum.wins += g.wins;
          sum.points += g.points;
          sum.netPoints += g.netPoints || 0;
          sum.pointsIncomplete ||= g.pointsIncomplete;
          sum.netIncomplete ||= g.netIncomplete;
          return sum;
        }, {
          games: 0,
          wins: 0,
          points: 0,
          netPoints: 0
        });
      const cells = g => '<td>' + g.games + '</td><td>' + g.wins + '</td><td>' + (g.games ? Math.round(100 * g.wins / g.games) + ' %' : '\u2013') + '</td><td>' + g.points + (g.pointsIncomplete ? ' + ?' : '') + '</td><td>' + (g.netPoints === null ? '\u2013' : g.netPoints + (g.netIncomplete ? ' + ?' : '')) + '</td>';
      return '<div class="hh-table-scroll"><table class="hh-stat-table"><thead><tr><th>Spielart</th><th>Partien</th><th>Siege</th><th>Quote</th><th>Punkte</th><th>Nettopunkte</th></tr></thead><tbody>' + types.map(type => '<tr><th scope="row">' + c.esc(type) + '</th>' + cells(byGame[type]) + '</tr>').join('') + '</tbody><tfoot><tr><th scope="row">Gesamt</th>' + cells(total) + '</tr></tfoot></table></div><p class="small muted">Punkte zählen auch bei Niederlagen. Nettopunkte gelten nur für Bierkopf und Schleifer: eigene Punkte minus Gegnerpunkte.</p>';
    }
    function renderProfileMetrics(byGame, ownPlayed, ownWins) {
      const selected = c.$('hhProfileGame').value;
      const g = selected === 'all' ? Object.values(byGame).reduce((a, g) => ({
        games: a.games + g.games,
        wins: a.wins + g.wins,
        points: a.points + g.points,
        netPoints: a.netPoints + (g.netPoints || 0),
        pointsIncomplete: a.pointsIncomplete || g.pointsIncomplete,
        netIncomplete: a.netIncomplete || g.netIncomplete
      }), {
        games: 0,
        wins: 0,
        points: 0,
        netPoints: 0
      }) : byGame[selected] || {
        games: 0,
        wins: 0,
        points: 0
      };
      const icons = [
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M7 3h10v6a5 5 0 0 1-10 0zM7 5H3v2a4 4 0 0 0 4 4m10-6h4v2a4 4 0 0 1-4 4M12 14v6M7 21h10"/></svg>',
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="14" width="4" height="7"/><rect x="10" y="3" width="4" height="18"/><rect x="17" y="8" width="4" height="13"/></svg>',
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m12 2 3 6 7 1-5 5 1 8-6-4-6 4 1-8-5-5 7-1z"/></svg>'
      ];
      const metrics = [
        [
          g.games,
          'Partien'
        ],
        [
          g.games ? Math.round(g.wins / g.games * 100) + ' %' : '\u2013',
          'Siegquote'
        ],
        [
          g.points + (g.pointsIncomplete ? ' + ?' : ''),
          'Punkte'
        ],
        [
          g.netPoints === null ? '\u2013' : g.netPoints + (g.netIncomplete ? ' + ?' : ''),
          'Nettopunkte'
        ]
      ];
      c.$('hhProfileMetrics').innerHTML = metrics.map(([value, label], i) => '<div>' + icons[i % icons.length] + '<strong>' + c.esc(value) + '</strong><small>' + c.esc(label) + '</small></div>').join('');
    }
    let friendRequest = 0;
    async function openFriend(person) {
      const request = ++friendRequest, identity = c.user?.id;
      let dialog = document.getElementById('hhFriendProfileDialog');
      if (!dialog) { dialog=document.createElement('dialog');dialog.id='hhFriendProfileDialog';dialog.className='hh-confirm-dialog hh-friend-profile';document.body.append(dialog); }
      const heading=document.createElement('h2'), body=document.createElement('div'), close=document.createElement('button');
      heading.textContent='Profilstatistik';body.textContent='Statistik wird geladen …';close.type='button';close.className='ghost hh-wide-button';close.textContent='Schließen';close.onclick=()=>dialog.close();
      dialog.replaceChildren(heading,body,close);dialog.onclose=()=>{friendRequest++;dialog.replaceChildren()};if(!dialog.open)dialog.showModal();
      const result=await c.client.rpc('hh_friend_profile_statistics',{p_user:person.user_id});
      if(request!==friendRequest||identity!==c.user?.id||!dialog.open)return;
      if(result.error){body.textContent='Diese Profilstatistik ist derzeit nicht verfügbar.';throw result.error}
      const data=result.data;heading.textContent=data.username+' · Profilstatistik';body.replaceChildren(c.avatarElement({username:data.username,avatar:data.avatar},false));
      const table=document.createElement('div');table.innerHTML=tableMarkup(data.by_game||{});body.append(table);
    }
    return {
      clear(){friendRequest++;const dialog=document.getElementById('hhFriendProfileDialog');if(dialog?.open)dialog.close();dialog?.replaceChildren()},
      openFriend,
      tableMarkup,
      recordsForRoom,
      roomPlayerStats,
      statTiles,
      renderLobbyStatistics,
      renderProfileMetrics
    };
  }
  window.HHProfileStatistics = { create };
})();
