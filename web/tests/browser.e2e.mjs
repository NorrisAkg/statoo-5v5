// Run against the local API serving /portal/. Set STATOO_PLAYWRIGHT to a Playwright package path if not installed locally.
import { createRequire } from "node:module";
import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { sportStep } from "./sport-helpers.mjs";
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STATOO_PLAYWRIGHT || "playwright");
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
let browser;
before(async () => {
  browser = await chromium.launch({ channel: "chrome", headless: true });
});
after(async () => {
  await browser?.close();
});

test("WEB-03 collective identity cannot expose manager actions even with elevated role labels", async () => {
  const x = await boot(roles, { shared: true });
  try {
    for (const name of [
      "Nouvelle séance",
      "Nouveau point financier",
      "Gérer le groupe",
      "Décisions",
    ])
      assert.equal(
        await x.page.getByRole("button", { name, exact: true }).count(),
        0,
      );
  } finally {
    await x.close();
  }
});

test("WEB-15/18/19 Admin adds a member, renews access and configures future contribution", async () => {
  const x = await boot(["ADMIN"]);
  try {
    await x.page.getByRole("button", { name: "Membres", exact: true }).click();
    await x.page
      .getByRole("button", { name: "Ajouter un membre", exact: true })
      .click();
    await x.page.getByLabel("Nom du membre", { exact: true }).fill("Diane");
    await x.page
      .getByRole("button", { name: "Enregistrer", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page
      .getByText("Modification enregistrée.", { exact: true })
      .waitFor();
    const roster = x.sent.find((s) => s.url.endsWith("/members")).body;
    assert.equal(roster.length, 4);
    assert.equal(roster[0].id, "a");
    assert.equal(roster[3].name, "Diane");
    await x.page
      .getByRole("button", { name: "Gérer le groupe", exact: true })
      .click();
    await x.page
      .getByRole("button", {
        name: "Renouveler l’accès collectif",
        exact: true,
      })
      .click();
    await x.page
      .getByLabel("Nouvel identifiant collectif", { exact: true })
      .fill("collectif");
    await x.page
      .getByLabel("Nouveau mot de passe collectif", { exact: true })
      .fill("New-Password-2026");
    await x.page
      .getByRole("button", { name: "Enregistrer", exact: true })
      .click();
    await Promise.all([
      x.page.waitForResponse(r => r.url().endsWith("/shared-access") && r.request().method() === "PUT"),
      x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click(),
    ]);
    await x.page
      .getByText("Modification enregistrée.", { exact: true })
      .waitFor();
    assert.equal(
      x.sent.find((s) => s.url.endsWith("/shared-access")).method,
      "PUT",
    );
    await x.page
      .getByRole("button", { name: "Paramètres financiers", exact: true })
      .click();
    await x.page
      .getByLabel("Cotisation par défaut", { exact: true })
      .fill("150");
    await x.page
      .getByRole("button", { name: "Enregistrer", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page
      .getByText("Modification enregistrée.", { exact: true })
      .waitFor();
    assert.equal(
      x.sent.find((s) => s.url.endsWith("/financial-settings")).body
        .contribution,
      150,
    );
  } finally {
    await x.close();
  }
});

test("WEB-12/14 sport cancellation requires a reason and sends current revision", async () => {
  const x = await boot(["SG"], {
    setup: (d) =>
      (d.documents["sport:ref"] = {
        domain: "sport",
        occurrence_id: "ref",
        owner: "me",
        revision: 6,
        generation: 2,
        candidates: [],
        payload: {
          session: {
            id: "s",
            team_id: "g",
            played_at: "2026-10-15T20:00:00",
            session_type: "CLASSIC_2",
            status: "CLOSED",
            score_a: 0,
            score_b: 0,
            result: "DRAW",
          },
          participations: [],
        },
      }),
  });
  try {
    await x.page
      .getByRole("button", { name: "Voir la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Modifier la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Annuler la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    await x.page
      .getByLabel("Motif de correction", { exact: true })
      .fill("Terrain indisponible");
    await x.page
      .getByRole("button", { name: "Annuler la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    const op = x.sent.find((s) => s.url.endsWith("/sync")).body;
    assert.equal(op.payload.session.status, "CANCELLED");
    assert.equal(op.base_revision, 6);
    assert.equal(op.generation, 2);
  } finally {
    await x.close();
  }
});
const members = [
  { id: "a", name: "Alice", is_active: 1 },
  { id: "b", name: "Bob", is_active: 1 },
  { id: "c", name: "Camille", is_active: 1 },
];
const roles = ["ADMIN", "PDT", "VP", "TR", "TGA", "SG", "SGA", "CENSOR"];
function snapshot(r = ["MEMBER"], shared = false) {
  return {
    name: "Les amis du terrain",
    account: { id: "me", roles: r, shared },
    members: structuredClone(members),
    leaders: [{ id: "me", username: "responsable", roles: r, shared: false }],
    accounts: [{ id: "me", username: "responsable", roles: r, shared: false }],
    documents: {},
    obligations: {},
    opening: null,
    opening_proposal: null,
    financial_settings: { contribution: 100, late_penalty: 0 },
    finances: { cash: 0, members: {} },
    audit: [],
  };
}
async function boot(r, options = {}) {
  const context = await browser.newContext({
    viewport: { width: options.width || 390, height: 900 },
    colorScheme: options.light ? "light" : "dark",
  });
  const page = await context.newPage();
  const data = snapshot(r, options.shared);
  data.sport_settings = { min_players_per_session: 3 };
  const sent = [];
  if (options.setup) options.setup(data);
  await page.route("**/groups/g", (route) => route.fulfill({ json: data }));
  await page.route("**/groups/g/**", async (route) => {
    const req = route.request();
    const body = req.postDataJSON();
    sent.push({ url: req.url(), method: req.method(), body });
    if (req.url().endsWith("/sync"))
      data.documents[body.domain + ":" + body.occurrence_id] = {
        ...body,
        owner: "me",
        revision: 1,
        generation: 0,
        candidates: [],
      };
    await route.fulfill({
      json: req.url().endsWith("/sync")
        ? { status: "accepted", revision: 1 }
        : { ok: true },
    });
  });
  await page.addInitScript(
    ({ base, r, shared }) =>
      sessionStorage.setItem(
        "statoo-connection",
        JSON.stringify({
          api: base,
          group: "g",
          token: "test",
          expires_at: "2099-01-01T00:00:00Z",
          account: { id: "me", roles: r, shared },
        }),
      ),
    { base, r, shared: options.shared || false },
  );
  page.on("pageerror", (error) => console.error("Browser:", error.message));
  page.on("requestfailed", (request) =>
    console.error(
      "Failed request:",
      request.url(),
      request.failure()?.errorText,
    ),
  );
  await page.addInitScript(() =>
    localStorage.setItem("statoo-onboarding-complete", "1"),
  );
  await page.goto(base + "/portal/");
  try {
    await page
      .getByRole("heading", { name: data.name, exact: true })
      .waitFor({ timeout: 8000 });
  } catch (error) {
    console.error("Page state:", await page.locator("body").innerText());
    await context.close();
    throw error;
  }
  return { page, data, sent, close: () => context.close() };
}
for (const [role, allowed] of [
  ["MEMBER", []],
  ["CENSOR", []],
  ["ADMIN", ["Gérer le groupe", "Nouvelle séance"]],
  ["SG", ["Nouvelle séance"]],
  ["SGA", ["Nouvelle séance"]],
  ["TR", ["Nouveau point financier"]],
  ["TGA", ["Nouveau point financier"]],
  ["PDT", ["Décisions", "Nouvelle séance"]],
  ["VP", ["Décisions", "Nouvelle séance"]],
]) {
  test("WEB-03/04 action matrix " + role, async () => {
    const x = await boot([role]);
    try {
      for (const name of [
        "Nouvelle séance",
        "Nouveau point financier",
        "Gérer le groupe",
        "Décisions",
      ])
        assert.equal(
          await x.page.getByRole("button", { name, exact: true }).count(),
          allowed.includes(name) ? 1 : 0,
        );
    } finally {
      await x.close();
    }
  });
}
test("WEB-07/08/09 sport form creates balanced tournament with three club names", async () => {
  const x = await boot(["SG"]);
  try {
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await x.page.getByLabel("Format de jeu").selectOption("TOURNAMENT_3");
    await sportStep(x.page, 2);
    for (const m of members)
      await x.page.getByLabel("Présent : " + m.name, { exact: true }).check();
    await sportStep(x.page, 3);
    await x.page.getByRole("button", { name: "Répartir les joueurs" }).click();
    for (const [name, team] of [
      ["Alice", "A"],
      ["Bob", "B"],
      ["Camille", "C"],
    ])
      await x.page
        .getByLabel("Équipe de " + name, { exact: true })
        .selectOption(team);
    await sportStep(x.page, 4);
    await x.page.getByLabel("Victoires A", { exact: true }).fill("2");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Données publiées.").waitFor();
    const op = x.sent.find((s) => s.url.endsWith("/sync")).body;
    assert.equal(op.payload.session.result, "A");
    assert.equal(op.payload.participations.length, 3);
    assert.equal(
      new Set(Object.values(JSON.parse(op.payload.session.team_names))).size,
      3,
    );
  } finally {
    await x.close();
  }
});
test("WEB-22 finance includes every member, separates donations and expenses", async () => {
  const x = await boot(["TR"], {
    setup: (d) => (d.opening = { cash: 0, members: {} }),
  });
  try {
    await x.page
      .getByRole("button", { name: "Nouveau point financier", exact: true })
      .click();
    await x.page.getByLabel("Cotisation de Alice", { exact: true }).fill("200");
    await x.page
      .getByRole("button", { name: "Ajouter une dépense", exact: true })
      .click();
    await x.page.getByLabel("Libellé de la dépense 1").fill("Eau");
    await x.page.getByLabel("Montant de la dépense 1").fill("20");
    await x.page
      .getByRole("button", { name: "Valider le point", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Données publiées.").waitFor();
    const op = x.sent.find((s) => s.url.endsWith("/sync")).body;
    assert.equal(op.payload.lines.length, 3);
    assert.equal(op.payload.lines[0].contribution, 200);
    assert.equal(op.payload.expenses[0].amount, 20);
  } finally {
    await x.close();
  }
});
test("WEB-15/16 Admin manages members and cannot create plain individual member", async () => {
  const x = await boot(["ADMIN"]);
  try {
    await x.page
      .getByRole("button", { name: "Gérer le groupe", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Ajouter un gestionnaire", exact: true })
      .click();
    await x.page.getByLabel("Membre du compte").selectOption("a");
    await x.page.getByLabel("Identifiant personnel").fill("alice");
    await x.page
      .getByLabel("Mot de passe personnel", { exact: true })
      .fill("password-2026");
    assert.equal(
      await x.page
        .getByRole("button", { name: "Créer le compte", exact: true })
        .isDisabled(),
      true,
    );
    await x.page.getByLabel("Secrétaire général", { exact: true }).check();
    assert.equal(
      await x.page
        .getByRole("button", { name: "Créer le compte", exact: true })
        .isEnabled(),
      true,
    );
    await x.page
      .getByRole("button", { name: "Créer le compte", exact: true })
      .click();
    assert.equal(
      await x.page
        .getByRole("dialog")
        .last()
        .getByText("Alice", { exact: true })
        .count(),
      1,
    );
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Modification enregistrée.").waitFor();
    assert.deepEqual(
      x.sent.find((s) => s.url.endsWith("/accounts")).body.roles,
      ["SG"],
    );
  } finally {
    await x.close();
  }
});
test("WEB-21 proposal approval submits exactly the displayed balances", async () => {
  const proposal = {
    cash: 400,
    start_date: "2026-10-01",
    members: { a: { contribution_balance: -100, penalty_debt: 10 } },
  };
  const x = await boot(["PDT"], {
    setup: (d) => (d.opening_proposal = proposal),
  });
  try {
    await x.page
      .getByRole("button", { name: "Décisions", exact: true })
      .click();
    await x.page
      .getByRole("button", {
        name: "Vérifier les soldes initiaux",
        exact: true,
      })
      .click();
    await x.page.getByText("400 F", { exact: true }).waitFor();
    await x.page
      .getByRole("button", { name: "Approuver ces soldes", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Modification enregistrée.").waitFor();
    assert.deepEqual(
      x.sent.find((s) => s.url.endsWith("/opening/approve")).body,
      { proposal },
    );
  } finally {
    await x.close();
  }
});
test("WEB-27 drafts survive reload; WEB-34 content is rendered as text", async () => {
  const x = await boot(["SG"], {
    setup: (d) => (d.name = "<img src=x onerror=alert(1)>"),
  });
  try {
    assert.equal(await x.page.locator("h1 img").count(), 0);
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await sportStep(x.page, 4);
    await x.page.getByLabel("Notes de la séance").fill("Brouillon conservé");
    await x.page.reload();
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    assert.equal(
      await x.page.getByLabel("Notes de la séance").inputValue(),
      "Brouillon conservé",
    );
  } finally {
    await x.close();
  }
});
for (const width of [320, 360, 390, 768, 1440])
  test("WEB-35 page fits viewport " + width, async () => {
    const x = await boot(roles, { width });
    try {
      for (const tab of [
        "Accueil",
        "Séances",
        "Membres",
        "Classement",
        "Finances",
      ]) {
        await x.page.getByRole("button", { name: tab, exact: true }).click();
        assert.equal(
          await x.page.evaluate(
            () => document.documentElement.scrollWidth <= innerWidth,
          ),
          true,
        );
      }
    } finally {
      await x.close();
    }
  });

test("WEB-02/17/20/21/09/22 real API journey from group creation to sport and finances", async () => {
  const context = await browser.newContext({
      viewport: { width: 390, height: 900 },
    }),
    p = await context.newPage();
  p.on("dialog", (d) => d.accept());
  try {
    let group;
    await p.addInitScript(() =>
      localStorage.setItem("statoo-onboarding-complete", "1"),
    );
    await p.goto(base + "/portal/");
    await p
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    if (group)
      await p.getByLabel("Identifiant du groupe", { exact: true }).fill(group);
    await p
      .getByLabel("Nom du groupe", { exact: true })
      .fill("Groupe PWA de test");
    await p
      .getByLabel("Membres du groupe", { exact: true })
      .fill("Alice\nBob\nCamille");
    await p.getByLabel("Identifiant Admin", { exact: true }).fill("admin");
    await p
      .getByLabel("Mot de passe Admin", { exact: true })
      .fill("Test-Password-2026");
    await p
      .getByLabel("Mot de passe collectif", { exact: true })
      .fill("Members-Password-2026");
    await p
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await p
      .getByRole("heading", { name: "Groupe PWA de test", exact: true })
      .waitFor();
    group = await p.evaluate(
      () => JSON.parse(sessionStorage.getItem("statoo-connection")).group,
    );
    assert.match(group, /^#[0-9]{8}$/);
    await p
      .getByText("Identifiant du groupe : " + group, { exact: true })
      .waitFor();
    await p
      .getByRole("button", { name: "Gérer le groupe", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Paramètres sportifs", exact: true })
      .click();
    await p
      .getByLabel("Minimum de joueurs par séance", { exact: true })
      .fill("3");
    await p.getByRole("button", { name: "Enregistrer", exact: true }).click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p.getByText("Modification enregistrée.", { exact: true }).waitFor();
    await p
      .getByRole("button", { name: "Modifier les rôles de admin", exact: true })
      .click();
    for (const role of ["Président", "Trésorier", "Secrétaire général"])
      await p.getByLabel(role, { exact: true }).check();
    await p
      .getByLabel("Motif du changement", { exact: true })
      .fill("Configuration initiale");
    await p
      .getByRole("button", { name: "Enregistrer les rôles", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p.getByText("Modification enregistrée.", { exact: true }).waitFor();
    await p.getByRole("button", { name: "Finances", exact: true }).click();
    await p
      .getByRole("button", {
        name: "Proposer les soldes initiaux",
        exact: true,
      })
      .click();
    await p.getByLabel("Caisse initiale", { exact: true }).fill("400");
    await p
      .getByRole("button", { name: "Soumettre les soldes", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p
      .getByText("Proposition envoyée au Président ou Vice-président.", {
        exact: true,
      })
      .waitFor();
    await p.getByRole("button", { name: "Décisions", exact: true }).click();
    await p
      .getByRole("button", {
        name: "Vérifier les soldes initiaux",
        exact: true,
      })
      .click();
    await p
      .getByRole("button", { name: "Approuver ces soldes", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p.getByText("Modification enregistrée.", { exact: true }).waitFor();
    await p
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await p.getByLabel("Format de jeu").selectOption("TOURNAMENT_3");
    const ref = await p
      .getByLabel("Référence de la séance", { exact: true })
      .inputValue();
    await sportStep(p, 2);
    for (const [i, m] of members.entries()) {
      await p.getByLabel("Présent : " + m.name, { exact: true }).check();
    }
    await sportStep(p, 3);
    for (const [i, m] of members.entries()) {
      await p
        .getByLabel("Équipe de " + m.name, { exact: true })
        .selectOption(["A", "B", "C"][i]);
    }
    await sportStep(p, 4);
    await p.getByLabel("Victoires A", { exact: true }).fill("3");
    await p
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p.getByText("Données publiées.", { exact: true }).waitFor();
    await p
      .getByRole("button", { name: "Nouveau point financier", exact: true })
      .click();
    await p.getByLabel("Échéance", { exact: true }).selectOption(ref);
    await p.getByLabel("Cotisation de Alice", { exact: true }).fill("200");
    await p
      .getByRole("button", { name: "Valider le point", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await p.getByText("Données publiées.", { exact: true }).waitFor();
    await p.getByRole("button", { name: "Finances", exact: true }).click();
    await p.getByText("600 F", { exact: true }).waitFor();
    await p
      .getByRole("button", { name: "Se déconnecter", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Se connecter", exact: true })
      .waitFor();
    if (group)
      await p.getByLabel("Identifiant du groupe", { exact: true }).fill(group);
    await p
      .getByLabel("Identifiant de connexion", { exact: true })
      .fill("membres");
    await p
      .getByLabel("Mot de passe", { exact: true })
      .fill("Members-Password-2026");
    await p.getByRole("button", { name: "Se connecter", exact: true }).click();
    await p
      .getByRole("heading", { name: "Groupe PWA de test", exact: true })
      .waitFor();
    group = await p.evaluate(
      () => JSON.parse(sessionStorage.getItem("statoo-connection")).group,
    );
    assert.match(group, /^#[0-9]{8}$/);
    await p
      .getByText("Identifiant du groupe : " + group, { exact: true })
      .waitFor();
    assert.equal(
      await p
        .getByRole("button", { name: "Nouvelle séance", exact: true })
        .count(),
      0,
    );
    await p.getByRole("button", { name: "Finances", exact: true }).click();
    await p.getByText("600 F", { exact: true }).waitFor();
  } catch (error) {
    console.error("Live API page:", await p.locator("body").innerText());
    throw error;
  } finally {
    await context.close();
  }
});

test("WEB-25/26 conflict decision and explicit responsibility transfer use displayed revision", async () => {
  const payload = {
    session: {
      id: "s",
      team_id: "g",
      played_at: "2026-10-15T20:00:00",
      session_type: "CLASSIC_2",
      status: "CLOSED",
      score_a: 1,
      score_b: 0,
      team_names: { A: "Racing", B: "Union" },
    },
    participations: [],
  };
  const x = await boot(["PDT"], {
    setup: (d) => {
      d.documents["sport:ref"] = {
        domain: "sport",
        occurrence_id: "ref",
        owner: "other",
        revision: 4,
        generation: 2,
        payload,
        candidates: [
          {
            id: "candidate",
            actor: "me",
            reason: "Version contrôlée",
            payload: {
              ...payload,
              session: { ...payload.session, score_a: 3 },
            },
          },
        ],
      };
      d.leaders.push({
        id: "sg",
        username: "secretaire",
        roles: ["SG"],
        shared: false,
      });
    },
  });
  try {
    await x.page
      .getByRole("button", { name: "Décisions", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Comparer les versions", exact: true })
      .click();
    await x.page.getByLabel("Retenir cette version", { exact: true }).check();
    await x.page
      .getByLabel("Motif de la décision", { exact: true })
      .fill("Feuille de match vérifiée");
    await x.page
      .getByRole("button", { name: "Valider la décision", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByText("Décision enregistrée.", { exact: true }).waitFor();
    const decision = x.sent.find((s) => s.url.endsWith("/resolve"));
    assert.equal(decision.body.revision, 4);
    assert.equal(decision.body.candidate_id, "candidate");
    x.data.documents["sport:ref"].candidates = [];
    await x.page
      .getByRole("button", { name: "Actualiser", exact: true })
      .click();
    await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
    await x.page.getByRole("button", { name: "Séances", exact: true }).click();
    await x.page
      .getByRole("button", { name: "Voir la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", {
        name: "Transférer la responsabilité",
        exact: true,
      })
      .click();
    await x.page
      .getByLabel("Nouveau responsable", { exact: true })
      .selectOption("sg");
    await x.page
      .getByLabel("Motif du transfert", { exact: true })
      .fill("Remplacement");
    await x.page
      .getByRole("button", { name: "Enregistrer", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page
      .getByText("Modification enregistrée.", { exact: true })
      .waitFor();
    assert.equal(
      x.sent.find((s) => s.url.endsWith("/transfer")).body.account_id,
      "sg",
    );
  } finally {
    await x.close();
  }
});

test("PWA-03/04 offline reload retains shell and own snapshot", async () => {
  const x = await boot(["SG"]);
  try {
    await x.page.evaluate(() =>
      Promise.race([
        navigator.serviceWorker.ready,
        new Promise((_, reject) =>
          setTimeout(() => reject(Error("Service worker not ready")), 8000),
        ),
      ]),
    );
    await x.page.waitForFunction(() => !!navigator.serviceWorker.controller);
    await x.page.context().setOffline(true);
    await x.page.reload();
    await x.page
      .getByRole("heading", { name: "Les amis du terrain", exact: true })
      .waitFor({ timeout: 8000 });
    assert.match(await x.page.locator("#network").innerText(), /Hors ligne/);
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await sportStep(x.page, 4);
    await x.page.getByLabel("Notes de la séance").fill("Saisie hors ligne");
  } catch (error) {
    console.error("Offline page:", await x.page.locator("body").innerText());
    console.error(
      "Worker state:",
      await x.page.evaluate(async () => ({
        registrations: (await navigator.serviceWorker.getRegistrations()).map(
          (r) => ({
            scope: r.scope,
            active: r.active?.state,
            installing: r.installing?.state,
            waiting: r.waiting?.state,
          }),
        ),
        caches: await caches.keys(),
        storageKeys: Object.keys(localStorage),
      })),
    );
    throw error;
  } finally {
    await x.close();
  }
});

for (const light of [false, true])
  test(
    "WEB-35 populated tournament and narrow form, theme " +
      (light ? "light" : "dark"),
    async () => {
      const payload = {
        session: {
          id: "visual",
          team_id: "g",
          played_at: "2026-10-15T20:00:00",
          session_type: "TOURNAMENT_3",
          status: "CLOSED",
          is_ranked: 1,
          wins_a: 7,
          wins_b: 4,
          wins_c: 2,
          team_names: {
            A: "Racing Atlas",
            B: "Union des Cèdres",
            C: "Sporting du Port",
          },
          team_colors: { A: 0xff8b5cf6, B: 0xffec4899, C: 0xff06b6d4 },
        },
        participations: members.map((m, i) => ({
          id: m.id,
          session_id: "visual",
          player_id: m.id,
          team: ["A", "B", "C"][i],
          goals: [3, 2, 4][i],
          assists: 0,
        })),
      };
      const x = await boot(roles, {
        width: 390,
        light,
        setup: (d) => {
          d.documents["sport:ref"] = {
            domain: "sport",
            occurrence_id: "ref",
            payload,
            owner: "me",
            revision: 1,
            generation: 0,
            candidates: [],
          };
          d.finances.cash = 12600;
        },
      });
      try {
        await x.page.getByText("Racing Atlas", { exact: true }).waitFor();
        assert.equal(
          await x.page.evaluate(
            () => document.documentElement.scrollWidth <= innerWidth,
          ),
          true,
        );
        if (process.env.STATOO_QA_OUTPUT) {
          mkdirSync(process.env.STATOO_QA_OUTPUT, { recursive: true });
          await x.page.screenshot({
            path: join(
              process.env.STATOO_QA_OUTPUT,
              `home-${light ? "light" : "dark"}.png`,
            ),
            fullPage: true,
          });
        }
        await x.page.setViewportSize({ width: 320, height: 900 });
        await x.page
          .getByRole("button", { name: "Nouvelle séance", exact: true })
          .click();
        await sportStep(x.page, 2);
        await x.page.getByLabel("Présent : Alice", { exact: true }).check();
        assert.equal(
          await x.page.evaluate(
            () =>
              document.querySelector("dialog").scrollWidth <=
              document.querySelector("dialog").clientWidth,
          ),
          true,
        );
        if (process.env.STATOO_QA_OUTPUT)
          await x.page.screenshot({
            path: join(
              process.env.STATOO_QA_OUTPUT,
              `form-${light ? "light" : "dark"}.png`,
            ),
            fullPage: true,
          });
      } finally {
        await x.close();
      }
    },
  );
