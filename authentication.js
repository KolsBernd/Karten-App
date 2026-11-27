/* Authentication and verified session startup. Credentials are sent only to the existing login service; this module never persists them.
 * Live getters keep room revisions, identity and rendering in sync with the entry point.
 */
(() => {
  'use strict';
  function create(c) {
    async function login() {
      if (!c.client)
        throw Error('Der Anmeldedienst konnte nicht geladen werden. Bitte die App neu laden und die Internetverbindung prüfen.');
      const username = c.validUsername(c.$('hhUsername').value), password = c.$('hhPassword').value;
      if (!password)
        throw Error('Bitte Passwort eingeben.');
      const {
        data: tokens,
        error
      } = await c.client.functions.invoke('username-login', {
        body: {
          username,
          password
        }
      });
      c.$('hhPassword').value = '';
      if (error) {
        let message = 'Anmeldung fehlgeschlagen. Bitte Benutzername und Passwort prüfen.';
        try {
          const response = await error.context.json();
          if (typeof response.error === 'string')
            message = response.error;
        } catch {
        }
        throw Error(message);
      }
      if (!tokens?.access_token || !tokens?.refresh_token)
        throw Error('Anmeldung fehlgeschlagen.');
      const result = await c.client.auth.setSession(tokens);
      if (result.error)
        throw result.error;
      await signedIn();
    }
    async function register() {
      const username = c.validUsername(c.$('hhRegisterUsername').value), details = c.contactFields('hhRegister');
      const email = c.$('hhRegisterEmail').value.trim(), password = c.validPassword(c.$('hhRegisterPassword').value);
      if (!email || !c.$('hhRegisterEmail').checkValidity())
        throw Error('Bitte eine gültige E-Mail-Adresse angeben.');
      const available = await c.client.rpc('hh_username_available', { p_username: username });
      if (available.error)
        throw available.error;
      if (!available.data) {
        await window.HHNotice('Benutzername bereits vorhanden', 'Dieser Benutzername existiert bereits. Bitte wähle einen anderen.');
        return;
      }
      const {error} = await c.client.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: location.origin + location.pathname,
          data: {
            requested_username: username,
            requested_display_username: c.$('hhRegisterUsername').value.trim(),
            requested_first: details.first,
            requested_last: details.last,
            requested_gender: c.$('hhRegisterGender').value,
            requested_locality: c.$('hhRegisterLocality').value.trim(),
            requested_phone: details.phone,
            requested_consent: details.consent,
            requested_phone_purpose: 'kartabend-contact-v1'
          }
        }
      });
      c.$('hhRegisterPassword').value = '';
      if (error) {
        const check = await c.client.rpc('hh_username_available', { p_username: username });
        if (check.data === false) {
          await window.HHNotice('Benutzername bereits vorhanden', 'Dieser Benutzername existiert bereits. Bitte wähle einen anderen.');
          return;
        }
        throw error;
      }
      c.status('Bitte bestätige deine E-Mail und öffne die App danach erneut. Falls dein Konto bereits besteht, nutze die Wiederherstellung.');
    }
    async function recover() {
      const email = c.$('hhRecoveryEmail').value.trim();
      if (!email)
        throw Error('Bitte E-Mail eingeben.');
      const {error} = await c.client.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname });
      if (error)
        throw error;
      c.status('Falls ein passendes Konto besteht, erhältst du eine E-Mail zur Wiederherstellung.');
    }
    async function signedIn() {
      const result = await c.client.auth.getUser();
      if (result.error)
        throw result.error;
      c.user = result.data.user;
      if (!c.user) {
        c.setupState();
        return;
      }
      window.HHErrorLog?.flush();
      c.hiddenMessages = new Set();
      c.lastHiddenMessage = null;
      c.revealedMessageKey = null;
      c.$('hhMessageUndo').classList.add('hide');
      const own = await c.client.from('hh_profiles').select('username,nickname,avatar').eq('user_id', c.user.id).maybeSingle();
      if (own.error)
        throw own.error;
      c.profile = own.data;
      const names = await c.client.rpc('hh_display_names');
      if (names.error)
        throw names.error;
      c.displayNames = names.data || {};
      c.profile = c.displayData(c.profile);
      const pending = await c.client.rpc('hh_pending_phone');
      if (pending.error)
        throw pending.error;
      c.pendingPhone = pending.data || '';
      const details = await c.client.rpc('hh_my_account');
      if (details.error)
        throw details.error;
      c.account = details.data;
      const cutoff = await c.client.rpc('hh_personal_statistics_since');
      if (cutoff.error)
        throw cutoff.error;
      c.personalStatsSince = cutoff.data || null;
      if (!c.profile || !c.account || c.recovering || c.account.phone_requires_choice) {
        if (c.account?.phone_requires_choice)
          c.editingAccount = true;
        await c.fillAccount();
        c.setupState();
        c.gate(true);
        c.status(c.account?.phone_requires_choice ? 'Bitte entscheide neu über deine freiwillige Telefonnummer: Erlaubnis für persönliche Rückfragen bestätigen oder die Nummer entfernen.' : c.recovering ? 'Bitte ein neues Passwort festlegen.' : 'Bitte dein Profil vervollständigen. Nur dein Benutzername und Profilbild sind für andere Raummitglieder sichtbar.');
        return;
      }
      c.roomArchive = false;
      c.roomCategory = 'active';
      c.$('hhRequestRooms').setAttribute('aria-pressed', 'false');
      c.$('hhActiveRooms').setAttribute('aria-pressed', 'true');
      c.$('hhArchivedRooms').setAttribute('aria-pressed', 'false');
      c.setLobbyPage('rooms');
      if (c.room) {
        await c.leaveView();
      } else {
        await c.startLobby();
        c.gate(true);
        c.status('Wähle deinen Kartabend oder erstelle mit + einen neuen.');
      }
      if (sessionStorage.getItem('hh_pending_view') === 'notifications') {
        sessionStorage.removeItem('hh_pending_view');
        c.setLobbyPage('notifications');
      }
      if (localStorage.getItem('hh_pending_table_invite') || localStorage.getItem('hh_pending_table')) {
        try {
          if (await c.acceptTournamentLink())
            return;
        } catch (e) {
          c.fail(e);
        }
      }
      if (localStorage.getItem('hh_pending_invite')) {
        try {
          await c.acceptInvitation();
        } catch (e) {
          c.setupState();
          c.fail(e);
        }
      }
    }
    return {
      login,
      register,
      recover,
      signedIn
    };
  }
  window.HHAuthentication = { create };
})();
