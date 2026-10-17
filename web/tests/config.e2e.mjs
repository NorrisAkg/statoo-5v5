import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
test("CFG-01 configured API receives login and registration without server fields", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    for (const registration of [false, true]) {
      const context = await browser.newContext({ serviceWorkers: "block" }),
        page = await context.newPage();
      await page.route("**/config.json", (r) =>
        r.fulfill({
          json: { api_url: "https://configured.example.test/api/" },
        }),
      );
      const requests = [];
      await page.route("https://configured.example.test/**", (r) => {
        requests.push(r.request().url());
        return r.fulfill({
          status: 401,
          json: { detail: "Identifiants de test" },
        });
      });
      await page.addInitScript(() =>
        localStorage.setItem("statoo-onboarding-complete", "1"),
      );
      await page.goto(base + "/portal/");
      if (registration)
        await page
          .getByRole("button", { name: "Créer un groupe", exact: true })
          .click();
      assert.equal(
        await page.getByLabel("Adresse de l’API", { exact: true }).count(),
        0,
      );
      if (!registration)
        await page
          .getByLabel("Identifiant du groupe", { exact: true })
          .fill("test");
      if (registration) {
        await page.getByLabel("Nom du groupe", { exact: true }).fill("Test");
        await page
          .getByLabel("Membres du groupe", { exact: true })
          .fill("Alice");
        await page
          .getByLabel("Mot de passe collectif", { exact: true })
          .fill("test-password");
      }
      await page
        .getByLabel(
          registration ? "Identifiant Admin" : "Identifiant de connexion",
          { exact: true },
        )
        .fill("admin");
      await page
        .getByLabel(registration ? "Mot de passe Admin" : "Mot de passe", {
          exact: true,
        })
        .fill("test-password");
      await page
        .getByRole("button", {
          name: registration ? "Créer le groupe" : "Se connecter",
          exact: true,
        })
        .click();
      await page.getByText("Identifiants de test", { exact: true }).waitFor();
      assert.equal(
        requests[0],
        `https://configured.example.test/api/${registration ? "groups" : "auth/login"}`,
      );
      await context.close();
    }
  } finally {
    await browser.close();
  }
});
