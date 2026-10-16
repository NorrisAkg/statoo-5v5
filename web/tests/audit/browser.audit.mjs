import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085",
  results = [];
const shots = resolve("mobile/build/pwa-audit");
mkdirSync(shots, { recursive: true });
let browser;
before(
  async () =>
    (browser = await chromium.launch({ channel: "chrome", headless: true })),
);
after(async () => {
  await browser?.close();
  const dir = new URL(
    "../../../docs/web-audit-corrections-results/",
    import.meta.url,
  );
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    new URL("browser-results.json", dir),
    JSON.stringify(results, null, 2) + "\n",
  );
});
function data() {
  return {
    name: "Groupe audit PWA",
    account: { id: "me", roles: ["ADMIN", "SG", "TR"], shared: false },
    members: [
      { id: "a", name: "Alice", is_active: 1 },
      { id: "b", name: "Bob", is_active: 1 },
      { id: "c", name: "Camille", is_active: 1 },
    ],
    leaders: [],
    accounts: [],
    opening: { cash: 0, members: {} },
    opening_proposal: null,
    documents: {},
    obligations: {},
    finances: { cash: 0, members: {} },
    financial_settings: { contribution: 100, late_penalty: 0 },
  };
}
const sport = {
  domain: "sport",
  occurrence_id: "ref",
  owner: "me",
  revision: 1,
  generation: 0,
  candidates: [],
  payload: {
    session: {
      id: "s",
      team_id: "g",
      played_at: "2026-10-15T20:00:00",
      status: "CLOSED",
      session_type: "TOURNAMENT_3",
      wins_a: 3,
      wins_b: 2,
      wins_c: 1,
      team_names: {
        A: "Racing Atlas",
        B: "Union des Cèdres",
        C: "Sporting du Port",
      },
      team_colors: { A: 0xfffacc15, B: 0xff06b6d4, C: 0xffec4899 },
    },
    participations: [],
  },
};
function financial() {
  return {
    domain: "finance",
    occurrence_id: "ref",
    owner: "me",
    revision: 1,
    generation: 0,
    candidates: [],
    payload: {
      played_at: "2026-10-15T20:00:00",
      rate: 100,
      cancelled: false,
      lines: ["a", "b", "c"].map((member_id) => ({
        member_id,
        contribution: member_id === "a" ? 100 : 0,
        penalty_due: 0,
        penalty_paid: 0,
        reason: "",
      })),
      expenses: [],
      donations: [],
    },
  };
}
async function boot(options = {}) {
  const context = await browser.newContext({
      viewport: { width: 390, height: 900 },
      colorScheme: options.light ? "light" : "dark",
    }),
    page = await context.newPage(),
    snapshot = data(),
    sent = [],
    errors = [];
  if (options.setup) options.setup(snapshot);
  page.on("pageerror", (e) => errors.push(e.message));
  await page.route("**/groups/g", (route) => route.fulfill({ json: snapshot }));
  await page.route("**/groups/g/**", (route) => {
    sent.push(route.request().postDataJSON());
    return route.fulfill({ json: { status: "accepted", revision: 6 } });
  });
  if (options.catalogue)
    await page.route("**/team-names.json", options.catalogue);
  await page.addInitScript(
    ({ base, deny }) => {
      sessionStorage.setItem(
        "statoo-connection",
        JSON.stringify({
          api: base,
          group: "g",
          token: "synthetic",
          expires_at: "2099-01-01T00:00:00Z",
          account: { id: "me", roles: ["ADMIN", "SG", "TR"], shared: false },
        }),
      );
      if (deny)
        Object.defineProperty(window, "localStorage", {
          get() {
            throw new DOMException("Storage denied", "SecurityError");
          },
        });
    },
    { base, deny: options.storageDenied },
  );
  await page.goto(base + "/portal/", {
    waitUntil: options.wait === false ? "commit" : "load",
  });
  if (options.wait !== false)
    await page
      .getByRole("heading", { name: snapshot.name, exact: true })
      .waitFor();
  return { page, snapshot, sent, errors, close: () => context.close() };
}
test("AUD-01 stale financial draft must not silently rebase on a newer server revision", async () => {
  const x = await boot({
    setup: (s) => (s.documents["finance:ref"] = financial()),
  });
  try {
    await x.page.getByRole("button", { name: "Finances", exact: true }).click();
    await x.page
      .getByRole("button", { name: "Voir le point", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Modifier le point", exact: true })
      .click();
    await x.page.getByLabel("Cotisation de Alice", { exact: true }).fill("150");
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    await x.page.getByRole("dialog").waitFor({ state: "detached" });
    x.snapshot.documents["finance:ref"].revision = 5;
    x.snapshot.documents["finance:ref"].payload.lines[0].contribution = 900;
    await x.page
      .getByRole("button", { name: "Actualiser", exact: true })
      .click();
    await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
    await x.page
      .getByRole("button", { name: "Voir le point", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Modifier le point", exact: true })
      .click();
    const restored = await x.page
      .getByLabel("Cotisation de Alice", { exact: true })
      .inputValue();
    await x.page
      .getByLabel("Motif de correction", { exact: true })
      .fill("Correction du brouillon");
    await x.page
      .getByRole("button", { name: "Valider le point", exact: true })
      .click();
    const confirm = x.page.getByRole("button", {
      name: "Confirmer l’envoi",
      exact: true,
    });
    if (await confirm.count()) {
      await confirm.click();
      await x.page.getByText("Données publiées.", { exact: true }).waitFor();
    }
    const op = x.sent.find((s) => s.domain === "finance");
    results.push({
      id: "AUD-01",
      draftBaseRevision: 1,
      serverRevision: 5,
      serverContribution: 900,
      restoredContribution: restored,
      sentBaseRevision: op?.base_revision,
      sentContribution: op?.payload.lines[0].contribution,
    });
    await x.page.screenshot({
      path: join(shots, "AUD-01-after-stale-publication.png"),
      fullPage: true,
    });
    assert.ok(
      !op || op.base_revision === 1,
      "Un brouillon périmé est envoyé comme une correction de la dernière version non relue.",
    );
  } finally {
    await x.close();
  }
});
test("AUD-02 closing the opening-balance form preserves input or confirms abandonment", async () => {
  const x = await boot({ setup: (s) => (s.opening = null) });
  let confirmation = false;
  x.page.on("dialog", async (d) => {
    confirmation = true;
    await d.dismiss();
  });
  try {
    await x.page.getByRole("button", { name: "Finances", exact: true }).click();
    await x.page
      .getByRole("button", {
        name: "Proposer les soldes initiaux",
        exact: true,
      })
      .click();
    await x.page.getByLabel("Caisse initiale", { exact: true }).fill("450");
    await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
    if (!(await x.page.getByRole("dialog").count()))
      await x.page
        .getByRole("button", {
          name: "Proposer les soldes initiaux",
          exact: true,
        })
        .click();
    const value = await x.page
      .getByLabel("Caisse initiale", { exact: true })
      .inputValue();
    results.push({
      id: "AUD-02",
      entered: "450",
      reopened: value,
      confirmation,
    });
    await x.page.screenshot({
      path: join(shots, "AUD-02-opening-reopened.png"),
      fullPage: true,
    });
    assert.ok(
      value === "450" || confirmation,
      "La saisie des soldes est perdue sans confirmation.",
    );
  } finally {
    await x.close();
  }
});
test("AUD-07 delayed optional catalogue must not block login and consultation", async () => {
  let release, requested;
  const ready = new Promise((done) => (requested = done)),
    gate = new Promise((done) => (release = done));
  const x = await boot({
    wait: false,
    catalogue: async (route) => {
      requested();
      await gate;
      await route
        .fulfill({ json: ["Racing Atlas", "Union du Port", "Sporting Atlas"] })
        .catch(() => {});
    },
  });
  try {
    await ready;
    await x.page
      .getByRole("heading", { name: "Groupe audit PWA", exact: true })
      .waitFor({ timeout: 5000 });
    const text = await x.page.locator("#content").innerText();
    results.push({ id: "AUD-07", contentWhileCataloguePending: text });
    await x.page.screenshot({
      path: join(shots, "AUD-07-blocked-startup.png"),
      fullPage: true,
    });
    assert.match(text, /Groupe audit PWA|Retrouver votre groupe/);
  } finally {
    release();
    await x.close();
  }
});
test("AUD-08 existing session remains editable without the team name catalogue", async () => {
  const x = await boot({
    setup: (s) => (s.documents["sport:ref"] = structuredClone(sport)),
    catalogue: (route) =>
      route.fulfill({ status: 503, body: "Service unavailable" }),
  });
  try {
    await x.page
      .getByRole("button", { name: "Voir la séance", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Modifier la séance", exact: true })
      .click();
    const fields = await x.page
      .getByLabel("Notes de la séance", { exact: true })
      .count();
    const msg = await x.page.locator("#message").innerText();
    results.push({ id: "AUD-08", editorOpen: fields === 1, message: msg });
    assert.equal(fields, 1);
  } finally {
    await x.close();
  }
});
test("AUD-09 denied local storage produces an actionable message rather than a frozen shell", async () => {
  const x = await boot({ storageDenied: true, wait: false });
  try {
    await x.page.waitForEvent("pageerror", { timeout: 5000 }).catch(() => {});
    const text = await x.page.locator("body").innerText();
    results.push({ id: "AUD-09", body: text, errors: x.errors });
    await x.page.screenshot({
      path: join(shots, "AUD-09-storage-denied.png"),
      fullPage: true,
    });
    assert.match(text, /stockage|stockage local|storage/i);
  } finally {
    await x.close();
  }
});
test("AUD-10 team-name text has at least 4.5:1 contrast in light theme", async () => {
  const x = await boot({
    light: true,
    setup: (s) => (s.documents["sport:ref"] = structuredClone(sport)),
  });
  try {
    const ratios = await x.page.locator(".team h4").evaluateAll((nodes) => {
      const rgb = (text) =>
        text
          .match(/[\d.]+/g)
          .slice(0, 3)
          .map(Number);
      const lum = (values) =>
        values
          .map((c) => {
            c /= 255;
            return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
          })
          .reduce((n, c, i) => n + c * [0.2126, 0.7152, 0.0722][i], 0);
      return nodes.map((n) => {
        const fg = getComputedStyle(n).color,
          bg = getComputedStyle(n.closest(".card")).backgroundColor,
          a = lum(rgb(fg)),
          b = lum(rgb(bg));
        return {
          name: n.textContent,
          foreground: fg,
          background: bg,
          ratio: (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05),
        };
      });
    });
    results.push({ id: "AUD-10", ratios });
    await x.page.screenshot({
      path: join(shots, "AUD-10-team-colors-light.png"),
      fullPage: true,
    });
    assert.ok(
      ratios.every((r) => r.ratio >= 4.5),
      JSON.stringify(ratios),
    );
  } finally {
    await x.close();
  }
});

test("FIX-01 old-generation and legacy drafts require explicit abandonment before current version", async () => {
  for (const legacy of [false, true]) {
    const x = await boot({
      setup: (s) => (s.documents["finance:ref"] = financial()),
    });
    try {
      await x.page
        .getByRole("button", { name: "Finances", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Voir le point", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Modifier le point", exact: true })
        .click();
      await x.page
        .getByLabel("Cotisation de Alice", { exact: true })
        .fill("150");
      await x.page.getByRole("button", { name: "Fermer", exact: true }).click();
      await x.page.getByRole("dialog").waitFor({ state: "detached" });
      if (legacy)
        await x.page.evaluate(() => {
          for (let i = 0; i < localStorage.length; i++) {
            const k = localStorage.key(i);
            if (k.includes("draft:finance:ref")) {
              const v = JSON.parse(localStorage.getItem(k));
              delete v.baseDocument;
              localStorage.setItem(k, JSON.stringify(v));
            }
          }
        });
      else x.snapshot.documents["finance:ref"].generation = 1;
      x.snapshot.documents["finance:ref"].payload.lines[0].contribution = 900;
      await x.page
        .getByRole("button", { name: "Actualiser", exact: true })
        .click();
      await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
      await x.page
        .getByRole("button", { name: "Voir le point", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Modifier le point", exact: true })
        .click();
      assert.equal(
        await x.page
          .getByLabel("Cotisation de Alice", { exact: true })
          .inputValue(),
        "150",
      );
      await x.page
        .getByRole("button", { name: "Relire la version publiée", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Revenir à la saisie", exact: true })
        .click();
      assert.equal(
        await x.page
          .getByLabel("Cotisation de Alice", { exact: true })
          .inputValue(),
        "150",
      );
      await x.page
        .getByRole("button", { name: "Relire la version publiée", exact: true })
        .click();
      await x.page
        .getByRole("button", { name: "Confirmer l’envoi", exact: true })
        .click();
      assert.equal(
        await x.page
          .getByLabel("Cotisation de Alice", { exact: true })
          .inputValue(),
        "900",
      );
      assert.equal(x.sent.length, 0);
    } finally {
      await x.close();
    }
  }
});
test("FIX-02 opening draft persists all fields across reload and is removed after accepted write", async () => {
  const x = await boot({ setup: (s) => (s.opening = null) });
  try {
    await x.page.getByRole("button", { name: "Finances", exact: true }).click();
    await x.page
      .getByRole("button", {
        name: "Proposer les soldes initiaux",
        exact: true,
      })
      .click();
    await x.page.getByLabel("Caisse initiale", { exact: true }).fill("450");
    await x.page
      .getByLabel("Date de début des comptes", { exact: true })
      .fill("2026-10-01");
    await x.page
      .getByLabel("Avance ou dette de Alice", { exact: true })
      .fill("-200");
    await x.page
      .getByLabel("Pénalités initiales de Alice", { exact: true })
      .fill("50");
    await x.page.keyboard.press("Escape");
    await x.page.reload();
    await x.page.getByRole("button", { name: "Finances", exact: true }).click();
    await x.page
      .getByRole("button", {
        name: "Proposer les soldes initiaux",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Caisse initiale", { exact: true }).inputValue(),
      "450",
    );
    assert.equal(
      await x.page
        .getByLabel("Date de début des comptes", { exact: true })
        .inputValue(),
      "2026-10-01",
    );
    assert.equal(
      await x.page
        .getByLabel("Avance ou dette de Alice", { exact: true })
        .inputValue(),
      "-200",
    );
    assert.equal(
      await x.page
        .getByLabel("Pénalités initiales de Alice", { exact: true })
        .inputValue(),
      "50",
    );
    await x.page
      .getByRole("button", { name: "Soumettre les soldes", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Revenir à la saisie", exact: true })
      .click();
    assert.equal(x.sent.length, 0);
    await x.page
      .getByRole("button", { name: "Soumettre les soldes", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByRole("dialog").waitFor({ state: "detached" });
    assert.equal(x.sent.length, 1);
    assert.equal(x.sent[0].members.a.contribution_balance, -200);
    await x.page
      .getByRole("button", {
        name: "Proposer les soldes initiaux",
        exact: true,
      })
      .click();
    assert.equal(
      await x.page.getByLabel("Caisse initiale", { exact: true }).inputValue(),
      "0",
    );
  } finally {
    await x.close();
  }
});
test("FIX-03 accepted administrative write shows refresh warning and permits read-only retry", async () => {
  const x = await boot();
  try {
    await x.page.getByRole("button", { name: "Membres", exact: true }).click();
    await x.page
      .getByRole("button", { name: "Ajouter un membre", exact: true })
      .click();
    await x.page.getByLabel("Nom du membre", { exact: true }).fill("Diane");
    await x.page.route("**/groups/g", (route) =>
      route.fulfill({ status: 503, json: { detail: "Lecture indisponible" } }),
    );
    await x.page
      .getByRole("button", { name: "Enregistrer", exact: true })
      .click();
    await x.page
      .getByRole("button", { name: "Confirmer l’envoi", exact: true })
      .click();
    await x.page.getByRole("dialog").waitFor({ state: "detached" });
    assert.match(
      await x.page.locator("#message").innerText(),
      /enregistr.*actualisation/i,
    );
    assert.equal(x.sent.length, 1);
    await x.page.route("**/groups/g", (route) =>
      route.fulfill({ json: x.snapshot }),
    );
    await x.page
      .getByRole("button", { name: "Actualiser", exact: true })
      .click();
    await x.page.getByText("Données actualisées.", { exact: true }).waitFor();
    assert.equal(x.sent.length, 1);
  } finally {
    await x.close();
  }
});
test("FIX-10 all team palette colors remain readable in both themes", async () => {
  const { palette } = await import("../../domain.mjs");
  for (const light of [true, false]) {
    const x = await boot({
      light,
      setup: (s) => {
        Object.values(palette).forEach((color, i) => {
          const d = structuredClone(sport);
          d.occurrence_id = "ref" + i;
          d.payload.session.team_colors = { A: color, B: color, C: color };
          s.documents["sport:ref" + i] = d;
        });
      },
    });
    try {
      await x.page
        .getByRole("button", { name: "Séances", exact: true })
        .click();
      const ratios = await x.page.locator(".team h4").evaluateAll((nodes) => {
        const lum = (s) =>
          s
            .match(/[\d.]+/g)
            .slice(0, 3)
            .map(Number)
            .map((c) => {
              c /= 255;
              return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
            })
            .reduce((n, c, i) => n + c * [0.2126, 0.7152, 0.0722][i], 0);
        return nodes.map((n) => {
          const a = lum(getComputedStyle(n).color),
            b = lum(getComputedStyle(n.closest(".card")).backgroundColor);
          return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
        });
      });
      assert.equal(ratios.length, 24);
      assert.ok(
        ratios.every((r) => r >= 4.5),
        JSON.stringify(ratios),
      );
    } finally {
      await x.close();
    }
  }
});
