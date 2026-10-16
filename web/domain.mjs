import {
  validate,
  parseInteger,
  parseDate,
  sportInputSchema,
  financeInputSchema,
  operationSchema,
  correctionReasonSchema,
} from "./validation.mjs";
export const responsibleRoles = [
  "ADMIN",
  "PDT",
  "VP",
  "TR",
  "TGA",
  "SG",
  "SGA",
  "CENSOR",
];
export const roleLabels = {
  ADMIN: "Admin",
  PDT: "Président",
  VP: "Vice-président",
  TR: "Trésorier",
  TGA: "Trésorier-adjoint",
  SG: "Secrétaire général",
  SGA: "Secrétaire général adjoint",
  CENSOR: "Censeur",
  MEMBER: "Membre",
};
export const palette = {
  Bleu: 0xff3b82f6,
  Orange: 0xfff97316,
  Vert: 0xff22c55e,
  Rouge: 0xffef4444,
  Violet: 0xff8b5cf6,
  Rose: 0xffec4899,
  Jaune: 0xfffacc15,
  Turquoise: 0xff06b6d4,
};
export function capabilities(account) {
  const has = (roles) =>
    !account?.shared && (account?.roles || []).some((r) => roles.includes(r));
  return {
    sport: has(["ADMIN", "PDT", "VP", "SG", "SGA"]),
    finance: has(["TR", "TGA"]),
    admin: has(["ADMIN"]),
    arbitrate: has(["PDT", "VP"]),
    settings: has(["ADMIN", "TR", "TGA"]),
  };
}
export function objectMap(value) {
  try {
    return typeof value === "string" ? JSON.parse(value) : value || {};
  } catch {
    return {};
  }
}
export function color(value, fallback = "#3b82f6") {
  return Number.isInteger(Number(value))
    ? "#" + (Number(value) >>> 0).toString(16).padStart(8, "0").slice(-6)
    : fallback;
}
export function integer(value, label = "Nombre", signed = false) {
  return parseInteger(value, label, signed);
}
function validDate(value) {
  parseDate(value);
}
export function newReference(snapshot, day) {
  const date = day.slice(0, 10);
  validDate(date);
  const known = new Set([
    ...Object.keys(snapshot.obligations || {}),
    ...Object.entries(snapshot.documents || {}).map(
      ([key, d]) => d.occurrence_id || key.slice(key.indexOf(":") + 1),
    ),
  ]);
  let number = 1;
  while (known.has(`${date}-${number}`)) number++;
  return `${date}-${number}`;
}
export function prepareSport(payload, members, status = "DRAFT", minimum = 6) {
  const p = validate(sportInputSchema, structuredClone(payload)),
    s = p.session;
  validDate(s.played_at);
  if (!["DRAFT", "CLOSED", "CANCELLED"].includes(status))
    throw Error("État de séance invalide.");
  s.status = status;
  const tournament = s.session_type === "TOURNAMENT_3";
  const teams = tournament ? ["A", "B", "C"] : ["A", "B"];
  const names = objectMap(s.team_names),
    colors = objectMap(s.team_colors);
  teams.forEach((team, i) => {
    names[team] ??= "Équipe " + team;
    colors[team] ??= Object.values(palette)[i];
  });
  s.team_names = names;
  s.team_colors = colors;
  if (
    new Set(
      teams.map((t) =>
        (names[t] || "Équipe " + t).trim().toLocaleLowerCase("fr"),
      ),
    ).size !== teams.length
  )
    throw Error("Chaque équipe doit avoir un nom différent.");
  if (
    teams.some((t) => !Object.values(palette).includes(colors[t])) ||
    new Set(teams.map((t) => colors[t])).size !== teams.length
  )
    throw Error("Choisissez des couleurs différentes dans la palette.");
  const known = new Set(members.map((m) => m.id));
  const seen = new Set();
  for (const part of p.participations) {
    if (
      !known.has(part.player_id) ||
      seen.has(part.player_id) ||
      !teams.includes(part.team) ||
      part.session_id !== s.id
    )
      throw Error("Participants inconnus, en double ou sans équipe valide.");
    seen.add(part.player_id);
    for (const key of ["goals", "assists", "yellow_cards", "red_cards"])
      part[key] = integer(part[key] ?? 0, "Statistiques");
  }
  for (const team of teams) {
    const k = team.toLowerCase();
    s["wins_" + k] = integer(s["wins_" + k] ?? 0, "Victoires");
    if (!tournament) s["score_" + k] = integer(s["score_" + k] ?? 0, "Score");
    else s["score_" + k] = null;
    const parts = p.participations.filter((p) => p.team === team),
      goals = parts.reduce((n, p) => n + p.goals, 0),
      assists = parts.reduce((n, p) => n + p.assists, 0);
    if (!tournament && goals > s["score_" + k])
      throw Error("Les buts attribués dépassent le score.");
    if (assists > goals || parts.some((p) => p.goals + p.assists > goals))
      throw Error("Passes décisives incohérentes.");
    s["unassigned_goals_" + k] = tournament
      ? integer(s["unassigned_goals_" + k] ?? 0)
      : s["score_" + k] - goals;
  }
  s.draw_points = integer(s.draw_points ?? 1, "Points du nul");
  if (status === "CLOSED") {
    if (p.participations.length < minimum)
      throw Error(
        `Sélectionnez au minimum ${minimum} joueurs pour clôturer la séance.`,
      );
    const counts = teams.map(
      (t) => p.participations.filter((p) => p.team === t).length,
    );
    if (!s.allow_uneven_teams && Math.max(...counts) - Math.min(...counts) > 1)
      throw Error("Équipes déséquilibrées.");
    if (!p.participations.length)
      throw Error("Sélectionnez les joueurs présents.");
    if (tournament) {
      const max = Math.max(...teams.map((t) => s["wins_" + t.toLowerCase()]));
      if (max === 0) throw Error("Saisissez au moins une victoire.");
      const winners = teams
        .filter((t) => s["wins_" + t.toLowerCase()] === max)
        .join("");
      s.result =
        winners.length === 1
          ? winners
          : winners === "ABC"
            ? "DRAW_ALL"
            : "DRAW_" + winners;
    } else
      s.result =
        s.score_a > s.score_b ? "A" : s.score_b > s.score_a ? "B" : "DRAW";
  } else s.result = null;
  return p;
}
export function prepareFinance(payload, roster) {
  const p = validate(financeInputSchema, structuredClone(payload));
  validDate(p.played_at);
  p.rate = integer(p.rate, "Cotisation");
  if (
    new Set(p.lines.map((l) => l.member_id)).size !== p.lines.length ||
    p.lines.length !== roster.length ||
    p.lines.some((l) => !roster.includes(l.member_id))
  )
    throw Error(
      "Tous les membres de cette échéance doivent figurer dans le point.",
    );
  for (const line of p.lines) {
    for (const key of ["contribution", "penalty_due", "penalty_paid"])
      line[key] = integer(line[key] ?? 0, "Montant");
    if (line.penalty_due && !line.reason?.trim())
      throw Error("Motif requis pour une pénalité.");
  }
  const seen = new Set();
  for (const m of [...p.expenses, ...p.donations]) {
    m.amount = integer(m.amount, "Montant");
    if (!m.label?.trim() || seen.has(m.id))
      throw Error("Libellé de mouvement requis et identifiants distincts.");
    seen.add(m.id);
  }
  if (
    p.cancelled &&
    (p.lines.some((l) => l.contribution || l.penalty_due || l.penalty_paid) ||
      p.expenses.length ||
      p.donations.length)
  )
    throw Error("Échéance annulée : aucun mouvement autorisé.");
  return p;
}
export function teamSummary(payload, members) {
  const s = payload.session,
    names = objectMap(s.team_names),
    colors = objectMap(s.team_colors),
    tournament = s.session_type === "TOURNAMENT_3";
  return (tournament ? ["A", "B", "C"] : ["A", "B"]).map((team, i) => ({
    team,
    name: names[team] || "Équipe " + team,
    color: color(colors[team], ["#3b82f6", "#f97316", "#22c55e"][i]),
    value: tournament
      ? (s["wins_" + team.toLowerCase()] ?? 0) + " V"
      : (s["score_" + team.toLowerCase()] ?? "–"),
    unassigned: s["unassigned_goals_" + team.toLowerCase()] || 0,
    scorers: (payload.participations || [])
      .filter((p) => p.session_id === s.id && p.team === team && p.goals > 0)
      .map((p) => ({
        name:
          members.find((m) => m.id === p.player_id)?.name || "Ancien membre",
        goals: p.goals,
      }))
      .sort((a, b) => b.goals - a.goals || a.name.localeCompare(b.name, "fr")),
  }));
}
export function operation(domain, reference, payload, document, reason = "") {
  reference = validate(operationSchema.shape.occurrence_id, reference);
  reason = validate(
    document ? correctionReasonSchema : operationSchema.shape.reason,
    reason,
  );
  const wire = structuredClone(payload);
  if (domain === "sport" && wire.session) {
    const session = wire.session;
    session.team_names = JSON.stringify(objectMap(session.team_names));
    session.team_colors = JSON.stringify(objectMap(session.team_colors));
    session.is_ranked = [true, 1, "1"].includes(session.is_ranked) ? 1 : 0;
    session.allow_uneven_teams = [true, 1, "1"].includes(
      session.allow_uneven_teams,
    )
      ? 1
      : 0;
  }
  return validate(operationSchema, {
    operation_id: crypto.randomUUID(),
    occurrence_id: reference.trim(),
    domain,
    base_revision: document?.revision || 0,
    generation: document?.generation || 0,
    payload: wire,
    reason: reason.trim(),
  });
}
export function parseMemberNames(value) {
  return value
    .split(/[,\r\n]+/)
    .map((name) => name.trim())
    .filter(Boolean);
}
