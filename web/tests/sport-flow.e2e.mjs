import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
const steps = ["1 · Options", "2 · Présents", "3 · Équipes", "4 · Match"];
let browser;
before(async () => {
  browser = await chromium.launch({ channel: "chrome", headless: true });
});
after(async () => {
  await browser?.close();
});

test("SPORT-14 a storage failure never claims the current preparation is saved", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await x.page.evaluate(() => {
      Storage.prototype.setItem = () => {
        throw new DOMException("Quota exceeded", "QuotaExceededError");
      };
    });
    await x.page
      .getByLabel("Référence de la séance", { exact: true })
      .fill("reference-a-conserver");
    assert.equal(
      await x.page
        .getByText(
          "Préparation non enregistrée : le stockage local est indisponible.",
          { exact: true },
        )
        .count(),
      1,
    );
    await step(x.page, 1);
    await x.page.getByLabel("Présent : Alice", { exact: true }).check();
    assert.match(await x.page.getByRole("alert").innerText(), /stockage/i);
    assert.equal(
      await x.page
        .getByText(
          "Préparation non enregistrée : le stockage local est indisponible.",
          { exact: true },
        )
        .count(),
      1,
    );
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await step(x.page, 2);
    await x.page
      .getByRole("button", { name: "Répartir les joueurs", exact: true })
      .click();
    await step(x.page, 3);
    await x.page
      .getByRole("button", { name: "Enregistrer le brouillon", exact: true })
      .click();
    await confirm(x.page);
    assert.match(await x.page.getByRole("alert").innerText(), /stockage/i);
    assert.equal(x.sent.length, 0);
    assert.deepEqual(x.errors, []);
  } finally {
    await x.close();
  }
});

test("SPORT-14 storage recovery restores the preparation status after typing", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await step(x.page, 3);
    await x.page.evaluate(() => {
      window.sportOriginalSetItem = Storage.prototype.setItem;
      Storage.prototype.setItem = () => {
        throw Error("Quota exceeded");
      };
    });
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("Avant rétablissement");
    assert.equal(
      await x.page
        .getByText(
          "Préparation non enregistrée : le stockage local est indisponible.",
          { exact: true },
        )
        .count(),
      1,
    );
    await x.page.evaluate(() => {
      Storage.prototype.setItem = window.sportOriginalSetItem;
    });
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("Après rétablissement");
    assert.equal(
      await x.page
        .getByText(
          "Préparation non enregistrée : le stockage local est indisponible.",
          { exact: true },
        )
        .count(),
      0,
    );
    assert.equal(
      await x.page.locator(".sport-dialog form > .error").textContent(),
      "",
    );
    await x.page.keyboard.press("Escape");
    await flow(x.page);
    assert.equal(
      await x.page
        .getByLabel("Notes de la séance", { exact: true })
        .inputValue(),
      "Après rétablissement",
    );
  } finally {
    await x.close();
  }
});
const names = [
  "Alice",
  "Béatrice",
  "Karim",
  "Diane",
  "Émile",
  "Fatou",
  "Gilles",
  "Hawa",
];
function snapshot(options = {}) {
  const account = {
    id: "me",
    roles: options.roles || ["SG"],
    shared: !!options.shared,
  };
  const members = Array.from({ length: options.count ?? 8 }, (_, i) => ({
    id: "p" + i,
    name: names[i] || "Joueur " + i,
    nickname: i === 1 ? "Béa" : "",
    is_active: 1,
  }));
  members.push({ id: "archived", name: "Ancien joueur", is_active: 0 });
  const s = {
    name: "Groupe sport",
    account,
    members,
    leaders: [],
    accounts: [],
    opening: { cash: 0, members: {} },
    documents: {},
    obligations: {},
    finances: { cash: 0, members: {} },
    sport_settings: { min_players_per_session: options.minimum ?? 6 },
    financial_settings: { contribution: 100, late_penalty: 0 },
  };
  if (options.existing) {
    const session = {
      id: "s",
      team_id: "g",
      played_at: "2026-10-16T20:00",
      status: options.status || "DRAFT",
      session_type: "CLASSIC_2",
      is_ranked: 1,
      allow_uneven_teams: 0,
      score_a: 0,
      score_b: 0,
      draw_points: 1,
      team_names: { A: "Atlas", B: "Union", C: "Racing" },
      team_colors: { A: 0xff3b82f6, B: 0xfff97316, C: 0xff22c55e },
      notes: "Notes existantes",
    };
    const participations = members
      .filter((m) => m.is_active)
      .slice(0, 6)
      .map((m, i) => ({
        id: "part" + i,
        player_id: m.id,
        session_id: "s",
        team: i % 2 ? "B" : "A",
        goals: 0,
        assists: 0,
        yellow_cards: 0,
        red_cards: 0,
      }));
    if (options.historical)
      participations.push({
        id: "old",
        player_id: "archived",
        session_id: "s",
        team: "A",
        goals: 0,
        assists: 0,
      });
    s.documents["sport:ref"] = {
      domain: "sport",
      occurrence_id: "ref",
      owner: options.owner || "me",
      revision: 2,
      generation: 0,
      candidates: options.conflict ? [{ id: "other" }] : [],
      payload: { session, participations },
    };
  }
  return s;
}
async function boot(options = {}) {
  const context = await browser.newContext({
      viewport: { width: options.width || 390, height: 900 },
      colorScheme: options.light ? "light" : "dark",
    }),
    page = await context.newPage();
  const data = snapshot(options),
    sent = [],
    errors = [];
  let reject = null;
  page.on("pageerror", (e) => errors.push(e.message));
  await page.route("**/groups/g", (r) => r.fulfill({ json: data }));
  await page.route("**/groups/g/sync", (r) => {
    const op = r.request().postDataJSON();
    sent.push(op);
    if (reject)
      return r.fulfill({
        status: reject,
        json: { detail: "Refus de publication" },
      });
    data.documents[op.domain + ":" + op.occurrence_id] = {
      domain: op.domain,
      occurrence_id: op.occurrence_id,
      owner: "me",
      revision: 3,
      generation: 0,
      candidates: [],
      payload: op.payload,
    };
    return r.fulfill({ json: { status: "accepted", revision: 3 } });
  });
  if (options.noCatalogue)
    await page.route("**/team-names.json", (r) =>
      r.fulfill({ status: 503, body: "Unavailable" }),
    );
  await page.addInitScript(
    ({ base, account }) =>
      sessionStorage.setItem(
        "statoo-connection",
        JSON.stringify({
          api: base,
          group: "g",
          token: "synthetic",
          expires_at: "2099-01-01T00:00:00Z",
          account,
        }),
      ),
    { base, account: data.account },
  );
  await page.goto(base + "/portal/");
  await page.getByRole("heading", { name: data.name, exact: true }).waitFor();
  await page.waitForLoadState("networkidle");
  return {
    page,
    context,
    data,
    sent,
    errors,
    reject: (status) => {
      reject = status;
    },
    close: () => context.close(),
  };
}
async function flow(page, existing = false) {
  if (existing) {
    await page
      .getByRole("button", { name: "Voir la séance", exact: true })
      .first()
      .click();
    await page
      .getByRole("button", { name: "Modifier la séance", exact: true })
      .click();
  } else
    await page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
  assert.equal(
    await page.getByRole("button", { name: steps[0], exact: true }).count(),
    1,
    "La séance doit proposer les quatre étapes du parcours sportif.",
  );
}
async function step(page, index) {
  await page.getByRole("button", { name: steps[index], exact: true }).click();
}
async function compose(page, count = 6) {
  await step(page, 1);
  for (const name of names.slice(0, count))
    await page.getByLabel("Présent : " + name, { exact: true }).check();
  await step(page, 2);
  await page
    .getByRole("button", { name: "Répartir les joueurs", exact: true })
    .click();
  await step(page, 3);
}
async function confirm(page) {
  await page
    .getByRole("button", { name: "Confirmer l’envoi", exact: true })
    .click();
}
async function screenshot(page, name) {
  if (!process.env.STATOO_SPORT_QA) return;
  mkdirSync(process.env.STATOO_SPORT_QA, { recursive: true });
  await page.screenshot({
    path: join(process.env.STATOO_SPORT_QA, name + ".png"),
  });
}

for (const width of [390, 1440])
  for (const light of [false, true]) {
    test(`SPORT-01/02/05 progressive layout ${width}px ${light ? "light" : "dark"}`, async () => {
      const x = await boot({ width, light });
      try {
        await flow(x.page);
        assert.equal(
          await x.page
            .getByRole("button", { name: steps[0], exact: true })
            .getAttribute("aria-current"),
          "step",
        );
        assert.equal(
          await x.page.getByLabel("Date et heure", { exact: true }).isVisible(),
          true,
        );
        assert.equal(
          await x.page.getByLabel("Présent : Alice", { exact: true }).count(),
          0,
        );
        await x.page
          .getByLabel("Date et heure", { exact: true })
          .fill("2026-10-20T18:30");
        await x.page
          .getByRole("button", { name: "Suivant", exact: true })
          .click();
        assert.equal(
          await x.page
            .getByRole("button", { name: steps[1], exact: true })
            .getAttribute("aria-current"),
          "step",
        );
        assert.equal(
          await x.page.getByLabel("Date et heure", { exact: true }).count(),
          0,
        );
        await x.page.getByLabel("Présent : Alice", { exact: true }).focus();
        await x.page
          .getByLabel("Présent : Alice", { exact: true })
          .press("Space");
        assert.equal(
          await x.page
            .getByLabel("Présent : Alice", { exact: true })
            .evaluate((n) => n === document.activeElement),
          true,
        );
        await screenshot(
          x.page,
          `presents-${width}-${light ? "light" : "dark"}`,
        );
        await x.page
          .getByRole("button", { name: "Précédent", exact: true })
          .click();
        assert.equal(
          await x.page
            .getByLabel("Date et heure", { exact: true })
            .inputValue(),
          "2026-10-20T18:30",
        );
        await compose(x.page);
        assert.equal(
          await x.page.getByLabel("Score A", { exact: true }).isVisible(),
          true,
        );
        assert.equal(
          await x.page.getByLabel("Buts de Alice", { exact: true }).count(),
          0,
        );
        const button = x.page.getByRole("button", {
          name: "Clôturer la séance",
          exact: true,
        });
        const box = await button.boundingBox();
        assert.ok(
          box.y >= 0 && box.y + box.height <= 900,
          "La clôture doit rester accessible dans la barre d’actions.",
        );
        assert.equal(
          await x.page
            .getByRole("dialog")
            .evaluate((n) => n.scrollWidth <= n.clientWidth),
          true,
        );
        await screenshot(x.page, `match-${width}-${light ? "light" : "dark"}`);
        assert.deepEqual(x.errors, []);
      } finally {
        await x.close();
      }
    });
  }

test("SPORT-03/04 search is accent-insensitive, scoped bulk selection preserves hidden selections", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await step(x.page, 1);
    const search = x.page.getByLabel("Rechercher un joueur", { exact: true });
    await search.fill("BEA");
    assert.equal(
      await x.page
        .getByLabel("Présent : Béatrice", { exact: true })
        .isVisible(),
      true,
    );
    assert.equal(
      await x.page.getByLabel("Présent : Alice", { exact: true }).count(),
      0,
    );
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await search.fill("Alice");
    await x.page.getByLabel("Présent : Alice", { exact: true }).check();
    await search.fill("inconnu");
    await x.page
      .getByText("Aucun joueur pour cette recherche.", { exact: true })
      .waitFor();
    await search.fill("");
    assert.equal(
      await x.page.getByLabel("Présent : Alice", { exact: true }).isChecked(),
      true,
    );
    assert.equal(
      await x.page
        .getByLabel("Présent : Béatrice", { exact: true })
        .isChecked(),
      true,
    );
    assert.equal(
      await x.page
        .getByLabel("Présent : Ancien joueur", { exact: true })
        .count(),
      0,
    );
    await search.fill("BEA");
    await x.page
      .getByRole("button", {
        name: "Désélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await search.fill("");
    assert.equal(
      await x.page.getByLabel("Présent : Alice", { exact: true }).isChecked(),
      true,
    );
    assert.equal(
      await x.page
        .getByLabel("Présent : Béatrice", { exact: true })
        .isChecked(),
      false,
    );
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await x.page
      .getByText("8 présents · Minimum pour clôturer : 6", { exact: true })
      .waitFor();
    assert.equal(await x.page.getByLabel(/^Buts de /).count(), 0);
  } finally {
    await x.close();
  }
});

for (const [format, count, teams] of [
  ["CLASSIC_2", 6, ["A", "B"]],
  ["CLASSIC_2", 7, ["A", "B"]],
  ["TOURNAMENT_3", 6, ["A", "B", "C"]],
  ["TOURNAMENT_3", 8, ["A", "B", "C"]],
]) {
  test(`SPORT-07 distribution preserves participants and balances ${count} players in ${teams.length} teams`, async () => {
    const x = await boot();
    try {
      await flow(x.page);
      await x.page
        .getByLabel("Format de jeu", { exact: true })
        .selectOption(format);
      await compose(x.page, count);
      await step(x.page, 2);
      for (let repeat = 0; repeat < 2; repeat++) {
        await x.page
          .getByRole("button", { name: "Répartir les joueurs", exact: true })
          .click();
        const assigned = await x.page
          .getByLabel(/^Équipe de /)
          .evaluateAll((nodes) => nodes.map((n) => n.value));
        const counts = teams.map((t) => assigned.filter((v) => v === t).length);
        assert.equal(assigned.length, count);
        assert.ok(Math.max(...counts) - Math.min(...counts) <= 1);
        for (const [i, t] of teams.entries())
          await x.page
            .getByText(`Équipe ${t} · ${counts[i]} joueur(s)`, { exact: true })
            .waitFor();
      }
      await x.page
        .getByLabel("Équipe de Alice", { exact: true })
        .selectOption("B");
      assert.equal(
        await x.page
          .getByLabel("Équipe de Alice", { exact: true })
          .inputValue(),
        "B",
      );
    } finally {
      await x.close();
    }
  });
}

test("SPORT-06/09 counters are local, targeted and reversible; deselection retains a player’s work", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    await x.page
      .getByRole("button", { name: "Augmenter le score A", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Diminuer le score B", exact: true })
      .isDisabled()
      .then((disabled) => assert.equal(disabled, true));
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Alice",
        exact: true,
      })
      .click();
    await x.page
      .getByRole("button", { name: "Augmenter les buts de Alice", exact: true })
      .click();
    await x.page
      .getByRole("button", {
        name: "Augmenter les jaunes de Alice",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).inputValue(),
      "1",
    );
    assert.equal(
      await x.page.getByLabel("Jaunes de Alice", { exact: true }).inputValue(),
      "1",
    );
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Béatrice",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).count(),
      0,
    );
    assert.equal(
      await x.page.getByLabel("Buts de Béatrice", { exact: true }).isVisible(),
      true,
    );
    assert.equal(x.sent.length, 0);
    await step(x.page, 1);
    await x.page.getByLabel("Présent : Alice", { exact: true }).uncheck();
    await x.page.getByLabel("Présent : Alice", { exact: true }).check();
    await step(x.page, 3);
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Alice",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).inputValue(),
      "1",
    );
    assert.equal(
      await x.page.getByLabel("Jaunes de Alice", { exact: true }).inputValue(),
      "1",
    );
    await x.page
      .getByRole("button", { name: "Diminuer les buts de Alice", exact: true })
      .click();
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).inputValue(),
      "0",
    );
    assert.equal(
      await x.page
        .getByRole("button", {
          name: "Diminuer les buts de Alice",
          exact: true,
        })
        .isDisabled(),
      true,
    );
    assert.deepEqual(x.errors, []);
  } finally {
    await x.close();
  }
});

test("SPORT-08/10 format change never hides C players; validation guides back before any send", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await x.page
      .getByLabel("Format de jeu", { exact: true })
      .selectOption("TOURNAMENT_3");
    await compose(x.page);
    await step(x.page, 0);
    await x.page
      .getByLabel("Format de jeu", { exact: true })
      .selectOption("CLASSIC_2");
    await step(x.page, 3);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[2], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    assert.match(await x.page.getByRole("alert").innerText(), /équipe|placer/i);
    assert.equal(await x.page.getByLabel(/^Équipe de /).count(), 6);
    assert.equal(x.sent.length, 0);
    await x.page
      .getByRole("button", { name: "Répartir les joueurs", exact: true })
      .click();
    await step(x.page, 3);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Revenir à la saisie", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
  } finally {
    await x.close();
  }
});

test("SPORT-10/11 classic closure keeps the API contract, confirms and removes only the published draft", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    await x.page.getByLabel("Score A", { exact: true }).fill("2");
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("Match du vendredi");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    await x.page
      .getByRole("button", { name: "Revenir à la saisie", exact: true })
      .click();
    assert.equal(
      await x.page
        .getByLabel("Notes de la séance", { exact: true })
        .inputValue(),
      "Match du vendredi",
    );
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await confirm(x.page);
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    assert.equal(x.sent.length, 1);
    const op = x.sent[0];
    assert.equal(op.payload.session.status, "CLOSED");
    assert.equal(op.payload.session.result, "A");
    assert.equal(op.payload.participations.length, 6);
    assert.equal(
      new Set(op.payload.participations.map((p) => p.player_id)).size,
      6,
    );
    assert.equal(typeof op.payload.session.team_names, "string");
    assert.equal(
      await x.page.evaluate(
        () =>
          Object.keys(localStorage).filter((k) => k.endsWith("draft:sport:new"))
            .length,
      ),
      0,
    );
  } finally {
    await x.close();
  }
});

test("SPORT-10 minimum and incoherent goals stop publication, retaining data for correction", async () => {
  const x = await boot({ minimum: 8 });
  try {
    await flow(x.page);
    await compose(x.page);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    assert.match(await x.page.getByRole("alert").innerText(), /8 joueurs/i);
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[1], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    await step(x.page, 2);
    await x.page
      .getByRole("button", { name: "Répartir les joueurs", exact: true })
      .click();
    await step(x.page, 3);
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Alice",
        exact: true,
      })
      .click();
    await x.page.getByLabel("Buts de Alice", { exact: true }).fill("5");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.match(await x.page.getByRole("alert").innerText(), /buts.*score/i);
    assert.equal(x.sent.length, 0);
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).inputValue(),
      "5",
    );
  } finally {
    await x.close();
  }
});

test("SPORT-11 refused write retains local preparation and no automatic retry occurs", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    x.reject(422);
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("Préparation à conserver");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await confirm(x.page);
    await x.page
      .getByText("Refus de publication", { exact: true })
      .first()
      .waitFor();
    assert.equal(x.sent.length, 1);
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    await flow(x.page);
    assert.equal(
      await x.page
        .getByLabel("Notes de la séance", { exact: true })
        .inputValue(),
      "Préparation à conserver",
    );
    assert.equal(x.sent.length, 1);
  } finally {
    await x.close();
  }
});

test("SPORT-12 stage, composition and scores survive Escape, reload and offline use", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    await x.page.getByLabel("Score B", { exact: true }).fill("3");
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("À reprendre");
    await x.page.keyboard.press("Escape");
    await x.page.reload();
    await x.page
      .getByRole("heading", { name: x.data.name, exact: true })
      .waitFor();
    await flow(x.page);
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[3], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    assert.equal(
      await x.page.getByLabel("Score B", { exact: true }).inputValue(),
      "3",
    );
    assert.equal(
      await x.page
        .getByLabel("Notes de la séance", { exact: true })
        .inputValue(),
      "À reprendre",
    );
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    await x.page.evaluate(async () => {
      await navigator.serviceWorker.ready;
      if (!navigator.serviceWorker.controller)
        await new Promise((resolve) =>
          navigator.serviceWorker.addEventListener(
            "controllerchange",
            resolve,
            { once: true },
          ),
        );
    });
    await x.context.setOffline(true);
    await x.page.reload();
    await x.page
      .getByRole("heading", { name: x.data.name, exact: true })
      .waitFor();
    await flow(x.page);
    await x.page
      .getByRole("button", { name: "Augmenter le score B", exact: true })
      .click();
    assert.equal(
      await x.page.getByLabel("Score B", { exact: true }).inputValue(),
      "4",
    );
    assert.equal(x.sent.length, 0);
  } finally {
    await x.close();
  }
});

test("SPORT-12/13/14 existing session opens on match without catalogue, includes its archived participant", async () => {
  const x = await boot({ existing: true, noCatalogue: true, historical: true });
  try {
    await flow(x.page, true);
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[3], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Ancien joueur",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page
        .getByLabel("Buts de Ancien joueur", { exact: true })
        .isVisible(),
      true,
    );
    await step(x.page, 1);
    assert.equal(
      await x.page
        .getByLabel("Présent : Ancien joueur", { exact: true })
        .isChecked(),
      true,
    );
    await step(x.page, 3);
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
    await confirm(x.page);
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    assert.equal(x.sent[0].base_revision, 2);
    assert.equal(x.sent[0].payload.session.status, "CANCELLED");
  } finally {
    await x.close();
  }
});

for (const options of [
  { roles: ["SGA"] },
  { roles: ["TR"] },
  { roles: ["ADMIN"] },
  { roles: ["SG"], shared: true },
  { roles: ["SG"], existing: true, owner: "other" },
  { roles: ["SG"], existing: true, conflict: true },
]) {
  test(
    "SPORT-13 permissions remain explicit " + JSON.stringify(options),
    async () => {
      const x = await boot(options);
      try {
        const allowed = options.roles.includes("SGA") && !options.shared;
        if (options.existing) {
          await x.page
            .getByRole("button", { name: "Voir la séance", exact: true })
            .click();
          assert.equal(
            await x.page
              .getByRole("button", { name: "Modifier la séance", exact: true })
              .count(),
            0,
          );
        } else
          assert.equal(
            await x.page
              .getByRole("button", { name: "Nouvelle séance", exact: true })
              .count(),
            allowed ? 1 : 0,
          );
        assert.equal(x.sent.length, 0);
      } finally {
        await x.close();
      }
    },
  );
}

test("SPORT-14 empty roster has an actionable state rather than empty composition", async () => {
  const x = await boot({ count: 0 });
  try {
    await flow(x.page);
    await step(x.page, 1);
    await x.page
      .getByText("Aucun membre actif dans ce groupe.", { exact: true })
      .waitFor();
    assert.equal(
      await x.page
        .getByRole("button", {
          name: "Sélectionner les joueurs affichés",
          exact: true,
        })
        .isDisabled(),
      true,
    );
    assert.equal(x.sent.length, 0);
  } finally {
    await x.close();
  }
});

test("SPORT-02/10 invalid options and duplicate colors guide correction without any request", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await x.page.getByLabel("Date et heure", { exact: true }).fill("");
    await x.page.getByRole("button", { name: "Suivant", exact: true }).click();
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[0], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    await x.page
      .getByLabel("Date et heure", { exact: true })
      .fill("2026-10-20T18:30");
    await compose(x.page);
    await step(x.page, 2);
    const blue = await x.page
      .getByLabel("Couleur A", { exact: true })
      .inputValue();
    await x.page.getByLabel("Couleur B", { exact: true }).selectOption(blue);
    await step(x.page, 3);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    assert.equal(
      await x.page
        .getByRole("button", { name: steps[2], exact: true })
        .getAttribute("aria-current"),
      "step",
    );
    assert.match(
      await x.page.getByRole("alert").innerText(),
      /couleurs différentes/i,
    );
  } finally {
    await x.close();
  }
});

test("SPORT-10 tournament refuses zero wins then keeps a draw and the chosen format on publication", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await x.page
      .getByLabel("Format de jeu", { exact: true })
      .selectOption("TOURNAMENT_3");
    await compose(x.page);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    assert.match(await x.page.getByRole("alert").innerText(), /victoire/i);
    await x.page.getByLabel("Victoires A", { exact: true }).fill("2");
    await x.page.getByLabel("Victoires B", { exact: true }).fill("2");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await confirm(x.page);
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    assert.equal(x.sent[0].payload.session.result, "DRAW_AB");
    assert.equal(x.sent[0].payload.session.score_a, null);
  } finally {
    await x.close();
  }
});

test("SPORT-10 unequal teams need the existing explicit option, and invalid numeric input is never published", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    await step(x.page, 2);
    for (const name of names.slice(0, 6))
      await x.page
        .getByLabel("Équipe de " + name, { exact: true })
        .selectOption("A");
    await step(x.page, 3);
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.match(await x.page.getByRole("alert").innerText(), /déséquilibr/i);
    assert.equal(x.sent.length, 0);
    await step(x.page, 0);
    await x.page
      .getByLabel("Autoriser les équipes inégales", { exact: true })
      .check();
    await step(x.page, 3);
    for (const value of ["-1", "1.5"]) {
      await x.page.getByLabel("Score A", { exact: true }).fill(value);
      await x.page
        .getByRole("button", { name: "Clôturer la séance", exact: true })
        .click();
      assert.equal(x.sent.length, 0);
      assert.equal(
        await x.page
          .getByLabel("Score A", { exact: true })
          .evaluate((n) => n.checkValidity()),
        false,
      );
    }
    await x.page.getByLabel("Score A", { exact: true }).fill("0");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await confirm(x.page);
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    assert.equal(x.sent[0].payload.session.allow_uneven_teams, 1);
  } finally {
    await x.close();
  }
});

test("SPORT-11/13 correcting a closed session keeps the original revision and requires a reason", async () => {
  const x = await boot({ existing: true, status: "CLOSED" });
  try {
    await flow(x.page, true);
    await x.page.getByLabel("Score A", { exact: true }).fill("1");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    await x.page
      .getByLabel("Motif de correction", { exact: true })
      .fill("But ajouté après vérification");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    await confirm(x.page);
    await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    assert.equal(x.sent[0].base_revision, 2);
    assert.equal(x.sent[0].reason, "But ajouté après vérification");
  } finally {
    await x.close();
  }
});

test("SPORT-12 a legacy draft without a step retains data, and a stale sport draft still cannot publish", async () => {
  const x = await boot({ existing: true });
  try {
    await flow(x.page, true);
    await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .fill("Ancien brouillon à garder");
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    await x.page.evaluate(() => {
      const key = Object.keys(localStorage).find((k) =>
        k.endsWith("draft:sport:ref"),
      );
      const saved = JSON.parse(localStorage.getItem(key));
      delete saved.step;
      localStorage.setItem(key, JSON.stringify(saved));
    });
    x.data.documents["sport:ref"].revision = 5;
    await x.page
      .getByRole("button", { name: "Actualiser", exact: true })
      .click();
    await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
    await flow(x.page, true);
    await step(x.page, 3);
    assert.equal(
      await x.page
        .getByLabel("Notes de la séance", { exact: true })
        .inputValue(),
      "Ancien brouillon à garder",
    );
    await x.page
      .getByLabel("Motif de correction", { exact: true })
      .fill("Correction");
    await x.page
      .getByRole("button", { name: "Clôturer la séance", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    assert.match(await x.page.getByRole("alert").innerText(), /périm|version/i);
  } finally {
    await x.close();
  }
});

test("SPORT-16 clicking a counter caption focuses its number input rather than a neighboring button", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await step(x.page, 3);
    const score = x.page.getByLabel("Score A", { exact: true });
    await x.page
      .locator(".sport-counter label")
      .first()
      .click({ position: { x: 4, y: 4 } });
    assert.equal(
      await score.evaluate((n) => n === document.activeElement),
      true,
    );
    await x.page
      .getByRole("button", { name: "Augmenter le score A", exact: true })
      .focus();
    await x.page
      .getByRole("button", { name: "Augmenter le score A", exact: true })
      .press("Enter");
    assert.equal(await score.inputValue(), "1");
    assert.equal(
      await x.page
        .getByRole("button", { name: "Augmenter le score A", exact: true })
        .evaluate((n) => n === document.activeElement),
      true,
    );
  } finally {
    await x.close();
  }
});

test("SPORT-17 legacy invalid draw points guide back to the Options field", async () => {
  for (const value of [-1, 1.5]) {
    const x = await boot({ existing: true });
    try {
      const s = x.data.documents["sport:ref"].payload.session;
      s.session_type = "TOURNAMENT_3";
      s.draw_points = value;
      s.wins_a = 1;
      await x.page
        .getByRole("button", { name: "Actualiser", exact: true })
        .click();
      await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
      await flow(x.page, true);
      await x.page
        .getByLabel("Motif de correction", { exact: true })
        .fill("Corriger le barème");
      await x.page
        .getByRole("button", { name: "Clôturer la séance", exact: true })
        .click();
      assert.equal(x.sent.length, 0);
      assert.equal(
        await x.page
          .getByRole("button", { name: steps[0], exact: true })
          .getAttribute("aria-current"),
        "step",
      );
      assert.equal(
        await x.page
          .getByLabel("Points pour un nul", { exact: true })
          .isVisible(),
        true,
      );
      assert.equal(
        await x.page
          .getByLabel("Points pour un nul", { exact: true })
          .inputValue(),
        String(value),
      );
    } finally {
      await x.close();
    }
  }
});

test("SPORT-18 narrow action bars keep complete words and visible actions", async () => {
  for (const width of [320, 390]) {
    const x = await boot({ width });
    try {
      await x.page.setViewportSize({ width, height: 640 });
      await flow(x.page);
      await step(x.page, 1);
      const save = x.page.getByRole("button", {
        name: "Enregistrer le brouillon",
        exact: true,
      });
      const fragments = await save.evaluate((n) => {
        const walker = document.createTreeWalker(n, NodeFilter.SHOW_TEXT);
        let text;
        while ((text = walker.nextNode()))
          if (text.textContent.includes("Enregistrer")) break;
        if (!text) throw Error("Libellé Enregistrer absent du bouton.");
        const start = text.textContent.indexOf("Enregistrer");
        const range = document.createRange();
        range.setStart(text, start);
        range.setEnd(text, start + "Enregistrer".length);
        return range.getClientRects().length;
      });
      assert.equal(
        fragments,
        1,
        "Le mot Enregistrer ne doit pas être cassé sur plusieurs lignes.",
      );
      for (const label of [
        "Précédent",
        "Suivant",
        "Enregistrer le brouillon",
      ]) {
        const box = await x.page
          .getByRole("button", { name: label, exact: true })
          .boundingBox();
        assert.ok(box.y >= 0 && box.y + box.height <= 640);
      }
      await step(x.page, 3);
      const close = await x.page
        .getByRole("button", { name: "Clôturer la séance", exact: true })
        .boundingBox();
      assert.ok(close.y >= 0 && close.y + close.height <= 640);
    } finally {
      await x.close();
    }
  }
});

test("SPORT-19 a player archived during an unpublished preparation can be explicitly restored with their statistics", async () => {
  const x = await boot();
  try {
    await flow(x.page);
    await compose(x.page);
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Alice",
        exact: true,
      })
      .click();
    await x.page.getByLabel("Buts de Alice", { exact: true }).fill("2");
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    x.data.members[0].is_active = 0;
    await x.page
      .getByRole("button", { name: "Actualiser", exact: true })
      .click();
    await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
    await flow(x.page);
    await step(x.page, 1);
    await x.page.getByLabel("Présent : Alice", { exact: true }).click();
    assert.equal(
      await x.page.getByLabel("Présent : Alice", { exact: true }).count(),
      1,
      "Un ancien présent archivé doit rester disponible pour une réintégration explicite.",
    );
    await x.page
      .getByRole("button", {
        name: "Sélectionner les joueurs affichés",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Présent : Alice", { exact: true }).isChecked(),
      false,
    );
    await x.page.getByLabel("Présent : Alice", { exact: true }).check();
    await step(x.page, 3);
    await x.page
      .getByRole("button", {
        name: "Modifier les statistiques de Alice",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Buts de Alice", { exact: true }).inputValue(),
      "2",
    );
    assert.equal(x.sent.length, 0);
  } finally {
    await x.close();
  }
});
