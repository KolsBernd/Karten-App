/* Experimental money-value calculator. All values use quarter-cents so the
 * documented Spitzen factors stay exact. No payments, network or persistence. */
(() => {
  "use strict";
  const games = [
    "King",
    "Wenz",
    "Geier",
    "Solo",
    "Sau",
    "Bagga",
    "Spitz",
    "Ramsch",
    "Kreuzspiel",
    "Bettel",
  ];
  const solo = ["King", "Wenz", "Geier", "Solo"];
  const descriptions = {
    King: "König ist Trumpf.",
    Wenz: "Wenz ist Trumpf.",
    Geier: "Geier ist Trumpf.",
    Solo: "Geier, Wenz und eine gewünschte Farbe sind Trumpf.",
    Sau: "Man spielt mit der angesagten Farbsau zusammen.",
    Bagga: "Einzelspiel: Nur einen Stich machen. Trümpfe wie bei Bierkopf.",
    Spitz: "Bettel, der sofort aufgelegt wird.",
    Ramsch:
      "Die wenigsten Augen gewinnen. Wer 120 Augen hat, gewinnt ebenfalls. Standardbetrag 0,10 €. Der Verlierer zahlt an alle anderen; bei 120 Augen zahlen alle an den ausgewählten Gewinner.",
    Tout: "Kein Stich darf herausgehen; bei Bagga und Bettel nach der ersten Karte auflegen. Tout zählt ×2, bei Bettel ×1,5. Schneider und Durch zählen nicht zusätzlich.",
    Light:
      "Bei King, Wenz, Geier oder Solo muss genau ein Stich herausgehen. Alternativ zu Tout. Light zählt ×2 ohne Spitzen und ohne Zuschläge für Schneider oder Durch.",
    Jungfrau:
      "Bei Ramsch erhält ein Spieler mit 0 Augen den doppelten Betrag. Im Dummy werden die Empfänger mit 0 Augen ausdrücklich markiert; beim Gewinn mit 120 Augen gilt keine Jungfrau-Verdopplung.",
    Legen:
      "Pro Leger wird der Spielwert verdoppelt. Buttons 1–4 ergeben ×2/×4/×8/×16. Ohne Auswahl gilt ×1; erneutes Antippen hebt die Wahl auf.",
    Schneider: "Zusätzlicher Betrag für Schneider.",
    Durch: "Kommt zusätzlich zum Schneiderbetrag hinzu.",
    Kreuzspiel:
      "Alternative zum Ramsch: Plätze 1 + 3 gegen 2 + 4. Grundbetrag 0,05 €.",
    Bettel: "Keinen Stich machen; bei Tout nach der ersten Karte auflegen.",
  };
  const defaults = () =>
    Object.fromEntries(
      [
        ...games,
        "Tout",
        "Light",
        "Jungfrau",
        "Legen",
        "Schneider",
        "Durch",
      ].map((name, i) => [
        name,
        {
          enabled: name !== "Ramsch",
          points:
            {
              King: 6,
              Wenz: 6,
              Geier: 6,
              Solo: 6,
              Sau: 1,
              Bagga: 6,
              Kreuzspiel: 1,
              Bettel: 1,
              Schneider: 1,
              Durch: 1,
            }[name] ?? null,
          cents:
            {
              King: 20,
              Wenz: 20,
              Geier: 20,
              Solo: 20,
              Sau: 5,
              Bagga: 30,
              Spitz: 40,
              Ramsch: 10,
              Kreuzspiel: 5,
              Bettel: 15,
              Schneider: 5,
              Durch: 5,
            }[name] ?? null,
        },
      ]),
    );
  function parseCents(input) {
    const s = String(input).trim();
    if (!/^\d+(?:[.,]\d{1,2})?$/.test(s))
      throw Error("Betrag mit höchstens zwei Nachkommastellen eingeben.");
    const [a, b = ""] = s.replace(",", ".").split(".");
    const n = Number(a) * 100 + Number(b.padEnd(2, "0"));
    if (!Number.isSafeInteger(n) || n > 100000)
      throw Error("Betrag zwischen 0 und 1.000 Euro eingeben.");
    return n;
  }
  const spikesAllowed = (game, light = false) =>
    !light &&
    !["Sau", "Kreuzspiel", "Bagga", "Spitz", "Ramsch", "Bettel"].includes(game);
  const resultAllowed = (game) =>
    !["Ramsch", "Spitz", "Bagga", "Bettel"].includes(game);
  function calculate(config, input) {
    if (!games.includes(input.game) || !config[input.game]?.enabled)
      throw Error("Dieses Spiel ist nicht freigegeben.");
    const c = config[input.game].cents;
    if (!Number.isSafeInteger(c) || c < 0 || c > 100000)
      throw Error("Ungültiger Grundbetrag.");
    const key = spikesAllowed(input.game, input.light)
      ? [...new Set(input.spikes || [])].sort().join("")
      : "";
    const factors = { "": 4, A: 4, AB: 6, ABC: 7, ABCD: 8, CD: 7, D: 8 };
    if (!/^[ABCD]*$/.test(key)) throw Error("Ungültige Spitzenwahl.");
    const spikeFactor = factors[key] ?? 4;
    // Hidden result fields never contribute to Tout/Light or games without result bonuses.
    const usesResult = resultAllowed(input.game) && !input.tout && !input.light;
    if (usesResult) {
      if (!["normal", "schneider", "durch"].includes(input.result))
        throw Error("Spielergebnis wählen.");
      if (input.result !== "normal" && !config.Schneider.enabled)
        throw Error("Schneider ist nicht freigegeben.");
      if (input.result === "durch" && !config.Durch.enabled)
        throw Error("Durch ist nicht freigegeben.");
    }
    if (input.tout && input.light)
      throw Error("Tout und Light sind im Dummy alternativ wählbar.");
    if (
      input.tout &&
      (!config.Tout.enabled ||
        ![...solo, "Bagga", "Bettel"].includes(input.game))
    )
      throw Error("Tout ist für dieses Spiel nicht freigegeben.");
    if (input.light && (!config.Light.enabled || !solo.includes(input.game)))
      throw Error("Light ist für dieses Spiel nicht freigegeben.");
    if (
      ![1, 2, 4, 8].includes(input.announcement) ||
      !Number.isInteger(input.laid) ||
      input.laid < 0 ||
      input.laid > 4
    )
      throw Error("Ungültiger Multiplikator.");
    if (input.laid && !config.Legen.enabled)
      throw Error("Legen ist nicht freigegeben.");
    const knockers = input.game === "Ramsch" ? (input.knockers ?? 0) : 0;
    if (!Number.isInteger(knockers) || knockers < 0 || knockers > 4)
      throw Error("Klopfer: 0 bis 4 wählen.");
    const bonus = usesResult
      ? (input.result === "normal" ? 0 : config.Schneider.cents) +
        (input.result === "durch" ? config.Durch.cents : 0)
      : 0;
    let quarters = c * spikeFactor + bonus * 4;
    // Bettel has no Spitzen/bonuses with Tout, so ×1.5 stays exact in quarter-cents.
    const specialMultiplier = input.tout
      ? input.game === "Bettel"
        ? 1.5
        : 2
      : input.light
        ? 2
        : 1;
    const multiplier =
      specialMultiplier * input.announcement * 2 ** input.laid * 2 ** knockers;
    quarters *= multiplier;
    if (!Number.isSafeInteger(quarters)) throw Error("Spielwert ist zu groß.");
    return {
      quarters,
      cents: quarters / 4,
      base: c,
      spikes: key,
      spikeQuarters: spikeFactor,
      bonus,
      multiplier,
      knockers,
      fractionalCent: quarters % 4 !== 0,
    };
  }
  function settlement(quarters, input) {
    if (!Number.isSafeInteger(quarters) || quarters < 0)
      throw Error("Ungültiger Spielwert.");
    if (!Number.isInteger(input.seat) || input.seat < 0 || input.seat > 3)
      throw Error("Spieler auswählen.");
    const team = ["Sau", "Kreuzspiel"].includes(input.game);
    if (
      team &&
      (!Number.isInteger(input.partner) ||
        input.partner < 0 ||
        input.partner > 3 ||
        input.partner === input.seat)
    )
      throw Error("Bitte zwei Spieler auswählen.");
    if (input.game === "Kreuzspiel" && (input.seat + 2) % 4 !== input.partner)
      throw Error("Kreuzspiel: Platz 1 + 3 oder 2 + 4 auswählen.");
    if (input.game === "Ramsch" && !input.won) {
      const out = [0, 0, 0, 0];
      for (let i = 0; i < 4; i++)
        if (i !== input.seat) {
          out[i] = quarters * ((input.jungfrauen || []).includes(i) ? 2 : 1);
          out[input.seat] -= out[i];
        }
      return out;
    }
    const side = team ? [input.seat, input.partner] : [input.seat];
    return [0, 1, 2, 3].map((i) => {
      const factor = team ? 1 : i === input.seat ? 3 : 1;
      return quarters * factor * (side.includes(i) === input.won ? 1 : -1);
    });
  }
  const api = {
    defaults,
    calculate,
    settlement,
    parseCents,
    spikesAllowed,
    resultAllowed,
    games,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  if (typeof window === "undefined") return;
  window.HHEuroDummy = api;
  const host = document.getElementById("euroApp");
  if (!host) return;
  document.documentElement.dataset.theme =
    location.hash === "#dark" ? "dark" : "light";
  const $ = (id) => document.getElementById(id),
    el = (tag, cls, text) => {
      const n = document.createElement(tag);
      if (cls) n.className = cls;
      if (text !== undefined) n.textContent = text;
      return n;
    };
  const euro = (cents) =>
    new Intl.NumberFormat("de-DE", {
      style: "currency",
      currency: "EUR",
      minimumFractionDigits: 2,
      maximumFractionDigits: 4,
    }).format(cents / 100);
  const icons = {
    King: "cards/euro-king.svg",
    Wenz: "cards/euro-wenz.svg",
    Geier: "cards/euro-geier.svg",
    Solo: "cards/euro-solo.svg",
    Sau: "cards/euro-sau.svg",
    Kreuzspiel: "kreuzspiel",
    Bettel: "cards/euro-bettel.svg",
    Bagga: "cards/euro-bagga.svg",
    Spitz: "cards/euro-spitz.svg",
    Ramsch: "eichel",
  };
  let config = defaults(),
    history = [],
    state = {
      seat: 0,
      partner: null,
      team: [],
      jungfrauen: [],
      game: "Solo",
      spikes: [],
      result: "normal",
      tout: false,
      light: false,
      won: true,
      announcement: 1,
      laid: 0,
      knockers: 0,
    };
  function option(label, pressed, run, icon) {
    const b = el("button", "choice");
    b.type = "button";
    b.setAttribute("aria-pressed", String(pressed));
    if (icon) {
      const im = el("img");
      im.src = icon.includes("/") ? icon : "cards/" + icon + ".svg";
      im.alt = "";
      b.append(im);
    }
    b.append(document.createTextNode(label));
    b.onclick = () => {
      run();
      render();
    };
    return b;
  }
  function section(title, group) {
    const s = el("section", "field");
    s.append(el("h2", "", title), group);
    return s;
  }
  function choices(options, prop) {
    const box = el("div", "choices");
    for (const [value, label] of options)
      box.append(
        option(label, state[prop] === value, () => (state[prop] = value)),
      );
    return box;
  }
  function info(text) {
    $("infoText").textContent = text;
    $("infoDialog").showModal();
  }
  function render() {
    const root = $("entry");
    root.replaceChildren();
    const people = el("div", "players");
    for (let i = 0; i < 4; i++) {
      const teamGame = ["Sau", "Kreuzspiel"].includes(state.game);
      const b = option(
        "",
        teamGame ? state.team.includes(i) : state.seat === i,
        () => {
          if (teamGame) {
            state.team = state.team.includes(i)
              ? state.team.filter((x) => x !== i)
              : state.team.length === 2
                ? [state.team[0], i]
                : [...state.team, i];
            state.seat = state.team[0];
            state.partner = state.team[1];
          } else {
            state.seat = i;
            state.jungfrauen = [];
          }
        },
      );
      b.setAttribute("aria-label", "Platz " + (i + 1) + " auswählen");
      b.append(
        el("span", "avatar", "S" + (i + 1)),
        el("small", "seat", String(i + 1)),
        el("span", "", "Spieler " + (i + 1)),
      );
      people.append(b);
    }
    root.append(section("Wer spielt?", people));
    const variants = el("div", "choices games");
    for (const game of games) {
      const b = option(
        game,
        state.game === game,
        () => {
          state.game = game;
          state.tout = false;
          state.light = false;
          state.spikes = [];
          state.jungfrauen = [];
          state.result = "normal";
          state.knockers = 0;
          state.team = ["Sau", "Kreuzspiel"].includes(game)
            ? [state.seat ?? 0]
            : [];
          state.partner = null;
        },
        icons[game],
      );
      b.disabled = !config[game].enabled;
      variants.append(b);
    }
    root.append(section("Spiel", variants));
    if (spikesAllowed(state.game, state.light)) {
      const group = el("div", "choices spikes");
      const suits = { A: "Eichel", B: "Gras", C: "Herz", D: "Schellen" };
      for (const letter of ["A", "B", "C", "D"]) {
        const family =
            state.game === "King"
              ? "king"
              : ["Solo", "Geier"].includes(state.game)
                ? "ober"
                : state.game === "Wenz"
                  ? "unter"
                  : null,
          suit = suits[letter];
        const b = option(
          family ? "" : letter,
          state.spikes.includes(letter),
          () => {
            state.spikes = state.spikes.includes(letter)
              ? state.spikes.filter((x) => x !== letter)
              : [...state.spikes, letter];
          },
          family
            ? "cards/" + family + "-" + suit.toLowerCase() + ".png"
            : undefined,
        );
        if (family) {
          const name =
            suit +
            (family === "king"
              ? "-König"
              : family === "ober"
                ? "-Ober"
                : "-Unter");
          b.setAttribute("aria-label", name);
          b.title = name + " (" + letter + ")";
          b.classList.add("spike-card");
        }
        group.append(b);
      }
      root.append(section("Spitzen", group));
    }
    const results = choices(
      [
        ["normal", "Schneider frei"],
        ["schneider", "Schneider"],
        ["durch", "Durch"],
      ],
      "result",
    );
    results.children[1].disabled = !config.Schneider.enabled;
    results.children[2].disabled =
      !config.Schneider.enabled || !config.Durch.enabled;
    if (resultAllowed(state.game) && !state.tout && !state.light)
      root.append(section("Spielergebnis", results));
    const toutAllowed =
      config.Tout.enabled && [...solo, "Bagga", "Bettel"].includes(state.game);
    const lightAllowed = config.Light.enabled && solo.includes(state.game);
    if (toutAllowed || lightAllowed) {
      const group = el("div", "choices");
      for (const mode of [
        "Nein",
        ...(toutAllowed ? ["Tout"] : []),
        ...(lightAllowed ? ["Light"] : []),
      ]) {
        const selected =
          mode === "Tout"
            ? state.tout
            : mode === "Light"
              ? state.light
              : !state.tout && !state.light;
        group.append(
          option(mode, selected, () => {
            state.tout = mode === "Tout";
            state.light = mode === "Light";
          }),
        );
      }
      root.append(section(lightAllowed ? "Tout & Light" : "Tout", group));
    }
    root.append(
      section(
        "Ausgang",
        choices(
          [
            [true, "Gewonnen"],
            [false, "Verloren"],
          ],
          "won",
        ),
      ),
    );
    if (state.game === "Ramsch" && config.Jungfrau.enabled) {
      const group = el("div", "players jungfrau-players");
      for (let i = 0; i < 4; i++) {
        const b = option(
          "",
          state.jungfrauen.includes(i),
          () =>
            (state.jungfrauen = state.jungfrauen.includes(i)
              ? state.jungfrauen.filter((x) => x !== i)
              : [...state.jungfrauen, i]),
        );
        b.classList.add("jungfrau-choice");
        b.setAttribute("aria-label", "Spieler " + (i + 1));
        b.append(
          el("span", "avatar", "S" + (i + 1)),
          el("span", "", "Spieler " + (i + 1)),
        );
        b.disabled = state.won || i === state.seat;
        group.append(b);
      }
      const field = section("Jungfrau", group);
      field.append(
        el(
          "small",
          "muted",
          state.won
            ? "Beim Alleingewinn mit 120 Punkten gilt keine Jungfrau-Verdopplung."
            : "Spieler mit 0 Punkten markieren.",
        ),
      );
      root.append(field);
    }

    root.append(
      section(
        "Ansage",
        choices(
          [
            [1, "Ohne"],
            [2, "Kontra"],
            [4, "Re"],
            [8, "Sub"],
          ],
          "announcement",
        ),
      ),
    );
    if (state.game === "Ramsch") {
      const group = el("div", "choices count-options");
      for (let n = 1; n <= 4; n++)
        group.append(
          option(
            String(n),
            state.knockers === n,
            () => (state.knockers = state.knockers === n ? 0 : n),
          ),
        );
      const field = section("Klopfer", group);
      field.append(
        el(
          "small",
          "muted",
          state.knockers
            ? state.knockers + " Klopfer: ×" + 2 ** state.knockers
            : "Keine Auswahl: ohne Klopfer",
        ),
      );
      root.append(field);
    }
    if (config.Legen.enabled) {
      const group = el("div", "choices count-options");
      for (let n = 1; n <= 4; n++)
        group.append(
          option(
            String(n),
            state.laid === n,
            () => (state.laid = state.laid === n ? 0 : n),
          ),
        );
      const field = section("Leger", group);
      field.append(
        el(
          "small",
          "muted",
          state.laid
            ? state.laid + " Leger: ×" + 2 ** state.laid
            : "Keine Auswahl: ohne Leger",
        ),
      );
      root.append(field);
    }
    let value;
    try {
      value = calculate(config, state);
      $("amount").textContent = euro(value.cents);
      $("formula").textContent =
        euro(value.base) +
        " × " +
        (value.spikeQuarters / 4).toLocaleString("de-DE") +
        " Spitzen + " +
        euro(value.bonus) +
        " Zuschläge; anschließend ×" +
        value.multiplier.toLocaleString("de-DE");
      const hints = [];
      if (value.fractionalCent)
        hints.push("Centbruchteile werden exakt angezeigt und nicht gerundet.");
      $("issue").textContent = hints.join(" ");
      $("save").disabled = false;
      try {
        settlement(value.quarters, state);
      } catch (error) {
        $("issue").textContent = error.message;
        $("save").disabled = true;
      }
    } catch (e) {
      $("amount").textContent = "—";
      $("formula").textContent = "Spielwert noch nicht berechenbar.";
      $("issue").textContent = e.message;
      $("save").disabled = true;
    }
    $("topValue").textContent = value ? euro(value.cents) : "—";
    renderHistory();
  }
  function renderHistory() {
    const totals = [0, 0, 0, 0];
    for (const record of history)
      record.balances.forEach((n, i) => (totals[i] += n));
    document
      .querySelectorAll("[data-balance]")
      .forEach((n, i) => (n.textContent = euro(totals[i] / 4)));
    const box = $("history");
    box.replaceChildren();
    if (!history.length)
      box.append(el("p", "muted", "Noch keine Testpartie erfasst."));
    for (const [i, h] of [...history.entries()].reverse()) {
      const row = el("div", "history-row");
      row.append(
        el(
          "span",
          "",
          i +
            1 +
            ". Spieler " +
            (h.seat + 1) +
            " · " +
            h.game +
            " · " +
            (h.won ? "Gewonnen" : "Verloren"),
        ),
        el("strong", "", euro(h.value.cents)),
      );
      box.append(row);
    }
    $("undo").disabled = !history.length;
    $("testCount").textContent = history.length + " Testpartien";
  }
  $("save").onclick = () => {
    try {
      const value = calculate(config, state);
      const balances = settlement(value.quarters, state);
      history.push({ ...structuredClone(state), value, balances });
      render();
    } catch (e) {
      info(e.message);
    }
  };
  $("undo").onclick = () => {
    $("undoDialog").showModal();
  };
  $("undoYes").onclick = () => {
    history.pop();
    $("undoDialog").close();
    render();
  };
  $("settingsOpen").onclick = () => {
    const body = $("configRows");
    body.replaceChildren();
    for (const name of [
      ...games,
      "Tout",
      "Light",
      "Jungfrau",
      "Legen",
      "Schneider",
      "Durch",
    ]) {
      const cfg = config[name],
        tr = el("tr");
      tr.dataset.option = name;
      tr.classList.toggle("disabled-row", !cfg.enabled);
      const enabled = el("input");
      enabled.type = "checkbox";
      enabled.checked = cfg.enabled;
      enabled.dataset.enable = name;
      enabled.setAttribute("aria-label", name + " freigeben");
      enabled.onchange = () => {
        tr.classList.toggle("disabled-row", !enabled.checked);
        if (enabled.checked && ["Ramsch", "Kreuzspiel"].includes(name)) {
          const other = document.querySelector(
            '[data-enable="' +
              (name === "Ramsch" ? "Kreuzspiel" : "Ramsch") +
              '"]',
          );
          if (other) {
            other.checked = false;
            other.closest("tr").classList.add("disabled-row");
          }
        }
      };
      const td = el("td");
      td.append(enabled);
      tr.append(td, el("th", "", name));
      const point = el("td");
      point.textContent = cfg.points ?? "";
      tr.append(point);
      const price = el("td");
      if (cfg.cents !== null) {
        const input = el("input");
        input.type = "text";
        input.inputMode = "decimal";
        input.value = (cfg.cents / 100).toFixed(2).replace(".", ",");
        input.dataset.price = name;
        input.setAttribute("aria-label", name + " Betrag in Euro");
        price.append(input);
      } else
        price.textContent =
          name === "Tout"
            ? "×2 / Bettel ×1,5"
            : ["Light", "Jungfrau"].includes(name)
              ? "×2"
              : name === "Legen"
                ? "×2 je Leger"
                : "Noch offen";
      tr.append(price);
      const description = el("td"),
        button = el("button", "info", "i");
      button.type = "button";
      button.setAttribute("aria-label", "Information zu " + name);
      button.onclick = () => info(descriptions[name]);
      description.append(button);
      tr.append(description);
      body.append(tr);
    }
    $("settingsIssue").textContent = "";
    $("settingsDialog").showModal();
  };
  $("settingsForm").onsubmit = (e) => {
    e.preventDefault();
    try {
      const draft = structuredClone(config);
      document
        .querySelectorAll("[data-enable]")
        .forEach((n) => (draft[n.dataset.enable].enabled = n.checked));
      document
        .querySelectorAll("[data-price]")
        .forEach((n) => (draft[n.dataset.price].cents = parseCents(n.value)));
      if (!games.some((g) => draft[g].enabled))
        throw Error("Mindestens ein Spiel freigeben.");
      if (draft.Ramsch.enabled && draft.Kreuzspiel.enabled)
        throw Error("Ramsch oder Kreuzspiel wählen, nicht beides.");
      config = draft;
      if (!config[state.game].enabled)
        state.game = games.find((g) => config[g].enabled);
      state.result = "normal";
      state.tout = false;
      state.light = false;
      state.laid = 0;
      state.knockers = 0;
      state.jungfrauen = [];
      $("settingsDialog").close();
      render();
    } catch (error) {
      $("settingsIssue").textContent = error.message;
    }
  };
  document
    .querySelectorAll("[data-close]")
    .forEach((b) => (b.onclick = () => $(b.dataset.close).close()));
  render();
})();
