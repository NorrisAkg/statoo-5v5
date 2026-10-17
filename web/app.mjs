import { prepareBusyButton, withBusyButton } from "./button-state.mjs";
import {
  validate,
  validateMutation,
  registrationSchema,
  credentialsSchema,
} from "./validation.mjs";
import { standings } from "./summary.mjs";
import { PortalClient } from "./client.mjs";
import {
  capabilities,
  roleLabels,
  responsibleRoles,
  palette,
  objectMap,
  integer,
  newReference,
  prepareSport,
  prepareFinance,
  teamSummary,
  parseMemberNames,
} from "./domain.mjs";
import { registerPwa } from "./pwa.mjs";
import { apiAddress } from "./config.mjs";
import { RegistrationDraft } from "./registration-draft.mjs";
import { preserveInteraction } from "./interaction.mjs";

const $ = (id) => document.getElementById(id),
  client = new PortalClient();
let tab = "Accueil",
  catalog = [],
  modal = null,
  registration = false,
  configuredApi = null,
  configurationError = null;
let filtersIdentity = null;
let sessionFilters = { status: "all", search: "" };
const money = (n) => new Intl.NumberFormat("fr-FR").format(n || 0) + " F";
const date = (value) =>
  Number.isFinite(Date.parse(value))
    ? new Intl.DateTimeFormat("fr-FR", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(value))
    : "Date non renseignée";
const localDate = () => {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
};
function el(tag, text = "", className = "") {
  const n = document.createElement(tag);
  n.textContent = text;
  if (className) n.className = className;
  return n;
}
function button(text, action, className = "secondary") {
  const b = el("button", text, className);
  b.type = "button";
  b.addEventListener("click", action);
  return b;
}
function asyncButton(text, action, className = "secondary") {
  const b = button(
    text,
    () => withBusyButton(b, action).catch(report),
    className,
  );
  prepareBusyButton(b);
  return b;
}
const fieldPaths = {
  "Identifiant du groupe": "group_id",
  "Identifiant de connexion": "username",
  "Identifiant Admin": "username",
  "Identifiant personnel": "username",
  "Identifiant collectif": "shared_username",
  "Nouvel identifiant collectif": "username",
  "Mot de passe": "password",
  "Mot de passe Admin": "password",
  "Mot de passe personnel": "password",
  "Nouveau mot de passe collectif": "password",
  "Mot de passe collectif": "shared_password",
  "Nom du groupe": "name",
  "Nom court (facultatif)": "short_name",
  "Nom du membre": "name",
  "Minimum de joueurs par séance": "min_players_per_session",
  "Cotisation par défaut": "contribution",
  "Pénalité de retard par défaut": "late_penalty",
  "Caisse initiale": "cash",
  "Date de début des comptes": "start_date",
  "Motif du changement": "reason",
  "Motif du transfert": "reason",
  "Motif de la décision": "reason",
  "Motif de correction": "reason",
  "Date et heure": "session.played_at",
  "Date du point": "played_at",
};
let validationSequence = 0;
function clearValidation(form) {
  for (const input of form.querySelectorAll("[data-validation-error]")) {
    const id = input.dataset.validationError;
    const described = (input.getAttribute("aria-describedby") || "")
      .split(" ")
      .filter((value) => value && value !== id);
    if (described.length)
      input.setAttribute("aria-describedby", described.join(" "));
    else input.removeAttribute("aria-describedby");
    input.removeAttribute("aria-invalid");
    delete input.dataset.validationError;
  }
  form.querySelectorAll(".field-error").forEach((node) => node.remove());
}
function showValidation(form, error) {
  for (const issue of error.issues || []) {
    const path = issue.path.join(".");
    const input = [...form.querySelectorAll("[data-validation-path]")].find(
      (node) =>
        node.dataset.validationPath === path ||
        node.dataset.validationPath === issue.path.at(-1),
    );
    if (!input || input.dataset.validationError) continue;
    const help = el("span", issue.message, "error field-error");
    help.id = "validation-error-" + ++validationSequence;
    input.dataset.validationError = help.id;
    input.setAttribute("aria-invalid", "true");
    input.setAttribute(
      "aria-describedby",
      [input.getAttribute("aria-describedby"), help.id]
        .filter(Boolean)
        .join(" "),
    );
    input.parentElement.append(help);
  }
}
function message(text, error = false) {
  $("message").textContent = text;
  $("message").classList.toggle("error", error);
}
function field(parent, label, value = "", options = {}) {
  const wrapper = el("label", label, "field"),
    input = document.createElement(
      options.select ? "select" : options.textarea ? "textarea" : "input",
    );
  if (!options.select && !options.textarea) input.type = options.type || "text";
  if (options.select)
    for (const [key, name] of options.select) {
      const option = el("option", name);
      option.value = key;
      input.append(option);
    }
  if (!options.select)
    input.placeholder =
      options.placeholder ||
      {
        "Nom du groupe": "Ex. : Football Club des Amis",
        "Nom court (facultatif)": "Ex. : FCA",
        "Membres du groupe": "Ex. : Alice, Karim, Moussa",
        "Identifiant du groupe": "Ex. : #12345678",
        "Identifiant Admin": "Ex. : karim.admin",
        "Identifiant de connexion": "Ex. : membres",
        "Identifiant collectif": "Ex. : membres",
      }[label] ||
      (options.type === "password"
        ? "Au moins 8 caractères"
        : options.type === "number"
          ? "Ex. : 0"
          : "Saisir : " + label.toLocaleLowerCase("fr"));
  input.value = value ?? "";
  input.setAttribute("aria-label", label);
  if (options.path || fieldPaths[label])
    input.dataset.validationPath = options.path || fieldPaths[label];
  input.required = !!options.required;
  if (options.min !== undefined) input.min = options.min;
  if (options.maxLength) input.maxLength = options.maxLength;
  if (options.type === "number") {
    input.step = "1";
    input.inputMode = "numeric";
  }
  if (options.type === "password") {
    input.minLength = 8;
    input.autocomplete = "new-password";
  }
  if (options.change)
    input.addEventListener(options.select ? "change" : "input", () =>
      options.change(input.value),
    );
  if (options.type === "password") {
    const control = el("span", "", "password-control");
    const toggle = button(
      "",
      () => {
        const visible = input.type === "password";
        input.type = visible ? "text" : "password";
        toggle.setAttribute(
          "aria-label",
          (visible ? "Masquer " : "Afficher ") + label,
        );
        toggle.setAttribute("aria-pressed", String(visible));
        input.focus({ preventScroll: true });
      },
      "password-toggle icon-button",
    );
    toggle.setAttribute("aria-label", "Afficher " + label);
    toggle.setAttribute("aria-pressed", "false");
    toggle.innerHTML =
      '<svg viewBox="0 0 24 24" aria-hidden="true" width="24" height="24"><path d="M12 5c5 0 9 7 9 7s-4 7-9 7-9-7-9-7 4-7 9-7Z" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.7"/><path class="eye-slash" d="m3 3 18 18" stroke="currentColor" stroke-width="2"/></svg>';
    control.append(input, toggle);
    wrapper.append(control);
  } else wrapper.append(input);
  parent.append(wrapper);
  return input;
}
function check(parent, label, value, change) {
  const wrap = el("label", "", "check"),
    input = document.createElement("input");
  input.type = "checkbox";
  input.checked = !!value;
  input.setAttribute("aria-label", label);
  input.addEventListener("change", () => change(input.checked));
  wrap.append(input, el("span", label));
  parent.append(wrap);
  return input;
}
function table(headers, rows) {
  const wrap = el("div", "", "table-wrap"),
    t = el("table"),
    head = el("thead"),
    hr = el("tr");
  for (const title of headers) {
    const th = el("th", title);
    th.scope = "col";
    hr.append(th);
  }
  head.append(hr);
  t.append(head);
  const body = el("tbody");
  for (const row of rows) {
    const tr = el("tr");
    for (const value of row) {
      const td = el("td");
      value instanceof Node
        ? td.append(value)
        : (td.textContent = String(value ?? ""));
      tr.append(td);
    }
    body.append(tr);
  }
  t.append(body);
  wrap.append(t);
  return wrap;
}
function card(title, subtitle = "") {
  const c = el("article", "", "card");
  if (title) c.append(el("h3", title));
  if (subtitle) c.append(el("p", subtitle, "muted"));
  return c;
}
function memberName(id) {
  return (
    client.snapshot?.members.find((m) => m.id === id)?.name || "Ancien membre"
  );
}
function currentCaps() {
  return capabilities(client.snapshot?.account);
}
function groupPath(doc) {
  return (
    "/documents/" +
    encodeURIComponent(doc.domain) +
    "/" +
    encodeURIComponent(doc.occurrence_id)
  );
}
function owned(doc, domain) {
  return (
    currentCaps()[domain] &&
    doc.owner === client.connection?.account.id &&
    !doc.candidates?.length
  );
}
function report(error) {
  if (!client.connection) {
    modal?.close();
    render();
  }
  if (error.status === 403 && client.snapshot) render();
  message(error.message || "La demande a échoué.", true);
}
async function run(action) {
  try {
    await action();
  } catch (error) {
    report(error);
  }
}
function dialog(title) {
  if (modal) {
    modal.close();
    modal.remove();
    modal = null;
  }
  const d = el("dialog"),
    header = el("div", "", "dialog-heading");
  header.append(
    el("h2", title),
    button("Fermer", () => d.close(), "icon-button"),
  );
  d.append(header);
  const form = el("form"),
    body = el("div", "", "dialog-body"),
    errors = el("p", "", "error"),
    actions = el("div", "", "dialog-actions");
  errors.setAttribute("role", "alert");
  form.append(body, errors, actions);
  d.append(form);
  document.body.append(d);
  modal = d;
  form.addEventListener("submit", (e) => e.preventDefault());
  d.addEventListener("close", () => {
    d.remove();
    if (modal === d) modal = null;
  });
  d.showModal();
  return {
    d,
    form,
    body,
    errors,
    actions,
    submit(label, action) {
      const b = button(
        label,
        async () => {
          if (!form.reportValidity()) return;
          clearValidation(form);
          errors.textContent = "";
          await withBusyButton(b, async () => {
            try {
              await action();
            } catch (error) {
              errors.textContent = error.message;
              showValidation(form, error);
              report(error);
            }
          });
        },
        "primary",
      );
      prepareBusyButton(b);
      actions.append(b);
      return b;
    },
  };
}
async function confirmSend(title, content) {
  const d = el("dialog"),
    body = el("div", "", "dialog-body"),
    actions = el("div", "", "dialog-actions");
  body.append(content);
  d.append(el("h2", title), body, actions);
  document.body.append(d);
  return new Promise((resolve) => {
    let settled = false;
    function done(value) {
      if (settled) return;
      settled = true;
      d.close();
      d.remove();
      resolve(value);
    }
    actions.append(
      button("Revenir à la saisie", () => done(false)),
      button("Confirmer l’envoi", () => done(true), "primary"),
    );
    d.addEventListener("cancel", (e) => {
      e.preventDefault();
      done(false);
    });
    d.showModal();
  });
}
function sportSummary(payload) {
  const c = el(
    "div",
    "",
    "teams " +
      (payload.session.session_type === "TOURNAMENT_3"
        ? "tournament"
        : "classic"),
  );
  for (const team of teamSummary(payload, client.snapshot.members)) {
    const block = el("section", "", "team"),
      heading = el("div", "", "team-heading"),
      name = el("h4", team.name);
    name.style.borderInlineStart = "4px solid " + team.color;
    name.style.paddingInlineStart = "8px";
    heading.append(name, el("strong", String(team.value)));
    block.append(heading);
    for (const scorer of team.scorers) {
      const line = el("div", "", "scorer");
      line.append(el("span", scorer.name), el("span", "⚽ " + scorer.goals));
      block.append(line);
    }
    if (team.unassigned)
      block.append(el("p", "Non attribués · ⚽ " + team.unassigned, "muted"));
    if (!team.scorers.length && !team.unassigned)
      block.append(el("p", "Aucun but enregistré", "muted"));
    c.append(block);
  }
  return c;
}
function payloadReview(domain, payload) {
  const node = el("div");
  if (domain === "sport") {
    const s = payload.session;
    node.append(
      el(
        "p",
        date(s.played_at) +
          " · " +
          { DRAFT: "Brouillon", CLOSED: "Terminée", CANCELLED: "Annulée" }[
            s.status
          ],
      ),
    );
    node.append(
      el(
        "p",
        (s.is_ranked ? "Classée" : "Amicale") +
          " · " +
          (s.allow_uneven_teams
            ? "Effectifs inégaux autorisés"
            : "Effectifs équilibrés") +
          " · Nul : " +
          (s.draw_points ?? 1) +
          " point(s)",
      ),
    );
    node.append(
      sportSummary(payload),
      table(
        ["Joueur", "Équipe", "Buts", "Passes", "Jaunes", "Rouges"],
        (payload.participations || []).map((p) => [
          memberName(p.player_id),
          p.team,
          p.goals,
          p.assists,
          p.yellow_cards || 0,
          p.red_cards || 0,
        ]),
      ),
    );
    if (s.notes) node.append(el("p", s.notes));
  } else {
    node.append(
      el(
        "p",
        date(payload.played_at) +
          " · Cotisation : " +
          money(payload.rate) +
          (payload.cancelled ? " · Annulée" : ""),
      ),
    );
    node.append(
      table(
        [
          "Membre",
          "Cotisation versée",
          "Pénalités réglées",
          "Pénalités dues",
          "Motif",
        ],
        payload.lines.map((l) => [
          memberName(l.member_id),
          money(l.contribution),
          money(l.penalty_paid),
          money(l.penalty_due),
          l.reason,
        ]),
      ),
    );
    for (const [label, key] of [
      ["Dépenses", "expenses"],
      ["Dons", "donations"],
    ]) {
      node.append(
        el("h4", label),
        table(
          ["Libellé", "Montant"],
          payload[key].map((m) => [m.label, money(m.amount)]),
        ),
      );
    }
  }
  return node;
}
function openingReview(p) {
  const node = el("div");
  node.append(
    el("p", "Caisse initiale"),
    el("strong", money(p.cash)),
    el("p", "À partir du " + (p.start_date || "début de l’historique")),
    table(
      ["Membre", "Avance (+) / dette (−)", "Pénalités dues"],
      Object.entries(p.members).map(([id, v]) => [
        memberName(id),
        money(v.contribution_balance),
        money(v.penalty_debt),
      ]),
    ),
  );
  return node;
}
function mutationForm(title, path, build, method = "POST") {
  const f = dialog(title),
    collect = build(f.body, f);
  f.submit("Enregistrer", async () => {
    const value = validateMutation(path, collect());
    if (!(await confirmSend("Vérifier la modification", summaryValues(value))))
      return;
    await client.mutate(path, value, method);
    f.d.close();
    render();
    message(client.refreshWarning || "Modification enregistrée.");
  });
  return f;
}
const labels = {
  username: "Identifiant",
  password: "Nouveau mot de passe",
  roles: "Rôles",
  member_id: "Membre",
  name: "Nom",
  is_active: "Actif",
  nickname: "Surnom",
  reason: "Motif",
  account_id: "Responsable",
  revision: "Version",
  transfer: "Transfert explicite",
  contribution: "Cotisation",
  late_penalty: "Pénalité de retard",
  group_id: "Groupe",
};
function summaryValues(value) {
  if (Array.isArray(value)) {
    return table(
      ["Membre", "Surnom", "Statut"],
      value.map((m) => [
        m.name,
        m.nickname || "—",
        m.is_active === 0 ? "Archivé" : "Actif",
      ]),
    );
  }
  const out = el("dl", "", "review-values");
  for (const [key, v] of Object.entries(value)) {
    if (key === "revision" || key === "id") continue;
    let display = v;
    if (key === "password") display = "••••••••";
    else if (key === "member_id") display = memberName(v);
    else if (key === "account_id")
      display =
        client.snapshot.leaders.find((a) => a.id === v)?.username ||
        "Responsable";
    else if (key === "group_id") display = client.snapshot.name;
    else if (key === "roles")
      display =
        v.map((r) => roleLabels[r] || r).join(" · ") || "Consultation seule";
    else if (typeof v === "boolean") display = v ? "Oui" : "Non";
    out.append(el("dt", labels[key] || key), el("dd", String(display ?? "—")));
  }
  return out;
}
const splash = el("div");
splash.id = "splash";
splash.setAttribute("role", "status");
splash.setAttribute("aria-label", "Ouverture de Statoo");
splash.innerHTML =
  '<img src="icons/logo-transparent.png" width="104" height="104" alt=""/><strong>STATOO</strong><span>STATS &amp; MATCHS 5V5</span><span class="splash-progress" aria-hidden="true"></span>';
document.body.append(splash);
let onboardingStep = null;
const splashReady = new Promise((resolve) => setTimeout(resolve, 900));
const onboardingPages = [
  [
    "Suivez vos matchs 5v5",
    "Enregistrez facilement vos séances, scores et statistiques individuelles au bord du terrain.",
  ],
  [
    "Tirage rapide & équilibré",
    "Générez vos compositions d'équipes aléatoires et ajustez les joueurs en temps réel.",
  ],
  [
    "Classement & Statistiques",
    "Découvrez qui domine au classement des points, aux victoires et au tableau des buteurs.",
  ],
];
function footballArt(step) {
  const holder = el("div", "", "football-art");
  holder.setAttribute("aria-hidden", "true");
  const scenes = [
    '<rect x="48" y="44" width="264" height="184" rx="24" fill="var(--surface)" stroke="currentColor" stroke-width="2"/><path d="M180 44v184M48 136h264" stroke="currentColor" opacity=".3"/><circle cx="180" cy="136" r="38" fill="none" stroke="currentColor" opacity=".4"/><rect x="103" y="20" width="154" height="64" rx="18" fill="var(--soft)" stroke="currentColor"/><text x="180" y="63" text-anchor="middle" fill="var(--text)" font-size="30" font-family="Poppins">3 : 2</text><circle cx="109" cy="164" r="17" fill="currentColor"/><circle cx="247" cy="113" r="17" fill="var(--text)"/>',
    '<path d="M64 76c100 0 120 124 232 124m-24-23 24 23-26 22M64 200c100 0 120-124 232-124m-24-23 24 23-26 22" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round"/><g fill="var(--surface)" stroke="currentColor" stroke-width="2"><circle cx="79" cy="76" r="26"/><circle cx="79" cy="200" r="26"/><circle cx="282" cy="76" r="26"/><circle cx="282" cy="200" r="26"/></g><g fill="var(--text)" font-size="19" text-anchor="middle" font-family="Poppins"><text x="79" y="83">A</text><text x="79" y="207">B</text><text x="282" y="83">B</text><text x="282" y="207">A</text></g>',
    '<path d="M48 236v-90h84v90m0 0V105h96v131m0 0v-64h84v64" fill="var(--surface)" stroke="currentColor" stroke-width="2"/><path d="M154 27h52v25c0 30-52 30-52 0Zm0 9h-18v12c0 13 18 16 18 16m52-28h18v12c0 13-18 16-18 16m-26 11v22m-19 0h38" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round"/><g fill="var(--text)" text-anchor="middle" font-size="26" font-family="Poppins"><text x="90" y="194">2</text><text x="180" y="157">1</text><text x="270" y="213">3</text></g>',
  ];
  holder.innerHTML =
    '<svg viewBox="0 0 360 270" focusable="false"><circle cx="180" cy="135" r="125" fill="currentColor" opacity=".07"/>' +
    scenes[step] +
    '<g fill="currentColor"><circle cx="28" cy="72" r="4"/><circle cx="328" cy="122" r="5"/><path d="m309 29 3 8 8 3-8 3-3 8-3-8-8-3 8-3Z"/></g></svg>';
  return holder;
}
function completeOnboarding() {
  try {
    localStorage.setItem("statoo-onboarding-complete", "1");
  } catch {}
  onboardingStep = null;
  render();
  $("content").focus();
}
function onboarding() {
  const page = el("section", "", "onboarding card");
  page.setAttribute("aria-label", "Découvrir Statoo");
  const top = el("div", "", "onboarding-top");
  top.append(
    el("p", "LE FOOT, ENSEMBLE.", "eyebrow"),
    button("Passer", completeOnboarding, "text-button"),
  );
  const heading = el("h1", onboardingPages[onboardingStep][0]);
  heading.tabIndex = -1;
  const controls = el("div", "", "onboarding-controls");
  if (onboardingStep > 0)
    controls.append(
      button("Précédent", () => {
        onboardingStep--;
        render();
        $("content").querySelector("h1").focus();
      }),
    );
  controls.append(
    button(
      onboardingStep === 2 ? "Commencer" : "Suivant",
      () => {
        if (onboardingStep === 2) completeOnboarding();
        else {
          onboardingStep++;
          render();
          $("content").querySelector("h1").focus();
        }
      },
      "primary",
    ),
  );
  const progress = el("p", `Étape ${onboardingStep + 1} sur 3`, "muted");
  progress.setAttribute("role", "status");
  page.append(
    top,
    footballArt(onboardingStep),
    progress,
    heading,
    el("p", onboardingPages[onboardingStep][1], "lead"),
    controls,
  );
  return page;
}
function auth() {
  const preparation = new RegistrationDraft(client.storage);
  let draft = null,
    draftError = null;
  try {
    draft = preparation.load();
  } catch (error) {
    draftError = error;
  }
  const offline = !navigator.onLine;
  const layout = el("div", "", "welcome"),
    intro = el("section", "", "welcome-copy");
  intro.append(
    el("p", "LE FOOT, ENSEMBLE.", "eyebrow"),
    el("h1", "Votre groupe.\nVotre terrain."),
    el(
      "p",
      "Les séances, les performances et les comptes du groupe, réunis au même endroit.",
      "lead",
    ),
  );
  const chips = el("div", "", "chips");
  for (const label of ["⚽ Matchs & tournois", "↗ Classement", "◈ Finances"])
    chips.append(el("span", label, "chip"));
  intro.append(chips);
  const c = card(
      registration ? "Créer votre groupe" : "Retrouver votre groupe",
    ),
    form = el("form", "", "auth-form");
  c.classList.add("auth-card");
  c.append(
    el(
      "p",
      registration
        ? "Créez votre accès Admin et un accès collectif pour les membres."
        : "Membre : utilisez l’accès collectif. Responsable : utilisez vos identifiants personnels.",
      "muted",
    ),
  );
  const group = registration
    ? null
    : field(form, "Identifiant du groupe", "", {
        required: true,
        maxLength: 100,
      });
  let name, shortName, roster, sharedUser, sharedPassword;
  if (registration) {
    const details = el("fieldset", "", "registration-section group-details");
    details.append(el("legend", "Le groupe"));
    form.append(details);
    name = field(details, "Nom du groupe", draft?.name || "", {
      required: true,
      maxLength: 100,
    });
    shortName = field(
      details,
      "Nom court (facultatif)",
      draft?.short_name || "",
      { maxLength: 30 },
    );
    const shortHelp = el(
      "small",
      "Initiales ou surnom du groupe, utilisés dans l’application. Sans nom court, le nom complet sera affiché.",
      "muted",
    );
    shortHelp.id = "short-name-help";
    shortName.setAttribute("aria-describedby", shortHelp.id);
    shortName.parentElement.append(shortHelp);
    roster = field(details, "Membres du groupe", draft?.roster || "", {
      textarea: true,
      required: true,
    });
    name.disabled = shortName.disabled = roster.disabled = !!draft?.pending;
    details.append(
      el(
        "p",
        "Séparez les noms par une virgule ou un retour à la ligne.",
        "muted",
      ),
    );
    details.append(
      el(
        "p",
        "L’identifiant unique du groupe sera généré automatiquement après sa création.",
        "muted",
      ),
    );
  }
  const credentials = el("div", "", registration ? "registration-access" : "");
  form.append(credentials);
  const adminAccess = registration
    ? el("fieldset", "", "registration-section")
    : credentials;
  if (registration && !offline) {
    adminAccess.append(el("legend", "Votre accès Admin"));
    credentials.append(adminAccess);
  }
  const user =
    registration && offline
      ? null
      : field(
          adminAccess,
          registration ? "Identifiant Admin" : "Identifiant de connexion",
          "",
          { required: true },
        );
  if (user) user.autocomplete = "username";
  const pass =
    registration && offline
      ? null
      : field(
          adminAccess,
          registration ? "Mot de passe Admin" : "Mot de passe",
          "",
          { type: "password", required: true },
        );
  if (pass)
    pass.autocomplete = registration ? "new-password" : "current-password";
  if (registration && !offline) {
    const collectiveAccess = el("fieldset", "", "registration-section");
    collectiveAccess.append(el("legend", "L’accès des membres"));
    credentials.append(collectiveAccess);
    sharedUser = field(collectiveAccess, "Identifiant collectif", "membres", {
      required: true,
    });
    const help = el(
      "small",
      "Identifiant partagé par les membres pour consulter le groupe, sans modifier les données.",
      "muted",
    );
    help.id = "collective-help";
    sharedUser.setAttribute("aria-describedby", help.id);
    sharedUser.parentElement.append(help);
    sharedPassword = field(collectiveAccess, "Mot de passe collectif", "", {
      type: "password",
      required: true,
    });
  }
  const submit = el(
    "button",
    registration
      ? offline
        ? "Enregistrer sur cet appareil"
        : "Créer le groupe"
      : "Se connecter",
    "primary",
  );
  submit.type = "submit";
  prepareBusyButton(submit);
  form.append(submit);
  const errors = el("p", "", "error");
  errors.setAttribute("role", "alert");
  form.append(errors);
  const status = el("p", "", "muted");
  status.setAttribute("role", "status");
  if (registration) {
    const savedMessage = () =>
      offline
        ? "Enregistré sur cet appareil — en attente de connexion."
        : "Préparation enregistrée sur cet appareil. Définissez les accès pour publier le groupe.";
    status.textContent = draft?.pending
      ? "Publication à vérifier. Ressaisissez les mêmes accès pour reprendre sans créer de doublon."
      : draft
        ? savedMessage()
        : "Le nom et les membres peuvent être préparés sans connexion. Les accès seront définis à la publication.";
    form.append(
      status,
      el(
        "small",
        "Cette préparation reste sur cet appareil. Effacer les données du navigateur la supprime.",
        "muted",
      ),
    );
    const save = () => {
      try {
        draft = preparation.save({
          name: name.value,
          short_name: shortName.value,
          roster: roster.value,
        });
        errors.textContent = "";
        status.textContent = savedMessage();
      } catch (error) {
        errors.textContent = error.message;
      }
    };
    if (!draft?.pending) {
      name.addEventListener("input", save);
      shortName.addEventListener("input", save);
      roster.addEventListener("input", save);
      if (!offline) form.append(button("Enregistrer sur cet appareil", save));
    }
    form.append(
      button(
        "Abandonner la préparation",
        () => {
          const warning = draft?.pending
            ? "La publication a peut-être déjà réussi. Vérifiez le groupe existant avant une nouvelle création. Effacer cette préparation ?"
            : "Effacer la préparation enregistrée sur cet appareil ?";
          if (confirm(warning))
            try {
              preparation.clear();
              registration = false;
              render();
            } catch (error) {
              errors.textContent = error.message;
            }
        },
        "text-button",
      ),
    );
  }
  if (draftError) errors.textContent = draftError.message;
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (submit.disabled) return;
    await withBusyButton(submit, async () => {
      clearValidation(form);
      errors.textContent = "";
      let attemptedConnection = false;
      try {
        if (registration && !navigator.onLine) {
          draft = preparation.save({
            name: name.value,
            short_name: shortName.value,
            roster: roster.value,
          });
          status.textContent =
            "Enregistré sur cet appareil — en attente de connexion.";
          return;
        }
        if (configurationError) throw configurationError;
        const members = registration
          ? parseMemberNames(roster.value).map((name) => ({
              id: crypto.randomUUID(),
              name,
              is_active: 1,
            }))
          : [];
        if (registration && !members.length)
          throw Error("Ajoutez au moins un membre.");
        let pending, registrationBody;
        if (registration) {
          if (!draft?.pending)
            draft = preparation.save({
              name: name.value,
              short_name: shortName.value,
              roster: roster.value,
            });
          registrationBody = validate(registrationSchema, {
            name: draft.name,
            short_name: draft.short_name || "",
            operation_id: draft.operation_id,
            username: user.value.trim(),
            password: pass.value,
            shared_username: sharedUser.value.trim(),
            shared_password: sharedPassword.value,
            members: draft.members,
          });
          pending = preparation.prepare(configuredApi);
          draft = pending;
          name.disabled = shortName.disabled = roster.disabled = true;
        }
        if (!registration)
          validate(credentialsSchema, {
            group_id: group.value.trim(),
            username: user.value.trim(),
            password: pass.value,
          });
        attemptedConnection = true;
        await client.connect(
          configuredApi,
          group?.value.trim() || "",
          user.value.trim(),
          pass.value,
          registrationBody,
        );
        if (registration) preparation.clear();
        render();
        message(
          registration
            ? "Groupe créé. Attribuez les rôles Président et Trésorier pour démarrer. Votre accès Admin permet de gérer les séances."
            : "",
        );
        registration = false;
      } catch (error) {
        errors.textContent = error.message;
        showValidation(form, error);
        if (registration && draft?.pending)
          status.textContent =
            "Publication à vérifier. Ressaisissez les mêmes accès pour reprendre sans créer de doublon.";
      } finally {
        if (attemptedConnection && pass) pass.value = "";
        if (attemptedConnection && sharedPassword) sharedPassword.value = "";
      }
    });
    if (registration && draft?.pending)
      name.disabled = shortName.disabled = roster.disabled = true;
  });
  if (!registration && draft)
    c.append(
      button("Reprendre la préparation", () => {
        registration = true;
        render();
      }),
    );
  c.append(
    form,
    button(
      registration ? "J’ai déjà des identifiants" : "Créer un groupe",
      () => {
        registration = !registration;
        render();
      },
      "text-button",
    ),
  );
  layout.append(intro, c);
  return layout;
}
function render({ preserve = false } = {}) {
  if (preserve) return preserveInteraction($("content"), renderContent);
  return renderContent();
}
function renderContent() {
  const identityKey =
    client.connection &&
    JSON.stringify([
      client.connection.api,
      client.connection.group,
      client.connection.account?.id,
    ]);
  if (identityKey !== filtersIdentity) {
    filtersIdentity = identityKey;
    sessionFilters = { status: "all", search: "" };
  }
  const root = $("content");
  root.replaceChildren();
  if (onboardingStep !== null && !client.connection) {
    root.append(onboarding());
    return;
  }
  if (client.storageWarning)
    root.append(el("p", client.storageWarning, "notice error"));
  if (!client.connection || !client.snapshot) {
    root.append(auth());
    return;
  }
  const data = client.snapshot,
    caps = currentCaps(),
    heading = el("div", "", "page-heading"),
    identity = el("div");
  identity.append(
    el("p", "VOTRE GROUPE", "eyebrow"),
    el("h1", data.short_name?.trim() || data.name),
    ...(data.short_name?.trim() ? [el("p", data.name, "muted")] : []),
    el("p", "Identifiant du groupe : " + client.connection.group, "muted"),
    el(
      "p",
      data.account.shared
        ? "Accès collectif · Consultation"
        : data.account.roles.map((r) => roleLabels[r] || r).join(" · "),
      "muted",
    ),
  );
  const actions = el("div", "", "actions");
  actions.append(
    asyncButton("Actualiser", () =>
      run(async () => {
        await client.refresh();
        if (!modal) render({ preserve: true });
        message("Données actualisées.");
      }),
    ),
    asyncButton(
      "Se déconnecter",
      () =>
        run(async () => {
          modal?.close();
          await client.logout();
          render();
          message("Déconnexion effectuée.");
        }),
      "text-button",
    ),
  );
  heading.append(identity, actions);
  root.append(heading);
  const global = el("div", "", "actions quick-actions");
  if (caps.sport)
    global.append(button("Nouvelle séance", () => sportEditor(), "primary"));
  if (caps.finance)
    global.append(button("Nouveau point financier", () => financeEditor()));
  if (caps.admin)
    global.append(
      button("Gérer le groupe", () => {
        tab = "Gestion";
        render();
      }),
    );
  if (caps.arbitrate)
    global.append(
      button("Décisions", () => {
        tab = "Décisions";
        render();
      }),
    );
  root.append(global);
  let pending = [];
  try {
    pending = client.pending();
  } catch (error) {
    root.append(el("p", error.message, "notice error"));
  }
  if (pending.length) {
    const banner = el("div", "", "notice");
    banner.append(
      el(
        "p",
        pending.length +
          " envoi(s) en attente. Ils ne sont pas encore publiés.",
      ),
      asyncButton("Réessayer les envois", () =>
        run(async () => {
          await client.refresh();
          await client.retryPending();
          render();
          message(
            "Envois traités. Vérifiez les éventuels conflits dans les décisions.",
          );
        }),
      ),
    );
    root.append(banner);
  }
  const nav = el("nav");
  nav.setAttribute("aria-label", "Navigation principale");
  for (const [label, symbol] of [
    ["Accueil", "⌂"],
    ["Séances", "⚽"],
    ["Membres", "♧"],
    ["Classement", "↗"],
    ["Finances", "◈"],
  ]) {
    const b = button(
      label,
      () => {
        tab = label;
        render();
      },
      tab === label ? "selected" : "",
    );
    b.dataset.symbol = symbol;
    b.setAttribute("aria-label", label);
    if (tab === label) b.setAttribute("aria-current", "page");
    nav.append(b);
  }
  root.append(nav);
  const content = el("section", "", "page-content");
  root.append(content);
  (
    ({
      Accueil: home,
      Séances: sessions,
      Membres: membersView,
      Classement: ranking,
      Finances: finances,
      Gestion: management,
      Décisions: decisions,
    })[tab] || home
  )(content);
  root.append(
    el(
      "p",
      "Dernière actualisation : " +
        (client.updatedAt ? date(client.updatedAt) : "à actualiser"),
      "sync-time",
    ),
  );
  network();
}
function documents(domain) {
  return Object.values(client.snapshot.documents || {})
    .filter((d) => d.domain === domain)
    .sort((a, b) =>
      String(b.payload.played_at || b.payload.session?.played_at).localeCompare(
        String(a.payload.played_at || a.payload.session?.played_at),
      ),
    );
}
function sessionCard(doc) {
  const s = doc.payload.session,
    c = card(date(s.played_at));
  c.append(
    el(
      "p",
      (s.session_type === "TOURNAMENT_3"
        ? "Tournoi · 3 équipes"
        : "Match · 2 équipes") +
        " · " +
        ({ CLOSED: "Terminée", DRAFT: "En cours", CANCELLED: "Annulée" }[
          s.status
        ] || s.status),
      "eyebrow",
    ),
    sportSummary(doc.payload),
    button("Voir la séance", () => sessionDetail(doc), "text-button"),
  );
  return c;
}
function home(parent) {
  const data = client.snapshot,
    docs = documents("sport"),
    featured =
      docs.find((d) => d.payload.session.status === "DRAFT") ||
      docs.find((d) => d.payload.session.status === "CLOSED");
  parent.append(
    el(
      "h2",
      featured?.payload.session.status === "DRAFT"
        ? "Séance en cours"
        : "Dernière séance",
    ),
  );
  parent.append(
    featured
      ? sessionCard(featured)
      : card("Le terrain vous attend", "Aucune séance publiée pour le moment."),
  );
  const grid = el("div", "", "stats-grid");
  for (const [title, value] of [
    ["Membres", data.members.filter((m) => m.is_active !== 0).length],
    [
      "Séances terminées",
      docs.filter((d) => d.payload.session.status === "CLOSED").length,
    ],
    ["Caisse", money(data.finances.cash)],
  ]) {
    const c = card(title);
    c.append(el("strong", String(value), "stat"));
    grid.append(c);
  }
  parent.append(grid);
  if (currentCaps().admin) {
    const assigned = new Set((data.leaders || []).flatMap((a) => a.roles));
    if (!["PDT", "TR"].every((r) => assigned.has(r)))
      parent.append(
        card(
          "Préparer votre groupe",
          "Attribuez les rôles Président et Trésorier dans Gérer le groupe. Votre accès Admin permet de gérer les séances ; vous pouvez aussi déléguer au Secrétaire général ou à son adjoint. Les soldes initiaux seront proposés par le Trésorier et approuvés par le Président.",
        ),
      );
  }
}
function sessions(parent) {
  parent.append(el("h2", "Les séances du groupe"));
  const controls = el("div", "", "filter-bar"),
    list = el("div", "", "grid");
  function update() {
    list.replaceChildren();
    for (const doc of documents("sport").filter(
      (d) =>
        (sessionFilters.status === "all" ||
          d.payload.session.status === sessionFilters.status) &&
        JSON.stringify([d.occurrence_id, d.payload.session.team_names])
          .toLocaleLowerCase("fr")
          .includes(sessionFilters.search.toLocaleLowerCase("fr")),
    ))
      list.append(sessionCard(doc));
    if (!list.children.length)
      list.append(el("p", "Aucune séance pour ce filtre.", "muted"));
  }
  field(controls, "État", sessionFilters.status, {
    select: [
      ["all", "Toutes"],
      ["DRAFT", "En cours"],
      ["CLOSED", "Terminées"],
      ["CANCELLED", "Annulées"],
    ],
    change: (v) => {
      sessionFilters.status = v;
      update();
    },
  });
  field(controls, "Rechercher une séance", sessionFilters.search, {
    change: (v) => {
      sessionFilters.search = v;
      update();
    },
  });
  parent.append(controls, list);
  update();
}
function sessionDetail(doc) {
  const f = dialog("Détail de la séance");
  f.body.append(
    payloadReview("sport", doc.payload),
    el("p", "Référence : " + doc.occurrence_id, "muted"),
  );
  if (owned(doc, "sport"))
    f.actions.append(
      button("Modifier la séance", () => sportEditor(doc), "primary"),
    );
  else if (currentCaps().sport)
    f.body.append(
      el(
        "p",
        "Cette séance dépend d’un autre responsable ou attend un arbitrage.",
        "muted",
      ),
    );
  if (
    (currentCaps().sport && doc.owner === client.connection.account.id) ||
    currentCaps().arbitrate
  )
    f.actions.append(
      button("Transférer la responsabilité", () => transferEditor(doc)),
    );
  history(f, doc);
}
function history(f, doc) {
  if (doc.history?.length) {
    const details = el("details");
    details.append(el("summary", "Historique des versions"));
    for (const item of doc.history)
      details.append(payloadReview(doc.domain, item.payload));
    f.body.append(details);
  }
}
function membersView(parent) {
  parent.append(el("h2", "Les membres"));
  const list = el("div", "", "grid");
  for (const m of client.snapshot.members) {
    const c = card(
      m.name,
      m.is_active === 0 ? "Archivé" : m.nickname || "Membre du groupe",
    );
    if (currentCaps().admin)
      c.append(
        button("Modifier " + m.name, () => memberEditor(m), "text-button"),
      );
    list.append(c);
  }
  if (currentCaps().admin)
    parent.append(button("Ajouter un membre", () => memberEditor(), "primary"));
  parent.append(list);
}
function ranking(parent) {
  parent.append(
    el("h2", "Classement du groupe"),
    el(
      "p",
      "Les points comptent les séances classées terminées. Les buts et passes incluent aussi les amicaux.",
      "muted",
    ),
    table(
      ["Rang", "Membre", "Points", "Séances", "Buts", "Passes"],
      standings(client.snapshot).map((m, i) => [
        i + 1,
        m.name,
        m.points,
        m.matches,
        m.goals,
        m.assists,
      ]),
    ),
  );
}
function finances(parent) {
  const data = client.snapshot;
  parent.append(el("h2", "Finances du groupe"));
  const cash = card("Caisse disponible");
  cash.classList.add("cash");
  cash.append(
    el("strong", money(data.finances.cash), "stat"),
    el("p", "Encaissements − dépenses, avec solde d’ouverture", "muted"),
  );
  parent.append(
    cash,
    table(
      ["Membre", "Cotisations dues", "Avance", "Pénalités dues"],
      data.members.map((m) => {
        const b = data.finances.members[m.id] || {};
        return [
          m.name,
          money(Math.max(0, -(b.contribution_balance || 0))),
          money(Math.max(0, b.contribution_balance || 0)),
          money(b.penalty_debt),
        ];
      }),
    ),
  );
  const actions = el("div", "", "actions");
  if (currentCaps().settings)
    actions.append(button("Paramètres financiers", financialSettings));
  if (currentCaps().finance && !data.opening)
    actions.append(button("Proposer les soldes initiaux", openingEditor));
  parent.append(actions, el("h3", "Points financiers"));
  const docs = documents("finance"),
    known = new Set(docs.map((d) => d.occurrence_id)),
    entries = [
      ...docs,
      ...Object.entries(data.obligations || {})
        .filter(([id]) => !known.has(id))
        .map(([id, payload]) => ({
          domain: "finance",
          occurrence_id: id,
          payload,
          obligation: true,
        })),
    ];
  for (const doc of entries) {
    const c = card(
      date(doc.payload.played_at),
      doc.occurrence_id + (doc.obligation ? " · À renseigner" : ""),
    );
    c.append(button("Voir le point", () => financeDetail(doc)));
    if (doc.obligation && currentCaps().finance)
      c.append(button("Renseigner le point", () => financeEditor(doc)));
    parent.append(c);
  }
  if (!entries.length)
    parent.append(el("p", "Aucun point financier pour le moment.", "muted"));
}
function financeDetail(doc) {
  const f = dialog("Point financier");
  f.body.append(payloadReview("finance", doc.payload));
  if (doc.obligation ? currentCaps().finance : owned(doc, "finance"))
    f.actions.append(
      button("Modifier le point", () => financeEditor(doc), "primary"),
    );
  if (
    !doc.obligation &&
    ((currentCaps().finance && doc.owner === client.connection.account.id) ||
      currentCaps().arbitrate)
  )
    f.actions.append(
      button("Transférer la responsabilité", () => transferEditor(doc)),
    );
  history(f, doc);
}

function assertDraft(domain, state) {
  if (!Object.hasOwn(state, "baseDocument"))
    throw Error(
      "Ce brouillon ancien ne contient pas sa version d’origine. Relisez la version publiée avant de poursuivre.",
    );
  client.assertCurrentDocument(domain, state.reference, state.baseDocument);
}
function draftNotice(f, domain, id, state) {
  try {
    assertDraft(domain, state);
    return;
  } catch (error) {
    const notice = el("div", "", "notice");
    notice.append(el("p", error.message));
    notice.append(
      button("Relire la version publiée", async () => {
        const current =
          client.snapshot.documents[domain + ":" + state.reference];
        const review = el("div");
        review.append(
          el(
            "p",
            "Abandonner explicitement ce brouillon et repartir de la version publiée ? Les saisies de ce brouillon seront effacées.",
          ),
        );
        if (current) review.append(payloadReview(domain, current.payload));
        else
          review.append(
            el("p", "Aucune version publiée ne correspond à cette référence."),
          );
        if (
          !(await confirmSend("Relire avant d’abandonner le brouillon", review))
        )
          return;
        try {
          client.removeDraft(domain, id);
          if (current && !owned(current, domain)) {
            f.d.close();
            render();
            return;
          }
          if (domain === "sport") sportEditor(current);
          else financeEditor(current);
        } catch (failure) {
          report(failure);
        }
      }),
    );
    f.body.append(notice);
  }
}
function shuffled(values) {
  const result = [...values];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(
      (crypto.getRandomValues(new Uint32Array(1))[0] / 2 ** 32) * (i + 1),
    );
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
async function sportEditor(doc) {
  if (!currentCaps().sport || (doc && !owned(doc, "sport"))) return;
  const id = doc?.occurrence_id || "new",
    saved = client.readDraft("sport", id);
  if (!doc && !saved && catalog.length < 3) {
    message(
      "Le catalogue d’équipes est indisponible. Actualisez la page en ligne.",
      true,
    );
    return;
  }
  const names = shuffled(catalog).slice(0, 3),
    now = localDate();
  const state = saved || {
    baseDocument: doc
      ? { revision: doc.revision, generation: doc.generation, owner: doc.owner }
      : null,
    reference: doc?.occurrence_id || newReference(client.snapshot, now),
    reason: "",
    payload: doc
      ? structuredClone(doc.payload)
      : {
          session: {
            id: crypto.randomUUID(),
            team_id: client.connection.group,
            played_at: now,
            status: "DRAFT",
            session_type: "CLASSIC_2",
            is_ranked: 1,
            allow_uneven_teams: 0,
            draw_points: 1,
            score_a: 0,
            score_b: 0,
            wins_a: 0,
            wins_b: 0,
            wins_c: 0,
            team_names: Object.fromEntries(
              ["A", "B", "C"].map((team, i) => [team, names[i]]),
            ),
            team_colors: {
              A: palette.Bleu,
              B: palette.Orange,
              C: palette.Vert,
            },
            notes: "",
          },
          participations: [],
        },
  };
  state.step =
    Number.isInteger(state.step) && state.step >= 0 && state.step <= 3
      ? state.step
      : doc
        ? 3
        : 0;
  state.removedParticipants ??= {};
  const s = state.payload.session;
  s.team_names = objectMap(s.team_names);
  s.team_colors = objectMap(s.team_colors);
  ["A", "B", "C"].forEach((team, i) => {
    s.team_names[team] ??= "Équipe " + team;
    s.team_colors[team] ??= Object.values(palette)[i];
  });
  const f = dialog(doc ? "Modifier la séance" : "Nouvelle séance");
  f.d.classList.add("sport-dialog");
  f.d.setAttribute(
    "aria-label",
    doc ? "Modifier la séance" : "Nouvelle séance",
  );
  const navigation = el("nav", "", "sport-steps");
  navigation.setAttribute("aria-label", "Étapes de la séance");
  f.d.insertBefore(navigation, f.form);
  const labels = ["Options", "Présents", "Équipes", "Match"];
  let search = "",
    expandedPlayer = null,
    storageError = client.storageWarning || null;
  const storageStatus = el("p");
  function updateStorageStatus() {
    storageStatus.textContent = storageError
      ? "Préparation non enregistrée : le stockage local est indisponible."
      : "Préparation conservée sur cet appareil. « Enregistrer le brouillon » la publie pour le groupe.";
    storageStatus.className = storageError ? "error" : "muted";
  }
  const historical = new Set(
    (doc?.payload.participations || []).map((p) => p.player_id),
  );
  const teams = () =>
    s.session_type === "TOURNAMENT_3" ? ["A", "B", "C"] : ["A", "B"];
  const participant = (memberId) =>
    state.payload.participations.find((p) => p.player_id === memberId);
  function save() {
    const previousError = storageError;
    try {
      client.saveDraft("sport", id, state);
      storageError = null;
      if (previousError && f.errors.textContent === previousError)
        f.errors.textContent = "";
    } catch (error) {
      storageError = error.message;
      f.errors.textContent = error.message;
    }
    updateStorageStatus();
  }
  function select(member, selected) {
    const part = participant(member.id);
    if (selected && !part) {
      const previous = state.removedParticipants[member.id];
      const restored = previous || {
        id: crypto.randomUUID(),
        session_id: s.id,
        player_id: member.id,
        team: "",
        goals: 0,
        assists: 0,
        yellow_cards: 0,
        red_cards: 0,
      };
      if (!teams().includes(restored.team)) restored.team = "";
      state.payload.participations.push(restored);
      delete state.removedParticipants[member.id];
    } else if (!selected && part) {
      state.removedParticipants[member.id] = part;
      state.payload.participations = state.payload.participations.filter(
        (p) => p !== part,
      );
    }
  }
  function go(index) {
    if (index > state.step && state.step === 0 && !f.form.reportValidity())
      return;
    state.step = index;
    expandedPlayer = null;
    f.errors.textContent = "";
    save();
    paint();
    f.body.querySelector(".sport-step-title")?.focus({ preventScroll: true });
    f.body.scrollTop = 0;
  }
  function counter(parent, label, noun, value, change) {
    const group = el("div", "", "sport-counter");
    const minus = button("−", () => adjust(-1)),
      plus = button("+", () => adjust(1));
    minus.setAttribute("aria-label", "Diminuer " + noun);
    plus.setAttribute("aria-label", "Augmenter " + noun);
    const input = field(group, label, value ?? 0, {
      type: "number",
      min: 0,
      change: (v) => {
        change(v);
        save();
        update();
      },
    });
    const row = el("div", "", "sport-counter-controls");
    const caption = group.querySelector("label");
    input.id = "sport-counter-" + crypto.randomUUID();
    caption.htmlFor = input.id;
    row.append(minus, input, plus);
    group.append(row);
    function update() {
      minus.disabled = Number(input.value) === 0;
    }
    function adjust(delta) {
      try {
        const number = integer(input.value, label);
        const next = integer(Math.max(0, number + delta), label);
        input.value = next;
        change(next);
        save();
        update();
      } catch (error) {
        f.errors.textContent = error.message;
      }
    }
    update();
    parent.append(group);
  }
  function options() {
    const grid = el("div", "", "form-grid");
    const reference = field(grid, "Référence de la séance", state.reference, {
      required: true,
      maxLength: 150,
      change: (value) => {
        state.reference = value;
        save();
      },
    });
    reference.readOnly = !!doc;
    const dateGrid = el("div", "", "form-grid");
    field(dateGrid, "Date et heure", s.played_at.slice(0, 16), {
      type: "datetime-local",
      required: true,
      change: (value) => {
        s.played_at = value;
        if (!doc && value) {
          state.reference = newReference(client.snapshot, value);
          reference.value = state.reference;
        }
        save();
      },
    });
    field(dateGrid, "Format de jeu", s.session_type, {
      select: [
        ["CLASSIC_2", "Match · 2 équipes"],
        ["TOURNAMENT_3", "Tournoi · 3 équipes"],
      ],
      change: (value) => {
        s.session_type = value;
        state.payload.participations.forEach((p) => {
          if (!teams().includes(p.team)) p.team = "";
        });
        save();
        paint();
      },
    });
    f.body.append(dateGrid);
    check(f.body, "Séance classée", s.is_ranked, (value) => {
      s.is_ranked = value ? 1 : 0;
      save();
    });
    check(
      f.body,
      "Autoriser les équipes inégales",
      s.allow_uneven_teams,
      (value) => {
        s.allow_uneven_teams = value ? 1 : 0;
        save();
      },
    );
    if (s.session_type === "TOURNAMENT_3")
      field(grid, "Points pour un nul", s.draw_points, {
        type: "number",
        min: 0,
        change: (value) => {
          s.draw_points = value;
          save();
        },
      });
    f.body.append(
      grid,
      el(
        "p",
        "Les noms des équipes sont attribués au hasard. Vous choisirez leurs couleurs à l’étape Équipes.",
        "muted",
      ),
    );
  }
  function presents() {
    const roster = client.snapshot.members.filter(
      (m) =>
        m.is_active !== 0 ||
        historical.has(m.id) ||
        participant(m.id) ||
        Object.hasOwn(state.removedParticipants, m.id),
    );
    const normalize = (value) =>
      String(value)
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLocaleLowerCase("fr");
    const count = el("p", "", "notice");
    count.setAttribute("role", "status");
    const list = el("div", "", "sport-roster");
    let visible = [];
    const controls = el("div", "", "actions");
    const choose = button("Sélectionner les joueurs affichés", () => {
      visible.filter((m) => m.is_active !== 0).forEach((m) => select(m, true));
      save();
      paint();
    });
    const clear = button("Désélectionner les joueurs affichés", () => {
      visible.forEach((m) => select(m, false));
      save();
      paint();
    });
    controls.append(choose, clear);
    field(f.body, "Rechercher un joueur", search, {
      type: "search",
      change: (value) => {
        search = value;
        update();
      },
    });
    f.body.append(
      count,
      controls,
      el(
        "p",
        "La sélection collective concerne les joueurs affichés. Vos autres sélections sont conservées.",
        "muted",
      ),
      list,
    );
    function update() {
      const n = state.payload.participations.length;
      count.textContent =
        n +
        " présent" +
        (n === 1 ? "" : "s") +
        " · Minimum pour clôturer : " +
        (client.snapshot.sport_settings?.min_players_per_session ?? 6);
      visible = roster.filter((m) =>
        normalize(m.name + " " + (m.nickname || "")).includes(
          normalize(search.trim()),
        ),
      );
      choose.disabled = !visible.some((m) => m.is_active !== 0);
      clear.disabled = !visible.some((m) => participant(m.id));
      list.replaceChildren();
      for (const member of visible) {
        const row = el("div", "", "sport-presence");
        check(
          row,
          "Présent : " + member.name,
          !!participant(member.id),
          (checked) => {
            select(member, checked);
            save();
            paint();
          },
        );
        if (member.is_active === 0)
          row.append(el("small", "Archivé · historique de la séance", "muted"));
        list.append(row);
      }
      if (!roster.length)
        list.append(
          el("p", "Aucun membre actif dans ce groupe."),
          el(
            "p",
            "L’Admin peut ajouter des membres depuis Gérer le groupe.",
            "muted",
          ),
        );
      else if (!visible.length)
        list.append(el("p", "Aucun joueur pour cette recherche.", "muted"));
    }
    update();
  }
  function composition() {
    const counts = el("div", "", "sport-team-counts"),
      grid = el("div", "", "sport-team-grid");
    function updateCounts() {
      counts.replaceChildren();
      for (const team of teams())
        counts.append(
          el(
            "p",
            "Équipe " +
              team +
              " · " +
              state.payload.participations.filter((p) => p.team === team)
                .length +
              " joueur(s)",
            "chip",
          ),
        );
      counts.append(
        el(
          "p",
          "À placer · " +
            state.payload.participations.filter(
              (p) => !teams().includes(p.team),
            ).length,
          "chip",
        ),
      );
    }
    f.body.append(
      counts,
      button("Répartir les joueurs", () => {
        shuffled(state.payload.participations).forEach((p, i) => {
          p.team = teams()[i % teams().length];
        });
        save();
        paint();
      }),
      el(
        "p",
        "La répartition équilibre le nombre de joueurs. Vous pouvez ensuite ajuster chaque équipe.",
        "muted",
      ),
    );
    for (const team of teams()) {
      const c = card(s.team_names[team]);
      field(c, "Couleur " + team, String(s.team_colors[team]), {
        select: Object.entries(palette).map(([name, value]) => [
          String(value),
          name,
        ]),
        change: (value) => {
          s.team_colors[team] = Number(value);
          save();
        },
      });
      grid.append(c);
    }
    f.body.append(grid);
    for (const part of state.payload.participations)
      field(f.body, "Équipe de " + memberName(part.player_id), part.team, {
        select: [
          ["", "À placer"],
          ...teams().map((team) => [team, team + " · " + s.team_names[team]]),
        ],
        change: (value) => {
          part.team = value;
          save();
          updateCounts();
        },
      });
    if (!state.payload.participations.length)
      f.body.append(
        el("p", "Sélectionnez les présents à l’étape précédente.", "muted"),
      );
    updateCounts();
  }
  function match() {
    const scoreboard = el("div", "", "sport-team-grid");
    for (const team of teams()) {
      const c = card(s.team_names[team]);
      const tournament = s.session_type === "TOURNAMENT_3",
        key = (tournament ? "wins_" : "score_") + team.toLowerCase();
      counter(
        c,
        (tournament ? "Victoires " : "Score ") + team,
        (tournament ? "les victoires " : "le score ") + team,
        s[key],
        (value) => {
          s[key] = value;
        },
      );
      scoreboard.append(c);
    }
    f.body.append(
      scoreboard,
      el(
        "p",
        "Choisissez un joueur pour saisir ses buts, passes et cartons. Les modifications restent sur cet appareil jusqu’à confirmation de l’envoi.",
        "muted",
      ),
    );
    for (const team of [...teams(), ""]) {
      const parts = state.payload.participations.filter(
        (p) => (teams().includes(p.team) ? p.team : "") === team,
      );
      if (!parts.length) continue;
      const group = card(team ? s.team_names[team] : "À placer");
      for (const part of parts) {
        const name = memberName(part.player_id),
          row = el("div", "", "sport-player-row");
        const edit = button(
          "Statistiques",
          () => {
            expandedPlayer =
              expandedPlayer === part.player_id ? null : part.player_id;
            paint();
          },
          "text-button",
        );
        edit.setAttribute("aria-label", "Modifier les statistiques de " + name);
        edit.setAttribute(
          "aria-expanded",
          String(expandedPlayer === part.player_id),
        );
        row.append(el("strong", name), edit);
        group.append(row);
        if (expandedPlayer === part.player_id) {
          const details = el("div", "", "sport-player-stats");
          for (const [label, key] of [
            ["Buts", "goals"],
            ["Passes", "assists"],
            ["Jaunes", "yellow_cards"],
            ["Rouges", "red_cards"],
          ])
            counter(
              details,
              label + " de " + name,
              "les " + label.toLocaleLowerCase("fr") + " de " + name,
              part[key],
              (value) => {
                part[key] = value;
              },
            );
          group.append(details);
        } else
          group.append(
            el(
              "p",
              [
                "⚽ " + (part.goals || 0),
                "Passes " + (part.assists || 0),
                "Jaunes " + (part.yellow_cards || 0),
                "Rouges " + (part.red_cards || 0),
              ].join(" · "),
              "muted",
            ),
          );
      }
      f.body.append(group);
    }
    if (!state.payload.participations.length)
      f.body.append(
        el(
          "p",
          "Aucun présent sélectionné. Complétez les étapes Présents et Équipes.",
          "notice",
        ),
      );
    field(f.body, "Notes de la séance", s.notes || "", {
      textarea: true,
      change: (value) => {
        s.notes = value;
        save();
      },
    });
    if (doc)
      field(f.body, "Motif de correction", state.reason, {
        required: true,
        change: (value) => {
          state.reason = value;
          save();
        },
      });
  }
  function paint() {
    preserveInteraction(f.body, () => {
      navigation.replaceChildren();
      labels.forEach((label, index) => {
        const b = button(
          index + 1 + " · " + label,
          () => go(index),
          state.step === index ? "selected" : "secondary",
        );
        if (state.step === index) b.setAttribute("aria-current", "step");
        navigation.append(b);
      });
      f.body.replaceChildren();
      draftNotice(f, "sport", id, state);
      const title = el(
        "h3",
        [
          "Options de la séance",
          "Les présents",
          "Composition des équipes",
          "Le match",
        ][state.step],
        "sport-step-title",
      );
      title.tabIndex = -1;
      f.body.append(
        el("p", "Étape " + (state.step + 1) + " sur 4", "eyebrow"),
        title,
      );
      [options, presents, composition, match][state.step]();
      updateStorageStatus();
      f.body.append(storageStatus);
      previous.hidden = state.step === 0;
      next.hidden = state.step === 3;
      close.hidden = state.step !== 3;
    });
  }
  async function send(status) {
    assertDraft("sport", state);
    let payload;
    try {
      if (!state.reference.trim())
        throw Error("Référence de la séance requise.");
      payload = prepareSport(
        state.payload,
        client.snapshot.members,
        status,
        client.snapshot.sport_settings?.min_players_per_session ?? 6,
      );
      if (doc && !state.reason.trim())
        throw Error("Motif de correction requis.");
    } catch (error) {
      const target = /date|référence|points du nul/i.test(error.message)
        ? 0
        : /minimum|joueurs présents/i.test(error.message)
          ? 1
          : /équipe|participant|couleur|nom différent/i.test(error.message)
            ? 2
            : 3;
      if (state.step !== target) expandedPlayer = null;
      state.step = target;
      save();
      paint();
      f.body.scrollTop = 0;
      throw error;
    }
    const preview = payloadReview("sport", payload);
    preview.prepend(el("p", "Référence : " + state.reference));
    if (
      !(await confirmSend(
        status === "CANCELLED"
          ? "Annuler cette séance ?"
          : "Vérifier la séance",
        preview,
      ))
    )
      return;
    const result = await client.send(
      "sport",
      state.reference,
      payload,
      state.baseDocument,
      state.reason,
    );
    client.removeDraft("sport", id);
    f.d.close();
    render();
    message(
      result.status === "conflict"
        ? "Version concurrente envoyée : arbitrage nécessaire."
        : client.refreshWarning || "Données publiées.",
    );
  }
  const previous = button("Précédent", () => go(state.step - 1));
  const next = button("Suivant", () => go(state.step + 1), "primary");
  f.actions.append(previous, next);
  const publishDraft = f.submit("Enregistrer le brouillon", () =>
    send("DRAFT"),
  );
  publishDraft.className = "secondary";
  const close = f.submit("Clôturer la séance", () => send("CLOSED"));
  if (doc) f.submit("Annuler la séance", () => send("CANCELLED"));
  paint();
}

function financeEditor(doc) {
  if (
    !currentCaps().finance ||
    (!doc?.obligation && doc && !owned(doc, "finance"))
  )
    return;
  if (!client.snapshot.opening) {
    const f = dialog("Initialiser les finances");
    f.body.append(
      el(
        "p",
        "Les soldes initiaux doivent être proposés puis approuvés avant le premier point financier.",
      ),
    );
    f.actions.append(
      button("Proposer les soldes initiaux", openingEditor, "primary"),
    );
    return;
  }
  const id = doc?.occurrence_id || "new",
    now = localDate(),
    saved = client.readDraft("finance", id);
  const state = saved || {
    baseDocument:
      doc && !doc.obligation
        ? {
            revision: doc.revision,
            generation: doc.generation,
            owner: doc.owner,
          }
        : null,
    reference: doc?.occurrence_id || newReference(client.snapshot, now),
    reason: "",
    payload: doc
      ? structuredClone(doc.payload)
      : {
          played_at: now,
          rate: client.snapshot.financial_settings?.contribution ?? 100,
          cancelled: false,
          lines: client.snapshot.members
            .filter((m) => m.is_active !== 0)
            .map((m) => ({
              member_id: m.id,
              contribution: 0,
              penalty_paid: 0,
              penalty_due: 0,
              reason: "",
            })),
          expenses: [],
          donations: [],
        },
  };
  const p = state.payload,
    roster = p.lines.map((l) => l.member_id),
    f = dialog(doc ? "Modifier le point financier" : "Nouveau point financier");
  function save() {
    try {
      client.saveDraft("finance", id, state);
    } catch (error) {
      f.errors.textContent = error.message;
    }
  }
  function paint() {
    return preserveInteraction(f.body, paintContent);
  }
  function paintContent() {
    f.body.replaceChildren();
    draftNotice(f, "finance", id, state);
    if (!doc) {
      const choices = [
        ["new", "Nouvelle échéance indépendante"],
        ...Object.entries(client.snapshot.obligations || {})
          .filter(([ref]) => !client.snapshot.documents["finance:" + ref])
          .map(([ref]) => [ref, ref]),
      ];
      field(f.body, "Échéance", "new", {
        select: choices,
        change: (v) => {
          if (v !== "new")
            financeEditor({
              domain: "finance",
              occurrence_id: v,
              payload: client.snapshot.obligations[v],
              obligation: true,
            });
        },
      });
    }
    const top = el("div", "", "form-grid");
    field(top, "Date du point", p.played_at.slice(0, 16), {
      type: "datetime-local",
      required: true,
      change: (v) => {
        p.played_at = v;
        save();
      },
    });
    const ref = field(top, "Référence de l’échéance", state.reference, {
      required: true,
      change: (v) => {
        state.reference = v;
        save();
      },
    });
    ref.readOnly = !!doc;
    field(top, "Cotisation de l’échéance", p.rate, {
      type: "number",
      min: 0,
      change: (v) => {
        p.rate = v;
        save();
      },
    }).readOnly = !!doc;
    f.body.append(top);
    if (p.cancelled)
      f.body.append(
        el(
          "p",
          "Échéance annulée : cotisation due, aucun encaissement ni nouvelle pénalité.",
          "notice",
        ),
      );
    f.body.append(
      el(
        "p",
        "Tous les membres de cette échéance doivent une cotisation, même absents. Les avances ne règlent pas les pénalités.",
        "muted",
      ),
    );
    for (const line of p.lines) {
      const c = card(memberName(line.member_id)),
        grid = el("div", "", "form-grid");
      for (const [label, key] of [
        ["Cotisation", "contribution"],
        ["Pénalités réglées", "penalty_paid"],
        ["Pénalités dues", "penalty_due"],
      ]) {
        const input = field(
          grid,
          label + " de " + memberName(line.member_id),
          line[key],
          {
            type: "number",
            min: 0,
            change: (v) => {
              line[key] = v;
              save();
            },
          },
        );
        input.disabled = p.cancelled;
      }
      field(
        grid,
        "Motif de pénalité de " + memberName(line.member_id),
        line.reason,
        {
          change: (v) => {
            line.reason = v;
            save();
          },
        },
      );
      c.append(grid);
      f.body.append(c);
    }
    for (const [key, title, singular] of [
      ["expenses", "Dépenses", "dépense"],
      ["donations", "Dons", "don"],
    ]) {
      f.body.append(el("h3", title));
      p[key].forEach((movement, i) => {
        const c = card(title + " " + (i + 1)),
          grid = el("div", "", "form-grid");
        field(
          grid,
          "Libellé " +
            (key === "expenses" ? "de la dépense " : "du don ") +
            (i + 1),
          movement.label,
          {
            required: true,
            maxLength: 200,
            change: (v) => {
              movement.label = v;
              save();
            },
          },
        );
        field(
          grid,
          "Montant " +
            (key === "expenses" ? "de la dépense " : "du don ") +
            (i + 1),
          movement.amount,
          {
            type: "number",
            min: 0,
            change: (v) => {
              movement.amount = v;
              save();
            },
          },
        );
        c.append(
          grid,
          button(
            "Retirer " + singular + " " + (i + 1),
            () => {
              p[key].splice(i, 1);
              save();
              paint();
              [...f.body.querySelectorAll("button")]
                .find(
                  (node) =>
                    node.textContent ===
                    "Ajouter " +
                      (key === "expenses" ? "une dépense" : "un don"),
                )
                ?.focus({ preventScroll: true });
            },
            "text-button",
          ),
        );
        f.body.append(c);
      });
      if (!p.cancelled)
        f.body.append(
          button(
            "Ajouter " + (key === "expenses" ? "une dépense" : "un don"),
            () => {
              p[key].push({ id: crypto.randomUUID(), label: "", amount: 0 });
              save();
              paint();
            },
          ),
        );
    }
    if (doc && !doc.obligation)
      field(f.body, "Motif de correction", state.reason, {
        required: true,
        change: (v) => {
          state.reason = v;
          save();
        },
      });
    f.body.append(el("p", "Brouillon conservé sur cet appareil.", "muted"));
  }
  f.submit("Valider le point", async () => {
    assertDraft("finance", state);
    const payload = prepareFinance(p, roster);
    if (
      !doc &&
      (client.snapshot.documents["finance:" + state.reference] ||
        client.snapshot.obligations[state.reference])
    )
      throw Error(
        "Choisissez l’échéance existante dans la liste pour la renseigner.",
      );
    if (
      !(await confirmSend(
        "Vérifier les encaissements et dépenses",
        payloadReview("finance", payload),
      ))
    )
      return;
    const result = await client.send(
      "finance",
      state.reference,
      payload,
      state.baseDocument,
      state.reason,
    );
    client.removeDraft("finance", id);
    f.d.close();
    render();
    message(
      result.status === "conflict"
        ? "Version concurrente envoyée : arbitrage nécessaire."
        : client.refreshWarning || "Données publiées.",
    );
  });
  paint();
}
function memberEditor(member) {
  if (!currentCaps().admin) return;
  mutationForm(
    member ? "Modifier un membre" : "Ajouter un membre",
    "/members",
    (parent) => {
      const name = field(parent, "Nom du membre", member?.name || "", {
          required: true,
          maxLength: 100,
        }),
        nickname = field(parent, "Surnom", member?.nickname || "");
      let active = member?.is_active !== 0;
      check(parent, "Membre actif", active, (v) => (active = v));
      return () => {
        const value = {
          ...member,
          id: member?.id || crypto.randomUUID(),
          name: name.value.trim(),
          nickname: nickname.value.trim(),
          is_active: active ? 1 : 0,
        };
        if (!value.name) throw Error("Nom requis.");
        return member
          ? client.snapshot.members.map((m) => (m.id === member.id ? value : m))
          : [...client.snapshot.members, value];
      };
    },
    "PUT",
  );
}
function management(parent) {
  if (!currentCaps().admin) {
    parent.append(el("p", "Accès Admin requis."));
    return;
  }
  parent.append(
    el("h2", "Gérer le groupe"),
    el(
      "p",
      "Les simples membres utilisent l’accès collectif en lecture seule. Les comptes individuels sont réservés aux responsables.",
      "muted",
    ),
  );
  const actions = el("div", "", "actions");
  actions.append(
    button("Ajouter un gestionnaire", () => accountEditor(), "primary"),
    button("Ajouter un membre", () => memberEditor()),
    button("Renouveler l’accès collectif", rotateAccess),
    button("Paramètres sportifs", sportSettings),
  );
  if (currentCaps().settings)
    actions.append(button("Paramètres financiers", financialSettings));
  parent.append(actions);
  const list = el("div", "", "grid");
  for (const account of client.snapshot.accounts || []) {
    const c = card(
      account.username,
      account.shared
        ? "Accès collectif · Lecture seule"
        : account.roles.map((r) => roleLabels[r] || r).join(" · "),
    );
    if (!account.shared)
      c.append(
        button("Modifier les rôles de " + account.username, () =>
          accountEditor(account),
        ),
      );
    list.append(c);
  }
  parent.append(list);
}
function accountEditor(account) {
  if (!currentCaps().admin) return;
  const f = dialog(
    account ? "Attribuer ou transférer les rôles" : "Ajouter un gestionnaire",
  );
  let member = account?.member_id || "",
    roles = new Set(account?.roles.filter((r) => r !== "MEMBER") || []),
    transfer = false;
  let username, password;
  if (!account) {
    field(f.body, "Membre du compte", member, {
      select: [
        ["", "Choisir un membre"],
        ...client.snapshot.members.map((m) => [m.id, m.name]),
      ],
      change: (v) => {
        member = v;
        update();
      },
    });
    username = field(f.body, "Identifiant personnel", "", { required: true });
    password = field(f.body, "Mot de passe personnel", "", {
      type: "password",
      required: true,
    });
  }
  for (const role of responsibleRoles.filter((r) => account || r !== "ADMIN"))
    check(f.body, roleLabels[role], roles.has(role), (checked) => {
      checked ? roles.add(role) : roles.delete(role);
      update();
    });
  let reason;
  if (account) {
    check(
      f.body,
      "Confirmer le transfert des rôles déjà attribués",
      false,
      (v) => (transfer = v),
    );
    reason = field(f.body, "Motif du changement", "", { required: true });
  } else
    f.body.append(
      el("p", "Sélectionnez au moins un rôle de responsable.", "muted"),
    );
  const submit = f.submit(
    account ? "Enregistrer les rôles" : "Créer le compte",
    async () => {
      const body = account
        ? { roles: [...roles], transfer, reason: reason.value.trim() }
        : {
            username: username.value.trim(),
            password: password.value,
            member_id: member,
            roles: [...roles],
          };
      validateMutation(
        account
          ? "/accounts/" + encodeURIComponent(account.id) + "/roles"
          : "/accounts",
        body,
      );
      if (!account && (!member || !roles.size))
        throw Error("Membre et responsabilité requis.");
      if (
        !(await confirmSend(
          "Vérifier le compte et ses rôles",
          summaryValues(body),
        ))
      )
        return;
      await client.mutate(
        account
          ? "/accounts/" + encodeURIComponent(account.id) + "/roles"
          : "/accounts",
        body,
        account ? "PUT" : "POST",
      );
      if (password) password.value = "";
      f.d.close();
      render();
      message(client.refreshWarning || "Modification enregistrée.");
    },
  );
  function update() {
    submit.disabled = !account && (!member || !roles.size);
  }
  update();
}
function rotateAccess() {
  if (!currentCaps().admin) return;
  mutationForm(
    "Renouveler l’accès collectif",
    "/shared-access",
    (parent) => {
      parent.append(
        el(
          "p",
          "Les connexions collectives actuelles seront révoquées. Communiquez les nouveaux identifiants aux membres.",
          "notice",
        ),
      );
      const username = field(parent, "Nouvel identifiant collectif", "", {
          required: true,
        }),
        password = field(parent, "Nouveau mot de passe collectif", "", {
          type: "password",
          required: true,
        });
      return () => ({
        group_id: client.connection.group,
        username: username.value.trim(),
        password: password.value,
      });
    },
    "PUT",
  );
}
function sportSettings() {
  if (!currentCaps().admin) return;
  mutationForm(
    "Paramètres sportifs",
    "/sport-settings",
    (parent) => {
      const minimum = field(
        parent,
        "Minimum de joueurs par séance",
        client.snapshot.sport_settings?.min_players_per_session ?? 6,
        { type: "number", min: 2 },
      );
      minimum.max = "30";
      parent.append(
        el(
          "p",
          "Règle commune au groupe, appliquée sur le web et le mobile. Entre 2 et 30 joueurs.",
          "muted",
        ),
      );
      return () => ({
        min_players_per_session: integer(minimum.value, "Minimum de joueurs"),
      });
    },
    "PUT",
  );
}
function financialSettings() {
  if (!currentCaps().settings) return;
  mutationForm(
    "Paramètres financiers",
    "/financial-settings",
    (parent) => {
      parent.append(
        el(
          "p",
          "Ces montants concernent les nouvelles échéances ; les taux historiques restent conservés.",
          "muted",
        ),
      );
      const s = client.snapshot.financial_settings || {},
        rate = field(parent, "Cotisation par défaut", s.contribution ?? 100, {
          type: "number",
          min: 0,
        }),
        late = field(
          parent,
          "Pénalité de retard par défaut",
          s.late_penalty ?? 0,
          { type: "number", min: 0 },
        );
      return () => ({
        contribution: integer(rate.value, "Cotisation"),
        late_penalty: integer(late.value, "Retard"),
      });
    },
    "PUT",
  );
}
function openingEditor() {
  if (!currentCaps().finance || client.snapshot.opening) return;
  const f = dialog("Proposer les soldes initiaux"),
    p = structuredClone(
      client.readDraft("opening", "proposal") ||
        client.snapshot.opening_proposal || {
          cash: 0,
          start_date: null,
          members: {},
        },
    );
  function saveOpening() {
    try {
      client.saveDraft("opening", "proposal", p);
    } catch (error) {
      f.errors.textContent = error.message;
    }
  }
  field(f.body, "Caisse initiale", p.cash, {
    type: "number",
    min: 0,
    change: (v) => {
      p.cash = v;
      saveOpening();
    },
  });
  field(f.body, "Date de début des comptes", p.start_date || "", {
    type: "date",
    change: (v) => {
      p.start_date = v || null;
      saveOpening();
    },
  });
  f.body.append(
    el(
      "p",
      "Cotisation : positif pour une avance, négatif pour une dette. Les pénalités dues restent séparées.",
      "muted",
    ),
  );
  for (const m of client.snapshot.members) {
    const balance = p.members[m.id] || {
      contribution_balance: 0,
      penalty_debt: 0,
    };
    p.members[m.id] = balance;
    const c = card(m.name);
    field(c, "Avance ou dette de " + m.name, balance.contribution_balance, {
      type: "number",
      change: (v) => {
        balance.contribution_balance = v;
        saveOpening();
      },
    });
    field(c, "Pénalités initiales de " + m.name, balance.penalty_debt, {
      type: "number",
      min: 0,
      change: (v) => {
        balance.penalty_debt = v;
        saveOpening();
      },
    });
    f.body.append(c);
  }
  f.submit("Soumettre les soldes", async () => {
    p.cash = integer(p.cash, "Caisse");
    for (const b of Object.values(p.members)) {
      b.contribution_balance = integer(
        b.contribution_balance,
        "Avance ou dette",
        true,
      );
      b.penalty_debt = integer(b.penalty_debt, "Pénalité");
    }
    validateMutation("/opening", p);
    if (!(await confirmSend("Vérifier les soldes proposés", openingReview(p))))
      return;
    await client.mutate("/opening", p);
    client.removeDraft("opening", "proposal");
    f.d.close();
    render();
    message(
      client.refreshWarning ||
        "Proposition envoyée au Président ou Vice-président.",
    );
  });
}
function decisions(parent) {
  if (!currentCaps().arbitrate) {
    parent.append(el("p", "Accès Président ou Vice-président requis."));
    return;
  }
  parent.append(el("h2", "Décisions du groupe"));
  if (client.snapshot.opening_proposal && !client.snapshot.opening)
    parent.append(
      button("Vérifier les soldes initiaux", approveOpening, "primary"),
    );
  let count = 0;
  for (const doc of Object.values(client.snapshot.documents)) {
    if (doc.candidates?.length) {
      count++;
      const c = card(
        "Conflit " + (doc.domain === "sport" ? "sportif" : "financier"),
        doc.occurrence_id,
      );
      c.append(button("Comparer les versions", () => conflictEditor(doc)));
      parent.append(c);
    }
  }
  if (!count)
    parent.append(
      card(
        "Aucun conflit à traiter",
        "Les versions publiées sont disponibles dans Séances et Finances.",
      ),
    );
}
function approveOpening() {
  const p = structuredClone(client.snapshot.opening_proposal);
  if (!currentCaps().arbitrate || !p) return;
  const f = dialog("Vérifier les soldes initiaux");
  f.body.append(openingReview(p));
  f.submit("Approuver ces soldes", async () => {
    validateMutation("/opening/approve", { proposal: p });
    if (
      !(await confirmSend(
        "Approuver définitivement les soldes ?",
        openingReview(p),
      ))
    )
      return;
    await client.mutate("/opening/approve", { proposal: p });
    f.d.close();
    render();
    message(client.refreshWarning || "Modification enregistrée.");
  });
}
function conflictEditor(doc) {
  if (!currentCaps().arbitrate) return;
  const f = dialog("Comparer les versions"),
    versions = [
      { id: "current", actor: doc.owner, payload: doc.payload },
      ...doc.candidates,
    ];
  let choice = "";
  const radios = el("div");
  for (const version of versions) {
    const c = card(
      version.id === "current" ? "Version publiée" : "Version proposée",
      client.snapshot.leaders?.find((a) => a.id === version.actor)?.username ||
        "Responsable",
    );
    if (version.reason) c.append(el("p", "Motif : " + version.reason));
    c.append(payloadReview(doc.domain, version.payload));
    const label = el("label", "", "check"),
      input = document.createElement("input");
    input.type = "radio";
    input.name = "version";
    input.value = version.id;
    input.addEventListener("change", () => (choice = version.id));
    label.append(
      input,
      el(
        "span",
        version.id === "current"
          ? "Conserver la version publiée"
          : "Retenir cette version",
      ),
    );
    c.append(label);
    radios.append(c);
  }
  f.body.append(radios);
  const reason = field(f.body, "Motif de la décision", "", { required: true });
  f.submit("Valider la décision", async () => {
    if (!choice) throw Error("Choisissez explicitement une version.");
    const selected = versions.find((v) => v.id === choice),
      preview = payloadReview(doc.domain, selected.payload);
    preview.prepend(el("p", "Motif : " + reason.value));
    validateMutation(groupPath(doc) + "/resolve", {
      revision: doc.revision,
      candidate_id: choice,
      reason: reason.value.trim(),
    });
    if (!(await confirmSend("Vérifier la version retenue", preview))) return;
    await client.mutate(groupPath(doc) + "/resolve", {
      revision: doc.revision,
      candidate_id: choice,
      reason: reason.value.trim(),
    });
    f.d.close();
    render();
    message("Décision enregistrée.");
  });
}
function transferEditor(doc) {
  const permitted = doc.domain === "sport" ? ["ADMIN", "PDT", "VP", "SG", "SGA"] : ["TR", "TGA"];
  if (doc.candidates?.length) {
    message("Résolvez le conflit avant le transfert.", true);
    return;
  }
  mutationForm(
    "Transférer la responsabilité",
    groupPath(doc) + "/transfer",
    (parent) => {
      const targets = (client.snapshot.leaders || []).filter(
        (a) =>
          a.id !== doc.owner &&
          !a.shared &&
          a.roles.some((r) => permitted.includes(r)),
      );
      const target = field(parent, "Nouveau responsable", "", {
          select: [
            ["", "Choisir un responsable"],
            ...targets.map((a) => [a.id, a.username]),
          ],
          required: true,
        }),
        reason = field(parent, "Motif du transfert", "", { required: true });
      return () => ({
        account_id: target.value,
        revision: doc.revision,
        reason: reason.value.trim(),
      });
    },
  );
}
function network() {
  const offline = !navigator.onLine;
  $("network").hidden = !offline;
  $("network").textContent =
    "Hors ligne · Les données affichées sont celles de la dernière actualisation. Vos brouillons restent sur cet appareil.";
}
$("theme").addEventListener("click", () => {
  const current =
    document.documentElement.dataset.theme ||
    (matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  const theme = current === "light" ? "dark" : "light";
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem("statoo-theme", theme);
  } catch {}
});
try {
  const theme = localStorage.getItem("statoo-theme");
  if (theme) document.documentElement.dataset.theme = theme;
} catch {}
window.addEventListener("offline", () => {
  network();
  if (!client.connection) render();
});
window.addEventListener("online", () => {
  network();
  if (!client.connection) render();
  if (!modal && client.connection)
    run(async () => {
      await client.refresh();
      if (!modal) render({ preserve: true });
    });
});
window.addEventListener("beforeunload", (event) => {
  if (modal && modal.querySelector("input,textarea,select")) {
    event.preventDefault();
    event.returnValue = "";
  }
});
registerPwa($("install"));
try {
  const response = await fetch("./config.json", { cache: "no-store" });
  if (!response.ok)
    throw Error(
      "Configuration du serveur indisponible. Réessayez en actualisant la page.",
    );
  configuredApi = apiAddress(await response.json(), location.origin);
} catch (error) {
  configurationError = error;
}
fetch("./team-names.json")
  .then((r) => {
    if (!r.ok) throw Error();
    return r.json();
  })
  .then((names) => {
    if (
      Array.isArray(names) &&
      names.every((n) => typeof n === "string" && n.trim())
    )
      catalog = [...new Set(names)];
  })
  .catch(() => {});
client.restore();
try {
  if (
    !client.connection &&
    !localStorage.getItem("statoo-onboarding-complete") &&
    !localStorage.getItem("statoo-registration-draft")
  )
    onboardingStep = 0;
} catch {
  onboardingStep = 0;
}
await splashReady;
$("splash")?.remove();
render();
if (configurationError) message(configurationError.message, true);
if (client.connection)
  run(async () => {
    await client.refresh();
    if (!modal) render({ preserve: true });
  });
setInterval(() => {
  if (client.connection && !modal && navigator.onLine)
    run(async () => {
      await client.refresh();
      if (!modal) render({ preserve: true });
    });
}, 45000);
