import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
let browser;
before(
  async () =>
    (browser = await chromium.launch({ channel: "chrome", headless: true })),
);
after(async () => await browser?.close());
const account = {
  id: "me",
  username: "admin",
  roles: ["ADMIN", "SG", "TR", "PDT"],
  shared: false,
};
function data() {
  return {
    name: "Chargement",
    account,
    members: [{ id: "a", name: "Alice", is_active: 1 }],
    accounts: [account],
    leaders: [account],
    documents: {},
    obligations: {},
    opening: { cash: 0, members: {} },
    finances: { cash: 0, members: {} },
    financial_settings: { contribution: 100, late_penalty: 0 },
    sport_settings: { min_players_per_session: 6 },
  };
}
async function boot({
  logged = true,
  width = 390,
  light = false,
  reducedMotion = "no-preference",
  opening = true,
  pending = false,
} = {}) {
  const context = await browser.newContext({
      viewport: { width, height: 900 },
      colorScheme: light ? "light" : "dark",
      reducedMotion,
      serviceWorkers: "block",
    }),
    page = await context.newPage(),
    snapshot = data();
  if (!opening) snapshot.opening = null;
  const requests = [];
  let delayed = null,
    status = 200;
  await page.route("**/config.json", (r) =>
    r.fulfill({ json: { api_url: base } }),
  );
  await page.route("**/groups/g", async (r) => {
    requests.push("read");
    const gate = delayed;
    if (gate) await gate;
    await r
      .fulfill({
        status,
        json: status === 200 ? snapshot : { detail: "Indisponible" },
      })
      .catch(() => {});
  });
  await page.route("**/groups/g/**", async (r) => {
    requests.push(r.request().url());
    const gate = delayed;
    if (gate) await gate;
    await r
      .fulfill({
        status,
        json:
          status === 200
            ? { ok: true, status: "accepted", revision: 1 }
            : { detail: "Refus de test" },
      })
      .catch(() => {});
  });
  await page.route("**/auth/login", async (r) => {
    requests.push("login");
    const gate = delayed;
    if (gate) await gate;
    await r
      .fulfill({
        status,
        json:
          status === 200
            ? {
                group_id: "g",
                token: "synthetic",
                expires_at: "2099-01-01",
                account,
              }
            : { detail: "Accès refusé" },
      })
      .catch(() => {});
  });
  await page.route("**/auth/logout", async (r) => {
    requests.push("logout");
    const gate = delayed;
    if (gate) await gate;
    await r.fulfill({ json: { ok: true } }).catch(() => {});
  });
  await page.addInitScript(
    ({ base, logged, account, pending }) => {
      if (logged)
        sessionStorage.setItem(
          "statoo-connection",
          JSON.stringify({
            api: base,
            group: "g",
            token: "synthetic",
            expires_at: "2099-01-01",
            account,
          }),
        );
      if (pending)
        localStorage.setItem(
          "statoo:" + encodeURIComponent(base) + "|g|me:pending",
          JSON.stringify([
            {
              domain: "sport",
              operation_id: "synthetic-operation",
              occurrence_id: "ref",
              base_revision: 0,
              generation: 0,
              reason: "",
              payload: {},
            },
          ]),
        );
    },
    { base, logged, account, pending },
  );
  await page.addInitScript(() =>
    localStorage.setItem("statoo-onboarding-complete", "1"),
  );
  await page.goto(base + "/portal/");
  await page
    .getByRole("heading", {
      name: logged ? "Chargement" : "Retrouver votre groupe",
      exact: true,
    })
    .waitFor();
  if (logged)
    await page.waitForFunction(
      () =>
        document.querySelector(".sync-time")?.textContent &&
        !document
          .querySelector(".sync-time")
          .textContent.includes("à actualiser"),
    );
  return {
    page,
    requests,
    snapshot,
    delay(code = 200) {
      status = code;
      let release;
      delayed = new Promise((done) => (release = done));
      return () => {
        delayed = null;
        release();
      };
    },
    close: () => context.close(),
  };
}
async function busy(button) {
  assert.equal(await button.getAttribute("aria-busy"), "true");
  assert.equal(await button.isDisabled(), true);
  assert.equal(await button.locator(".button-spinner").count(), 1);
  assert.equal(await button.locator(".button-spinner").isVisible(), true);
}
for (const status of [200, 503])
  test(
    "LOAD-01 refresh loading state, duplicate protection and reset status=" +
      status,
    async () => {
      const x = await boot();
      let release;
      try {
        release = x.delay(status);
        const b = x.page.getByRole("button", {
          name: "Actualiser",
          exact: true,
        });
        const reads = x.requests.length;
        await b.click();
        await busy(b);
        await b.evaluate((n) => n.click());
        assert.equal(x.requests.length, reads + 1);
        release();
        await x.page.waitForFunction(
          () => !document.querySelector('button[aria-busy="true"]'),
        );
        assert.equal(
          await x.page
            .getByRole("button", { name: "Actualiser", exact: true })
            .isDisabled(),
          false,
        );
      } finally {
        release?.();
        await x.close();
      }
    },
  );
test("LOAD-02 login loader blocks repeated Enter and resets after authentication failure", async () => {
  const x = await boot({ logged: false });
  let release;
  try {
    await x.page.getByLabel("Identifiant du groupe", { exact: true }).fill("g");
    await x.page
      .getByLabel("Identifiant de connexion", { exact: true })
      .fill("admin");
    await x.page.getByLabel("Mot de passe", { exact: true }).fill("password");
    release = x.delay(401);
    const b = x.page.getByRole("button", { name: "Se connecter", exact: true });
    await b.click();
    await busy(b);
    await x.page
      .locator("form")
      .evaluate((n) =>
        n.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true }),
        ),
      );
    assert.equal(x.requests.filter((r) => r === "login").length, 1);
    release();
    await x.page.getByText("Accès refusé", { exact: true }).waitFor();
    assert.equal(await b.isDisabled(), false);
    assert.notEqual(await b.getAttribute("aria-busy"), "true");
  } finally {
    release?.();
    await x.close();
  }
});
test("LOAD-03 modal locks concurrent actions, restores inputs after refusal and allows retry", async () => {
  const x = await boot();
  let release;
  try {
    await x.page.getByRole("button", { name: "Membres", exact: true }).click();
    await x.page
      .getByRole("button", { name: "Ajouter un membre", exact: true })
      .click();
    await x.page.getByLabel("Nom du membre", { exact: true }).fill("Diane");
    const submit = x.page.getByRole("button", {
      name: "Enregistrer",
      exact: true,
    });
    await submit.click();
    await x.page
      .getByRole("button", { name: "Revenir à la saisie", exact: true })
      .click();
    assert.equal(await submit.isDisabled(), false);
    await submit.click();
    release = x.delay(422);
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await busy(submit);
    assert.equal(
      await x.page
        .getByRole("button", { name: "Fermer", exact: true })
        .isDisabled(),
      true,
    );
    await x.page.keyboard.press("Escape");
    assert.equal(
      await x.page.getByRole("dialog").count(),
      1,
      "Échap ne doit pas masquer une publication en cours.",
    );
    release();
    await x.page.waitForFunction(
      () => !document.querySelector('button[aria-busy="true"]'),
    );
    assert.equal(
      await x.page.getByLabel("Nom du membre", { exact: true }).inputValue(),
      "Diane",
    );
    assert.equal(await submit.isDisabled(), false);
    x.delay(200)();
    await submit.click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page
      .getByText("Modification enregistrée.", { exact: true })
      .waitFor();
  } finally {
    release?.();
    await x.close();
  }
});
for (const name of ["Se déconnecter", "Réessayer les envois"])
  test("LOAD-04 loader for " + name, async () => {
    const x = await boot({ pending: name.startsWith("Réessayer") });
    let release;
    try {
      release = x.delay();
      const b = x.page.getByRole("button", { name, exact: true });
      await b.click();
      await busy(b);
      release();
      await x.page.waitForFunction(
        () => !document.querySelector('button[aria-busy="true"]'),
      );
    } finally {
      release?.();
      await x.close();
    }
  });
for (const [width, light] of [
  [320, true],
  [390, false],
  [1440, true],
])
  test(
    "LOAD-06 stable dimensions and reduced-motion loading " + width,
    async () => {
      const x = await boot({ width, light, reducedMotion: "reduce" });
      let release;
      try {
        const b = x.page.getByRole("button", {
            name: "Actualiser",
            exact: true,
          }),
          before = await b.boundingBox();
        release = x.delay();
        await b.click();
        await busy(b);
        const after = await b.boundingBox();
        assert.equal(after.width, before.width);
        assert.equal(after.height, before.height);
        assert.equal(
          await b
            .locator(".button-spinner")
            .evaluate((n) => getComputedStyle(n).animationName),
          "none",
        );
      } finally {
        release?.();
        await x.close();
      }
    },
  );
test("ZOD-06 client validation is French, field-linked, corrected and sends nothing invalid", async () => {
  const x = await boot({ logged: false });
  try {
    await x.page.getByLabel("Identifiant du groupe", { exact: true }).fill("g");
    await x.page
      .getByLabel("Identifiant de connexion", { exact: true })
      .fill("a".repeat(101));
    await x.page.getByLabel("Mot de passe", { exact: true }).fill("password");
    await x.page
      .getByRole("button", { name: "Se connecter", exact: true })
      .click();
    assert.equal(x.requests.filter((r) => r === "login").length, 0);
    const user = x.page.getByLabel("Identifiant de connexion", { exact: true });
    assert.equal(await user.getAttribute("aria-invalid"), "true");
    const error = await x.page.locator('form [role="alert"]').innerText();
    assert.match(error, /identifiant|100|caractères/i);
    assert.equal(error.includes("password"), false);
    const id = await user.getAttribute("aria-describedby");
    assert.ok(id);
    assert.ok(await x.page.locator("#" + id).innerText());
    assert.equal(
      await x.page.getByLabel("Mot de passe", { exact: true }).inputValue(),
      "password",
    );
    await user.fill("admin");
    await x.page
      .getByRole("button", { name: "Se connecter", exact: true })
      .click();
    await x.page
      .getByRole("heading", { name: "Chargement", exact: true })
      .waitFor();
  } finally {
    await x.close();
  }
});
