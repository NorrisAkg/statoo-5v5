import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { sportStep } from "./sport-helpers.mjs";

const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
let browser;
before(async () => {
  browser = await chromium.launch({ channel: "chrome", headless: true });
});
after(async () => {
  await browser?.close();
});

function fixture(shared = false) {
  const account = { id: "me", roles: ["SG", "TR", "ADMIN"], shared };
  const document = (id, name, status = "CLOSED") => ({
    domain: "sport",
    occurrence_id: id,
    owner: "me",
    revision: 1,
    generation: 0,
    candidates: [],
    payload: {
      session: {
        id,
        played_at: "2026-10-15T20:00:00",
        status,
        session_type: "CLASSIC_2",
        team_names: { A: name, B: "Union du Port" },
        score_a: 0,
        score_b: 0,
      },
      participations: [],
    },
  });
  return {
    name: "Groupe stabilité",
    account,
    members: Array.from({ length: 24 }, (_, i) => ({
      id: "m" + i,
      name: "Joueur " + String(i + 1).padStart(2, "0"),
      is_active: 1,
    })),
    leaders: [],
    accounts: [],
    opening: { cash: 0, members: {} },
    opening_proposal: null,
    financial_settings: { contribution: 100, late_penalty: 0 },
    sport_settings: { min_players_per_session: 6 },
    finances: { cash: 0, members: {} },
    obligations: {},
    documents: {
      "sport:a": document("a", "Atlas"),
      "sport:b": document("b", "Racing", "DRAFT"),
      "sport:c": document("c", "Atlas annulé", "CANCELLED"),
    },
  };
}

async function boot(width, shared = false) {
  const context = await browser.newContext({
      viewport: { width, height: 900 },
    }),
    page = await context.newPage();
  const snapshot = fixture(shared);
  let reads = 0,
    delayed;
  await page.route("**/groups/g", async (route) => {
    reads++;
    if (delayed) {
      const wait = delayed;
      delayed = null;
      await wait;
    }
    await route.fulfill({ json: snapshot });
  });
  await page.addInitScript(
    ({ base, account }) => {
      sessionStorage.setItem(
        "statoo-connection",
        JSON.stringify({
          api: base,
          group: "g",
          token: "synthetic",
          expires_at: "2099-01-01T00:00:00Z",
          account,
        }),
      );
      const original = window.setInterval;
      window.setInterval = (callback, ms, ...args) => {
        if (ms === 45000) window.stabilityRefresh = callback;
        return original(callback, ms, ...args);
      };
      window.stabilityConsumedReads = 0;
      const fetch = window.fetch.bind(window);
      window.fetch = async (...args) => {
        const response = await fetch(...args);
        const url = new URL(
          args[0] instanceof Request ? args[0].url : args[0],
          location.href,
        );
        if (url.pathname === "/groups/g") {
          for (const method of ["text", "json"]) {
            const consume = response[method].bind(response);
            response[method] = async (...parameters) => {
              try {
                return await consume(...parameters);
              } finally {
                window.stabilityConsumedReads++;
              }
            };
          }
        }
        return response;
      };
    },
    { base, account: snapshot.account },
  );
  await page.goto(base + "/portal/");
  await page
    .getByRole("heading", { name: snapshot.name, exact: true })
    .waitFor();
  await page.waitForFunction(() => !!window.stabilityRefresh);
  return {
    page,
    snapshot,
    context,
    reads: () => reads,
    delay: (promise) => {
      delayed = promise;
    },
    close: () => context.close(),
  };
}

async function filter(page) {
  await page.getByRole("button", { name: "Séances", exact: true }).click();
  await page.getByLabel("État", { exact: true }).selectOption("CLOSED");
  await page.getByLabel("Rechercher une séance", { exact: true }).fill("Atlas");
}

async function periodicRefresh(page) {
  const before = await page.evaluate(() => window.stabilityConsumedReads);
  await page.evaluate(() => window.stabilityRefresh());
  // The next browser task runs after response consumption and the refresh's
  // promise continuations, including its optional render, have completed.
  await page.waitForFunction(
    (count) => window.stabilityConsumedReads > count,
    before,
  );
}

for (const width of [390, 1440]) {
  test(`STAB-01/02 filters, focus and text selection survive refresh at ${width}px`, async () => {
    const x = await boot(width, width === 1440);
    try {
      await filter(x.page);
      const search = x.page.getByLabel("Rechercher une séance", {
        exact: true,
      });
      await search.evaluate((n) => {
        n.focus();
        n.setSelectionRange(1, 3);
      });
      const added = structuredClone(x.snapshot.documents["sport:a"]);
      added.occurrence_id = added.payload.session.id = "new";
      x.snapshot.documents["sport:new"] = added;
      await periodicRefresh(x.page);
      assert.equal(await search.inputValue(), "Atlas");
      assert.equal(
        await x.page.getByLabel("État", { exact: true }).inputValue(),
        "CLOSED",
      );
      assert.equal(
        await x.page
          .getByRole("button", { name: "Voir la séance", exact: true })
          .count(),
        2,
      );
      assert.deepEqual(
        await search.evaluate((n) => ({
          focused: n === document.activeElement,
          start: n.selectionStart,
          end: n.selectionEnd,
        })),
        { focused: true, start: 1, end: 3 },
      );
      await x.page
        .getByRole("button", { name: "Actualiser", exact: true })
        .click();
      await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
      assert.equal(await search.inputValue(), "Atlas");
      await x.page
        .getByRole("button", { name: "Accueil", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Séances", exact: true })
        .click();
      assert.equal(await search.inputValue(), "Atlas");
      await search.fill("");
      await x.page.getByLabel("État", { exact: true }).selectOption("all");
      assert.equal(
        await x.page
          .getByRole("button", { name: "Voir la séance", exact: true })
          .count(),
        4,
      );
      await search.fill("Aucun résultat XYZ");
      await periodicRefresh(x.page);
      await x.page
        .getByText("Aucune séance pour ce filtre.", { exact: true })
        .waitFor();
      assert.equal(await search.inputValue(), "Aucun résultat XYZ");
    } finally {
      await x.close();
    }
  });

  test(`STAB-03 sport composition keeps focus, values and dialog scroll at ${width}px`, async () => {
    const x = await boot(width);
    try {
      await x.page
        .getByRole("button", { name: "Nouvelle séance", exact: true })
        .click();
      await sportStep(x.page, 2);
      const first = x.page.getByLabel("Présent : Joueur 01", { exact: true });
      await first.focus();
      await first.press("Space");
      assert.equal(
        await first.evaluate((n) => document.activeElement === n),
        true,
      );
      await sportStep(x.page, 4);
      await x.page
        .getByRole("button", {
          name: "Modifier les statistiques de Joueur 01",
          exact: true,
        })
        .click();
      await x.page.getByLabel("Buts de Joueur 01", { exact: true }).fill("2");
      await sportStep(x.page, 2);
      const last = x.page.getByLabel("Présent : Joueur 24", { exact: true });
      await last.scrollIntoViewIfNeeded();
      await last.focus();
      const scroll = await x.page
        .locator(".sport-dialog .dialog-body")
        .evaluate((n) => n.scrollTop);
      await last.press("Space");
      assert.equal(
        await last.evaluate((n) => document.activeElement === n),
        true,
      );
      assert.ok(
        Math.abs(
          (await x.page
            .locator(".sport-dialog .dialog-body")
            .evaluate((n) => n.scrollTop)) - scroll,
        ) < 4,
      );
      await last.press("Space");
      assert.equal(await last.isChecked(), false);
      assert.equal(
        await last.evaluate((n) => document.activeElement === n),
        true,
      );
      await sportStep(x.page, 4);
      await x.page
        .getByRole("button", {
          name: "Modifier les statistiques de Joueur 01",
          exact: true,
        })
        .click();
      assert.equal(
        await x.page
          .getByLabel("Buts de Joueur 01", { exact: true })
          .inputValue(),
        "2",
      );
      await sportStep(x.page, 2);
      await first.click();
      assert.equal(await first.isChecked(), false);
      assert.equal(
        await first.evaluate((n) => document.activeElement === n),
        true,
      );
      await sportStep(x.page, 1);
      const format = x.page.getByLabel("Format de jeu", { exact: true });
      await format.focus();
      await format.selectOption("TOURNAMENT_3");
      assert.equal(
        await format.evaluate((n) => document.activeElement === n),
        true,
      );
      assert.equal(await format.inputValue(), "TOURNAMENT_3");
    } finally {
      await x.close();
    }
  });

  test(`STAB-04 finance recomposition keeps action focus and entered amounts at ${width}px`, async () => {
    const x = await boot(width);
    try {
      await x.page
        .getByRole("button", { name: "Nouveau point financier", exact: true })
        .click();
      await x.page
        .getByLabel("Cotisation de Joueur 01", { exact: true })
        .fill("300");
      for (const action of ["Ajouter une dépense", "Ajouter un don"]) {
        const add = x.page.getByRole("button", { name: action, exact: true });
        await add.scrollIntoViewIfNeeded();
        await add.focus();
        await add.press("Enter");
        assert.equal(
          await add.evaluate((n) => n === document.activeElement),
          true,
        );
        assert.equal(
          await x.page
            .getByLabel("Cotisation de Joueur 01", { exact: true })
            .inputValue(),
          "300",
        );
      }
      for (const [remove, add] of [
        ["Retirer dépense 1", "Ajouter une dépense"],
        ["Retirer don 1", "Ajouter un don"],
      ]) {
        await x.page.getByRole("button", { name: remove, exact: true }).click();
        assert.equal(
          await x.page
            .getByRole("button", { name: add, exact: true })
            .evaluate((n) => n === document.activeElement),
          true,
        );
        assert.equal(
          await x.page
            .getByLabel("Cotisation de Joueur 01", { exact: true })
            .inputValue(),
          "300",
        );
      }
    } finally {
      await x.close();
    }
  });
}

test("STAB-05 late background refresh does not rebuild behind a newly opened dialog", async () => {
  const x = await boot(390);
  let release;
  try {
    x.delay(
      new Promise((resolve) => {
        release = resolve;
      }),
    );
    const consumed = await x.page.evaluate(() => window.stabilityConsumedReads);
    const read = x.page.waitForRequest((r) => r.url() === base + "/groups/g");
    await x.page.evaluate(() => window.stabilityRefresh());
    await read;
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await sportStep(x.page, 4);
    const notes = x.page.getByLabel("Notes de la séance", { exact: true });
    await notes.fill("Notes protégées");
    await x.page.locator("#content").evaluate((n) => {
      n.dataset.stabilitySentinel = "unchanged";
      n.firstElementChild.dataset.stabilitySentinel = "unchanged";
    });
    release();
    await x.page.waitForFunction(
      (count) => window.stabilityConsumedReads > count,
      consumed,
    );
    assert.equal(
      await x.page
        .locator("#content > :first-child")
        .getAttribute("data-stability-sentinel"),
      "unchanged",
    );
    assert.equal(await notes.inputValue(), "Notes protégées");
    assert.equal(
      await notes.evaluate((n) => n === document.activeElement),
      true,
    );
    const count = x.reads();
    await x.page.evaluate(() => window.stabilityRefresh());
    assert.equal(x.reads(), count);
  } finally {
    release?.();
    await x.close();
  }
});

test("STAB-01 an empty search result survives periodic refresh", async () => {
  const x = await boot(390);
  try {
    await filter(x.page);
    await x.page
      .getByLabel("Rechercher une séance", { exact: true })
      .fill("Aucun résultat XYZ");
    await periodicRefresh(x.page);
    assert.equal(
      await x.page
        .getByLabel("Rechercher une séance", { exact: true })
        .inputValue(),
      "Aucun résultat XYZ",
    );
    assert.equal(
      await x.page
        .getByRole("button", { name: "Voir la séance", exact: true })
        .count(),
      0,
    );
  } finally {
    await x.close();
  }
});

test("STAB-04 removing the last expense returns focus to adding an expense", async () => {
  const x = await boot(390);
  try {
    await x.page
      .getByRole("button", { name: "Nouveau point financier", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Ajouter une dépense", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Retirer dépense 1", exact: true })
      .click();
    assert.equal(
      await x.page
        .getByRole("button", { name: "Ajouter une dépense", exact: true })
        .evaluate((n) => n === document.activeElement),
      true,
    );
  } finally {
    await x.close();
  }
});

test("STAB-06 changing account resets in-memory session filters", async () => {
  const x = await boot(390);
  try {
    await filter(x.page);
    await x.page.route("**/auth/logout", (r) =>
      r.fulfill({ json: { ok: true } }),
    );
    await x.page
      .getByRole("button", { name: "Se déconnecter", exact: true })
      .click();
    await x.page
      .getByRole("heading", { name: "Retrouver votre groupe", exact: true })
      .waitFor();
    // Use a genuine login in this same JS document: no reload that would reset state by itself.
    await x.page.route("**/auth/login", (r) =>
      r.fulfill({
        json: {
          group_id: "g",
          token: "other",
          expires_at: "2099-01-01T00:00:00Z",
          account: { ...x.snapshot.account, id: "other" },
        },
      }),
    );
    x.snapshot.account = { ...x.snapshot.account, id: "other" };
    await x.page.getByLabel("Identifiant du groupe", { exact: true }).fill("g");
    await x.page
      .getByLabel("Identifiant de connexion", { exact: true })
      .fill("other");
    await x.page.getByLabel("Mot de passe", { exact: true }).fill("password");
    await x.page
      .getByRole("button", { name: "Se connecter", exact: true })
      .click();
    await x.page
      .getByRole("heading", { name: x.snapshot.name, exact: true })
      .waitFor();
    await x.page.getByRole("button", { name: "Séances", exact: true }).click();
    assert.equal(
      await x.page
        .getByLabel("Rechercher une séance", { exact: true })
        .inputValue(),
      "",
    );
    assert.equal(
      await x.page.getByLabel("État", { exact: true }).inputValue(),
      "all",
    );
  } finally {
    await x.close();
  }
});

test("STAB-07 a previously loaded PWA keeps interactive forms available offline after reload", async () => {
  const x = await boot(390);
  try {
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
    await x.page.getByRole("button", { name: "Séances", exact: true }).click();
    await x.context.setOffline(true);
    await x.page.reload();
    await x.page
      .getByRole("heading", { name: x.snapshot.name, exact: true })
      .waitFor();
    await x.page
      .getByRole("button", { name: "Nouvelle séance", exact: true })
      .click();
    await sportStep(x.page, 2);
    const present = x.page.getByLabel("Présent : Joueur 01", { exact: true });
    await present.focus();
    await present.press("Space");
    assert.equal(await present.isChecked(), true);
    assert.equal(
      await present.evaluate((n) => n === document.activeElement),
      true,
    );
  } finally {
    await x.close();
  }
});
