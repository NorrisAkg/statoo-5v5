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

const $ = (id) => document.getElementById(id),
  client = new PortalClient();
let tab = "Accueil",
  catalog = [],
  modal = null,
  registration = false,
  configuredApi = null,
  configurationError = null;
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
  input.value = value ?? "";
  input.setAttribute("aria-label", label);
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
  wrapper.append(input);
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
          errors.textContent = "";
          b.disabled = true;
          try {
            await action();
          } catch (error) {
            errors.textContent = error.message;
            report(error);
          } finally {
            b.disabled = false;
          }
        },
        "primary",
      );
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
    name.style.color = team.color;
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
    const value = collect();
    if (!(await confirmSend("Vérifier la modification", summaryValues(value))))
      return;
    await client.mutate(path, value, method);
    f.d.close();
    render();
    message("Modification enregistrée.");
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
function auth() {
  const preparation = new RegistrationDraft(localStorage);
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
  let name, roster, sharedUser, sharedPassword;
  if (registration) {
    const details = el("fieldset", "", "registration-section group-details");
    details.append(el("legend", "Le groupe"));
    form.append(details);
    name = field(details, "Nom du groupe", draft?.name || "", {
      required: true,
      maxLength: 100,
    });
    roster = field(details, "Membres du groupe", draft?.roster || "", {
      textarea: true,
      required: true,
    });
    name.disabled = roster.disabled = !!draft?.pending;
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
        draft = preparation.save({ name: name.value, roster: roster.value });
        errors.textContent = "";
        status.textContent = savedMessage();
      } catch (error) {
        errors.textContent = error.message;
      }
    };
    if (!draft?.pending) {
      name.addEventListener("input", save);
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
    submit.disabled = true;
    errors.textContent = "";
    try {
      if (registration && !navigator.onLine) {
        draft = preparation.save({ name: name.value, roster: roster.value });
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
      let pending;
      if (registration) {
        if (!draft?.pending)
          draft = preparation.save({ name: name.value, roster: roster.value });
        pending = preparation.prepare(configuredApi);
        draft = pending;
        name.disabled = roster.disabled = true;
      }
      await client.connect(
        configuredApi,
        group?.value.trim() || "",
        user.value.trim(),
        pass.value,
        registration
          ? {
              name: pending.name,
              operation_id: pending.operation_id,
              username: user.value.trim(),
              password: pass.value,
              shared_username: sharedUser.value.trim(),
              shared_password: sharedPassword.value,
              members: pending.members,
            }
          : undefined,
      );
      if (registration) preparation.clear();
      render();
      message(
        registration
          ? "Groupe créé. Attribuez les rôles Président, Trésorier et Secrétaire général pour démarrer."
          : "",
      );
      registration = false;
    } catch (error) {
      errors.textContent = error.message;
      if (registration && draft?.pending)
        status.textContent =
          "Publication à vérifier. Ressaisissez les mêmes accès pour reprendre sans créer de doublon.";
    } finally {
      if (pass) pass.value = "";
      if (sharedPassword) sharedPassword.value = "";
      submit.disabled = false;
    }
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
function render() {
  const root = $("content");
  root.replaceChildren();
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
    el("h1", data.name),
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
    button("Actualiser", () =>
      run(async () => {
        await client.refresh();
        render();
        message("Données actualisées.");
      }),
    ),
    button(
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
      button("Réessayer les envois", () =>
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
    if (!["PDT", "TR", "SG"].every((r) => assigned.has(r)))
      parent.append(
        card(
          "Préparer votre groupe",
          "Attribuez les rôles Président, Trésorier et Secrétaire général dans Gérer le groupe. Les soldes initiaux seront proposés par le Trésorier et approuvés par le Président.",
        ),
      );
  }
}
function sessions(parent) {
  parent.append(el("h2", "Les séances du groupe"));
  const controls = el("div", "", "filter-bar"),
    list = el("div", "", "grid");
  let filter = "all",
    search = "";
  function update() {
    list.replaceChildren();
    for (const doc of documents("sport").filter(
      (d) =>
        (filter === "all" || d.payload.session.status === filter) &&
        JSON.stringify([d.occurrence_id, d.payload.session.team_names])
          .toLocaleLowerCase("fr")
          .includes(search.toLocaleLowerCase("fr")),
    ))
      list.append(sessionCard(doc));
    if (!list.children.length)
      list.append(el("p", "Aucune séance pour ce filtre.", "muted"));
  }
  field(controls, "État", "all", {
    select: [
      ["all", "Toutes"],
      ["DRAFT", "En cours"],
      ["CLOSED", "Terminées"],
      ["CANCELLED", "Annulées"],
    ],
    change: (v) => {
      filter = v;
      update();
    },
  });
  field(controls, "Rechercher une séance", "", {
    change: (v) => {
      search = v;
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
  if (catalog.length < 3) {
    message(
      "Le catalogue d’équipes est indisponible. Actualisez la page en ligne.",
      true,
    );
    return;
  }
  const id = doc?.occurrence_id || "new",
    saved = client.readDraft("sport", id),
    now = localDate(),
    names = shuffled(catalog).slice(0, 3);
  const state = saved || {
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
              ["A", "B", "C"].map((t, i) => [t, names[i]]),
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
  const s = state.payload.session;
  s.team_names = objectMap(s.team_names);
  s.team_colors = objectMap(s.team_colors);
  ["A", "B", "C"].forEach((t, i) => {
    s.team_names[t] ??= "Équipe " + t;
    s.team_colors[t] ??= Object.values(palette)[i];
  });
  const f = dialog(doc ? "Modifier la séance" : "Nouvelle séance");
  function save() {
    try {
      client.saveDraft("sport", id, state);
    } catch (error) {
      f.errors.textContent = error.message;
    }
  }
  function paint() {
    f.body.replaceChildren();
    const top = el("div", "", "form-grid");
    field(top, "Date et heure", s.played_at.slice(0, 16), {
      type: "datetime-local",
      required: true,
      change: (v) => {
        s.played_at = v;
        if (!doc) {
          state.reference = newReference(client.snapshot, v);
          reference.value = state.reference;
        }
        save();
      },
    });
    field(top, "Format de jeu", s.session_type, {
      select: [
        ["CLASSIC_2", "Match · 2 équipes"],
        ["TOURNAMENT_3", "Tournoi · 3 équipes"],
      ],
      change: (v) => {
        s.session_type = v;
        if (v === "CLASSIC_2")
          state.payload.participations.forEach((p) => {
            if (p.team === "C") p.team = "";
          });
        save();
        paint();
      },
    });
    const reference = field(top, "Référence de la séance", state.reference, {
      required: true,
      maxLength: 150,
      change: (v) => {
        state.reference = v;
        save();
      },
    });
    reference.readOnly = !!doc;
    if (s.session_type === "TOURNAMENT_3")
      field(top, "Points pour un nul", s.draw_points, {
        type: "number",
        min: 0,
        change: (v) => {
          s.draw_points = v;
          save();
        },
      });
    f.body.append(top);
    check(f.body, "Séance classée", s.is_ranked, (v) => {
      s.is_ranked = v ? 1 : 0;
      save();
    });
    check(
      f.body,
      "Autoriser les équipes inégales",
      s.allow_uneven_teams,
      (v) => {
        s.allow_uneven_teams = v ? 1 : 0;
        save();
      },
    );
    const teams =
      s.session_type === "TOURNAMENT_3" ? ["A", "B", "C"] : ["A", "B"];
    f.body.append(
      el("h3", "Les équipes"),
      el("p", "Noms attribués au hasard · Choisissez les couleurs.", "muted"),
    );
    const teamGrid = el("div", "", "form-grid");
    for (const t of teams) {
      const c = card(s.team_names[t] || "Équipe " + t);
      field(c, "Couleur " + t, String(s.team_colors[t]), {
        select: Object.entries(palette).map(([name, n]) => [String(n), name]),
        change: (v) => {
          s.team_colors[t] = Number(v);
          save();
        },
      });
      field(
        c,
        (s.session_type === "TOURNAMENT_3" ? "Victoires " : "Score ") + t,
        s[
          s.session_type === "TOURNAMENT_3"
            ? "wins_" + t.toLowerCase()
            : "score_" + t.toLowerCase()
        ] ?? 0,
        {
          type: "number",
          min: 0,
          change: (v) => {
            s[
              (s.session_type === "TOURNAMENT_3" ? "wins_" : "score_") +
                t.toLowerCase()
            ] = v;
            save();
          },
        },
      );
      teamGrid.append(c);
    }
    f.body.append(teamGrid, el("h3", "Composition et statistiques"));
    f.body.append(
      button("Répartir les joueurs", () => {
        shuffled(state.payload.participations).forEach(
          (p, i) => (p.team = teams[i % teams.length]),
        );
        save();
        paint();
      }),
    );
    const roster = [
      ...client.snapshot.members.filter(
        (m) =>
          m.is_active !== 0 ||
          state.payload.participations.some((p) => p.player_id === m.id),
      ),
    ];
    for (const m of roster) {
      const c = card(m.name),
        part = state.payload.participations.find((p) => p.player_id === m.id);
      check(c, "Présent : " + m.name, !!part, (selected) => {
        if (selected)
          state.payload.participations.push({
            id: crypto.randomUUID(),
            session_id: s.id,
            player_id: m.id,
            team: "",
            goals: 0,
            assists: 0,
            yellow_cards: 0,
            red_cards: 0,
          });
        else
          state.payload.participations = state.payload.participations.filter(
            (p) => p.player_id !== m.id,
          );
        save();
        paint();
      });
      if (part) {
        const grid = el("div", "", "player-inputs");
        field(grid, "Équipe de " + m.name, part.team, {
          select: [
            ["", "À placer"],
            ...teams.map((t) => [t, t + " · " + s.team_names[t]]),
          ],
          change: (v) => {
            part.team = v;
            save();
          },
        });
        for (const [label, key] of [
          ["Buts", "goals"],
          ["Passes", "assists"],
          ["Jaunes", "yellow_cards"],
          ["Rouges", "red_cards"],
        ])
          field(grid, label + " de " + m.name, part[key] || 0, {
            type: "number",
            min: 0,
            change: (v) => {
              part[key] = v;
              save();
            },
          });
        c.append(grid);
      }
      f.body.append(c);
    }
    field(f.body, "Notes de la séance", s.notes || "", {
      textarea: true,
      change: (v) => {
        s.notes = v;
        save();
      },
    });
    if (doc)
      field(f.body, "Motif de correction", state.reason, {
        required: true,
        change: (v) => {
          state.reason = v;
          save();
        },
      });
    f.body.append(
      el(
        "p",
        "Brouillon conservé sur cet appareil pour votre compte. Les buts non attribués sont calculés à partir du score du match.",
        "muted",
      ),
    );
  }
  async function send(status) {
    const payload = prepareSport(
      state.payload,
      client.snapshot.members,
      status,
    );
    if (!doc && client.snapshot.documents["sport:" + state.reference])
      throw Error(
        "Cette référence possède déjà une séance. Ouvrez-la pour la modifier.",
      );
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
      doc,
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
  f.submit("Enregistrer le brouillon", () => send("DRAFT"));
  f.submit("Clôturer la séance", () => send("CLOSED"));
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
    f.body.replaceChildren();
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
      doc?.obligation ? undefined : doc,
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
      message("Modification enregistrée.");
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
      client.snapshot.opening_proposal || {
        cash: 0,
        start_date: null,
        members: {},
      },
    );
  field(f.body, "Caisse initiale", p.cash, {
    type: "number",
    min: 0,
    change: (v) => (p.cash = v),
  });
  field(f.body, "Date de début des comptes", p.start_date || "", {
    type: "date",
    change: (v) => (p.start_date = v || null),
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
      change: (v) => (balance.contribution_balance = v),
    });
    field(c, "Pénalités initiales de " + m.name, balance.penalty_debt, {
      type: "number",
      min: 0,
      change: (v) => (balance.penalty_debt = v),
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
    if (!(await confirmSend("Vérifier les soldes proposés", openingReview(p))))
      return;
    await client.mutate("/opening", p);
    f.d.close();
    render();
    message("Proposition envoyée au Président ou Vice-président.");
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
    message("Modification enregistrée.");
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
  const permitted = doc.domain === "sport" ? ["SG", "SGA"] : ["TR", "TGA"];
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
      render();
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
try {
  catalog = await fetch("./team-names.json").then((r) => r.json());
} catch {}
client.restore();
render();
if (configurationError) message(configurationError.message, true);
if (client.connection)
  run(async () => {
    await client.refresh();
    render();
  });
setInterval(() => {
  if (client.connection && !modal && navigator.onLine)
    run(async () => {
      await client.refresh();
      render();
    });
}, 45000);
