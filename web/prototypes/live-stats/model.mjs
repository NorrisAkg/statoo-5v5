const teams = [
  {
    id: "A",
    name: "Racing Atlas",
    color: "#3b82f6",
    players: [
      ["a1", "Karim Benali"],
      ["a2", "Youssef El Amrani"],
      ["a3", "Lucas Martin"],
      ["a4", "Mehdi Alaoui"],
      ["a5", "Hugo Bernard"],
    ],
  },
  {
    id: "B",
    name: "Union des Cèdres",
    color: "#f97316",
    players: [
      ["b1", "Sofiane Berrada"],
      ["b2", "Nicolas Laurent"],
      ["b3", "Théo Dubois"],
      ["b4", "Enzo Morel"],
      ["b5", "Amine Idrissi"],
    ],
  },
  {
    id: "C",
    name: "Sporting du Port",
    color: "#a78bfa",
    players: [
      ["c1", "Camille Dupont"],
      ["c2", "Léo Mercier"],
      ["c3", "Jean-Baptiste de La Roche Saint-André"],
      ["c4", "Nassim El Fassi"],
      ["c5", "Adam Mansouri"],
    ],
  },
];
export function createDemo(mode = "tournament") {
  if (!["classic", "tournament"].includes(mode)) throw Error("Format inconnu.");
  return {
    version: 1,
    mode,
    teams: structuredClone(teams.slice(0, mode === "classic" ? 2 : 3)),
    events: [],
    closed: false,
  };
}
export function stats(state) {
  const out = { players: {} };
  for (const t of state.teams) {
    out[t.id] = { wins: 0, goals: 0, unassigned: 0 };
    for (const [id] of t.players)
      out.players[id] = { goals: 0, assists: 0, yellow: 0, red: 0 };
  }
  for (const e of state.events) {
    const t = out[e.team];
    if (e.type === "win") t.wins += e.delta;
    else if (e.type === "goal") {
      t.goals++;
      if (e.player) out.players[e.player].goals++;
      else t.unassigned++;
      if (e.assist) out.players[e.assist].assists++;
    } else out.players[e.player][e.type === "assist" ? "assists" : e.type]++;
  }
  return out;
}
export function record(state, action, legacy = false) {
  if (action.type === "assist" && !legacy) throw Error("La passe doit être liée à un but.");
  if (state.closed) throw Error("La séance est terminée.");
  const team = state.teams.find((t) => t.id === action.team);
  if (!team) throw Error("Équipe inconnue.");
  const valid = (id) => team.players.some((p) => p[0] === id);
  if (!["goal", "win", "assist", "yellow", "red"].includes(action.type))
    throw Error("Action inconnue.");
  if (action.type === "win") {
    if (
      state.mode !== "tournament" ||
      ![1, -1].includes(action.delta) ||
      stats(state)[team.id].wins + action.delta < 0
    )
      throw Error("Nombre de victoires invalide.");
  } else {
    if (
      (action.player && !valid(action.player)) ||
      (!action.player && action.type !== "goal")
    )
      throw Error("Choisissez un joueur de cette équipe.");
    if (
      action.assist &&
      (!valid(action.assist) ||
        !action.player ||
        action.assist === action.player ||
        action.type !== "goal")
    )
      throw Error("Passeur invalide.");
  }
  const event = {
    id: action.id || crypto.randomUUID(),
    type: action.type,
    team: team.id,
    player: action.player || null,
    assist: action.assist || null,
    delta: action.type === "win" ? action.delta : 1,
    at: action.at || new Date().toISOString(),
  };
  return { ...state, events: [...state.events, event] };
}
export function undo(state) {
  if (state.closed) throw Error("Reprenez la saisie pour corriger.");
  return { ...state, events: state.events.slice(0, -1) };
}
export const setClosed = (state, closed) => ({ ...state, closed: !!closed });
export function restore(raw, mode) {
  const value = JSON.parse(raw);
  if (
    value.version !== 1 ||
    value.mode !== mode ||
    !Array.isArray(value.events) ||
    value.events.length > 5000 ||
    typeof value.closed !== "boolean"
  )
    throw Error("Préparation illisible.");
  let state = createDemo(mode);
  for (const event of value.events) state = record(state, event, true);
  return setClosed(state, value.closed);
}

export function editGoal(state, id, values) {
  if (state.closed) throw Error("La séance est terminée.");
  const old = state.events.find(e => e.id === id && e.type === "goal");
  if (!old) throw Error("But introuvable.");
  const replacement = record({...state, events: []}, {...old, player: values.player, assist: values.assist}).events[0];
  return {...state, events: state.events.map(e => e.id === id ? replacement : e)};
}
