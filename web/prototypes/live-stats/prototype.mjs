import {
  editGoal,
  createDemo,
  record,
  undo,
  stats,
  setClosed,
  restore,
} from "./model.mjs";
const $ = (id) => document.getElementById(id),
  prefix = "statoo-live-prototype:",
  states = {},
  corrupt = new Set(),
  unsaved = new Set();
let mode = "tournament",
  selected = "A",
  state,
  writable = true,
  saved = true,
  notice = "";
const node = (tag, text = "", cls = "") => {
  const n = document.createElement(tag);
  n.textContent = text;
  n.className = cls;
  return n;
};
const icon = (kind) => {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  const path = document.createElementNS(svg.namespaceURI, "path");
  path.setAttribute("fill", "currentColor");
  path.setAttribute("d", kind === "shield"
    ? "M12 2 20 5v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V5l8-3Z"
    : "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 2 3 2-1 3h-4L9 6l3-2ZM5 7l3 1 1 4-3 2-2-2 1-5Zm14 0 1 5-2 2-3-2 1-4 3-1ZM8 15l3-1 2 3-1 3-4-1v-4Zm8 0 2 1-2 3-2 1 1-3 1-2Z");
  svg.append(path);
  return svg;
};
const button = (text, action, label) => {
  const b = node("button", text);
  if (label) b.setAttribute("aria-label", label);
  b.addEventListener("click", action);
  return b;
};
const team = () => state.teams.find((t) => t.id === selected);
const canEdit = () => writable && !state.closed && !corrupt.has(mode);
function error(text) {
  $("error").textContent = text;
  $("error").hidden = !text;
}
function load(next) {
  mode = next;
  selected = "A";
  if (!states[mode]) {
    try {
      const raw = localStorage.getItem(prefix + mode);
      states[mode] = raw ? restore(raw, mode) : createDemo(mode);
    } catch {
      states[mode] = createDemo(mode);
      corrupt.add(mode);
    }
  }
  state = states[mode];
  saved = !corrupt.has(mode) && !unsaved.has(mode);
  notice = "";
  error("");
  $("retry").hidden = !unsaved.has(mode);
  render();
  if (corrupt.has(mode))
    error(
      "La démo locale est illisible ou inaccessible. Réinitialisez-la pour continuer.",
    );
  else if (unsaved.has(mode))
    error(
      "Modification affichée mais non enregistrée sur cet appareil. Réessayez la sauvegarde.",
    );
}
function persist() {
  if (corrupt.has(mode)) {
    error("Réinitialisez la démo illisible avant de saisir.");
    return;
  }
  try {
    localStorage.setItem(prefix + mode, JSON.stringify(state));
    saved = true;
    unsaved.delete(mode);
    error("");
    $("retry").hidden = true;
  } catch {
    saved = false;
    unsaved.add(mode);
    error(
      "Modification affichée mais non enregistrée sur cet appareil. Réessayez la sauvegarde.",
    );
    $("retry").hidden = false;
  }
}
function change(action, message) {
  if (!canEdit()) return;
  try {
    if (corrupt.has(mode))
      throw Error("Réinitialisez la démo illisible avant de saisir.");
    state = record(state, { ...action, team: action.team || selected });
    states[mode] = state;
    notice = message;
    persist();
    render();
  } catch (e) {
    error(e.message);
  }
}
function playerName(id) {
  return (
    state.teams.flatMap((t) => t.players).find((p) => p[0] === id)?.[1] ||
    "Buteur non renseigné"
  );
}
function describe(e) {
  const t = state.teams.find((t) => t.id === e.team);
  if (e.type === "win")
    return {
      title: e.delta === 1 ? "Une victoire ajoutée" : "Une victoire retirée",
      detail: t.name,
      icon: "V",
    };
  const types = {
    goal: "But",
    assist: "Passe décisive",
    yellow: "Carton jaune",
    red: "Carton rouge",
  };
  return {
    title: types[e.type] + " · " + playerName(e.player),
    detail: t.name + (e.assist ? " · Passe de " + playerName(e.assist) : ""),
    icon:
      e.type === "goal"
        ? "+1"
        : e.type === "assist"
          ? "P"
          : e.type === "yellow"
            ? "J"
            : "R",
  };
}
function render() {
  const totals = stats(state),
    current = team();
  document.querySelectorAll("[data-mode]").forEach((b) => {
    b.classList.toggle("selected", b.dataset.mode === mode);
    b.setAttribute("aria-pressed", String(b.dataset.mode === mode));
  });
  $("format-label").textContent =
    mode === "tournament" ? "Tournoi à 3 équipes" : "Match à 2 équipes";
  $("session-status").textContent = state.closed
    ? "Terminée"
    : writable
      ? "En cours"
      : "Consultation";
  $("score-help").textContent =
    mode === "tournament"
      ? "Les victoires sont cumulées par équipe. Les buts renseignés ci-dessous ne changent pas ce compteur."
      : "Le score suit les buts enregistrés, y compris les buts non attribués.";
  $("scores").replaceChildren();
  $("scores").classList.toggle("classic-scoreboard", mode === "classic");
  const context = $("scores").closest(".context");
  context.classList.toggle("match-context", mode === "classic");
  context.style.setProperty("--team-a", state.teams[0].color);
  context.style.setProperty("--team-b", state.teams[1].color);
  $("teams").replaceChildren();
  for (const t of state.teams) {
    const card = node("article", "", "score-team");
    card.dataset.team = t.id;
    card.style.setProperty("--team", t.color);
    card.append(
      node("h3", t.name),
      node(
        "div",
        String(mode === "tournament" ? totals[t.id].wins : totals[t.id].goals),
        "score",
      ),
      node(
        "div",
        mode === "tournament"
          ? "victoire" + (totals[t.id].wins === 1 ? "" : "s")
          : "but" + (totals[t.id].goals === 1 ? "" : "s"),
        "score-caption",
      ),
    );
    if (mode === "classic") {
      const crest = node("span", "", "team-crest");
      crest.append(icon("shield"));
      card.append(crest);
    }
    if (mode === "tournament") {
      const actions = node("div", "", "win-actions");
      const minus = button(
          "−",
          () =>
            change(
              { type: "win", team: t.id, delta: -1 },
              "Victoire retirée · " + t.name,
            ),
          "Retirer une victoire à " + t.name,
        ),
        plus = button(
          "+",
          () =>
            change(
              { type: "win", team: t.id, delta: 1 },
              "Victoire ajoutée · " + t.name,
            ),
          "Ajouter une victoire à " + t.name,
        );
      minus.disabled = !canEdit() || !totals[t.id].wins;
      plus.disabled = !canEdit();
      actions.append(minus, plus);
      card.append(actions);
    }
    $("scores").append(card);
    if (mode === "classic" && t.id === "A") {
      const score = node("strong", `${totals.A.goals} – ${totals.B.goals}`, "central-score");
      score.id = "match-score";
      $("scores").append(score);
    }
    const tab = button(t.name, () => {
      selected = t.id;
      render();
    });
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", String(selected === t.id));
    tab.setAttribute("aria-label", t.name);
    if (selected === t.id) {
      const marker = node("span", "✓ Actif", "active-marker");
      marker.setAttribute("aria-hidden", "true");
      tab.append(marker);
    }
    tab.style.setProperty("--team", t.color);
    $("teams").append(tab);
  }
  $("scorers").replaceChildren();
  const scorerGrid = node("div", "", mode === "classic" ? "scorer-grid" : "scorer-stack");
  for (const t of state.teams) {
    const block = node("section");
    block.setAttribute("aria-label", "Buteurs · " + t.name);
    block.style.setProperty("--team", t.color);
    if (mode === "tournament") block.append(node("h4", t.name));
    const scorerRow = (name, goals) => {
      const row = node("p", "", "scorer-row");
      row.setAttribute("aria-label", `${name}, ${goals} ${goals === 1 ? "but" : "buts"}, ${t.name}`);
      const count = node("span", "", "goal-count");
      count.setAttribute("aria-hidden", "true");
      count.append(icon("ball"));
      if (goals > 1) count.append(node("span", "x" + goals));
      row.append(node("span", name, "scorer-name"), count);
      return row;
    };
    const scorers = t.players.filter(([id]) => totals.players[id].goals);
    for (const [id, name] of scorers) block.append(scorerRow(name, totals.players[id].goals));
    if (totals[t.id].unassigned) block.append(scorerRow("Non attribués", totals[t.id].unassigned));
    scorerGrid.append(block);
  }
  $("scorers").append(scorerGrid);
  $("scorers").hidden = !state.teams.some(t => totals[t.id].goals > 0);
  $("selected-name").textContent = current.name;
  $("selected-total").textContent =
    totals[selected].goals +
    " buts cumulés" +
    (totals[selected].unassigned
      ? " · " + totals[selected].unassigned + " non attribué(s)"
      : "");
  $("roster-count").textContent = current.players.length + " joueurs";
  $("players").replaceChildren();
  for (const [id, name] of current.players) {
    const s = totals.players[id],
      row = node("div", "", "player");
    row.dataset.player = id;
    const info = node("div", "", "player-info");
    info.append(
      node("p", name, "player-name"),
      node(
        "p",
        `${s.goals} but${s.goals === 1 ? "" : "s"} · ${s.assists} passe${s.assists === 1 ? "" : "s"} · ${s.yellow} jaune · ${s.red} rouge`,
        "player-stats",
      ),
    );
    const add = button(
      "+",
      () => pick("goal", id),
      "Ajouter un but pour " + name,
    );
    add.disabled = !canEdit();
    row.append(node("span", name.charAt(0), "avatar"), info, add);
    $("players").append(row);
  }
  for (const id of ["goal", "yellow", "red"])
    $(id).disabled = !canEdit();
  $("finish").hidden = state.closed;
  $("finish").disabled = !canEdit();
  $("resume").hidden = !state.closed || !writable;
  $("undo").disabled = !canEdit() || !state.events.length;
  $("undo-inline").disabled = !canEdit() || !state.events.length;
  $("save-status").textContent = !saved
    ? "Non enregistré sur cet appareil"
    : notice
      ? notice + " · Enregistré sur cet appareil"
      : "Données fictives · Conservation sur cet appareil";
  $("event-count").textContent = String(state.events.length);
  $("empty").hidden = !!state.events.length;
  $("journal").replaceChildren();
  for (const e of state.events.slice(-8).reverse()) {
    const d = describe(e),
      li = node("li"),
      line = node("div", "", "event-line"),
      info = node("div");
    info.append(
      node("p", d.title, "event-label"),
      node("p", d.detail, "event-detail"),
    );
    line.append(node("span", d.icon, "event-icon"), info);
    li.append(line);
    if (e.type === "goal" && canEdit()) li.append(button("Modifier ce but", () => {
      pick("goal", undefined, e.id);
    }));
    $("journal").append(li);
  }
}
function choices(title, help, items) {
  $("picker-title").textContent = title;
  $("picker-help").textContent = help;
  $("choices").replaceChildren();
  for (const item of items) {
    const b = button(item.name, item.action);
    if (item.secondary) b.classList.add("choice-secondary");
    $("choices").append(b);
  }
  if (!$("picker").open) $("picker").showModal();
  $("picker").scrollTop = 0;
}
function pick(type, player, editing = null) {
  if (!canEdit()) return;
  const t = editing
    ? state.teams.find(t => t.id === state.events.find(e => e.id === editing).team)
    : team();
  $("picker-team").textContent = t.name;
  $("picker-close").textContent = editing ? "Annuler la modification" : type === "goal" ? "Annuler le but" : "Fermer";
  $("picker-back").hidden = true;
  const finish = (id, assist = null) => {
    const action = { type, team: t.id, player: id, assist };
    $("picker").close();
    const label =
      type === "goal"
        ? "But"
        : type === "assist"
          ? "Passe décisive"
          : type === "yellow"
            ? "Carton jaune"
            : "Carton rouge";
    if (editing) {
      if (!canEdit()) return;
      try {
        state = editGoal(state, editing, {player: id, assist});
        states[mode] = state;
        notice = "But corrigé";
        persist();
        render();
      } catch (e) { error(e.message); }
    } else change(action, label + " · " + playerName(id));
  };
  const choosePlayer = (id) => {
    if (type !== "goal" || id === null) {
      finish(id);
      return;
    }
    choices(
      "But de " + playerName(id),
      "Qui lui a fait la passe ? Le but sera enregistré après ce choix.",
      [
        {
          name: "Aucun passeur",
          secondary: true,
          action: () => finish(id),
        },
        ...t.players
          .filter((p) => p[0] !== id)
          .map(([pid, name]) => ({ name, action: () => finish(id, pid) })),
      ],
    );
    $("picker-back").hidden = false;
    $("picker-back").onclick = () => pick(type, undefined, editing);
  };
  if (player) {
    choosePlayer(player);
    return;
  }
  choices(
    type === "goal"
      ? "Qui a marqué ?"
      : type === "assist"
        ? "Qui a fait la passe ?"
        : "Quel joueur reçoit le carton ?",
    type === "goal"
      ? "Choisissez le buteur. La passe est facultative."
      : "L’action est conservée dès le choix du joueur.",
    [
      ...t.players.map(([id, name]) => ({
        name,
        action: () => choosePlayer(id),
      })),
      ...(type === "goal"
        ? [
            {
              name: "Buteur non renseigné",
              secondary: true,
              action: () => choosePlayer(null),
            },
          ]
        : []),
    ],
  );
}
function review() {
  if (!canEdit()) return;
  const all = stats(state);
  $("review-body").replaceChildren();
  for (const t of state.teams) {
    const box = node("section", "", "review-team"),
      totals = t.players.reduce(
        (a, [id]) => {
          const s = all.players[id];
          return {
            assists: a.assists + s.assists,
            yellow: a.yellow + s.yellow,
            red: a.red + s.red,
          };
        },
        { assists: 0, yellow: 0, red: 0 },
      );
    box.append(
      node("h3", t.name),
      node(
        "p",
        (mode === "tournament" ? `${all[t.id].wins} victoire(s) · ` : "") +
          `${all[t.id].goals} but(s) · ${totals.assists} passe(s)`,
      ),
      node("p", `${totals.yellow} carton(s) jaune(s) · ${totals.red} rouge(s)`),
    );
    if (all[t.id].unassigned)
      box.append(node("p", `${all[t.id].unassigned} but(s) non attribué(s).`));
    if (totals.assists > all[t.id].goals)
      box.append(
        node(
          "p",
          "À vérifier : plus de passes décisives que de buts.",
          "error",
        ),
      );
    $("review-body").append(box);
  }
  $("review").showModal();
}
for (const b of document.querySelectorAll("[data-mode]"))
  b.addEventListener("click", () => load(b.dataset.mode));
$("goal").setAttribute("aria-label", "Ajouter un but");
for (const type of ["goal", "yellow", "red"])
  $(type).addEventListener("click", () => pick(type));
$("picker-close").addEventListener("click", () => $("picker").close());
$("finish").addEventListener("click", review);
$("review-cancel").addEventListener("click", () => $("review").close());
$("review-confirm").addEventListener("click", () => {
  if (!canEdit()) return;
  state = setClosed(state, true);
  states[mode] = state;
  notice = "Séance terminée";
  persist();
  $("review").close();
  render();
});
$("resume").addEventListener("click", () => {
  if (!writable || corrupt.has(mode)) return;
  state = setClosed(state, false);
  states[mode] = state;
  notice = "Saisie reprise";
  persist();
  render();
});
for (const id of ["undo", "undo-inline"])
  $(id).addEventListener("click", () => {
    if (!canEdit()) return;
    state = undo(state);
    states[mode] = state;
    notice = "Dernière action annulée";
    persist();
    render();
  });
$("retry").addEventListener("click", () => {
  persist();
  render();
});
$("access").addEventListener("change", (e) => {
  writable = e.target.value === "editor";
  $("picker").close();
  $("review").close();
  render();
});
$("scale").addEventListener("change", (e) => {
  document.documentElement.style.fontSize =
    (16 * Number(e.target.value)) / 100 + "px";
  document.documentElement.dataset.largeText = String(
    Number(e.target.value) >= 200,
  );
});
$("theme").addEventListener("click", () => {
  const light = document.documentElement.dataset.theme
    ? document.documentElement.dataset.theme === "light"
    : matchMedia("(prefers-color-scheme: light)").matches;
  document.documentElement.dataset.theme = light ? "dark" : "light";
});
$("reset").addEventListener("click", () => {
  if (!confirm("Effacer uniquement les essais de ce prototype ?")) return;
  try {
    for (const m of ["classic", "tournament"]) {
      localStorage.removeItem(prefix + m);
      delete states[m];
      corrupt.delete(m);
      unsaved.delete(m);
    }
    notice = "";
    error("");
    load(mode);
  } catch {
    error(
      "Le stockage est inaccessible. La réinitialisation n’a pas été enregistrée.",
    );
  }
});
load(mode);
