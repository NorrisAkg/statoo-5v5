import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
test("GRP-06/07/08/09 creation separates members and explains collective access", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const context = await browser.newContext({ serviceWorkers: "block" }),
      page = await context.newPage(),
      sent = [];
    await page.route("**/groups", (r) => {
      sent.push(r.request().postDataJSON());
      return r.fulfill({ status: 422, json: { detail: "Envoi de test" } });
    });
    await page.goto("http://127.0.0.1:18085/portal/");
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    assert.equal(
      await page.getByLabel("Identifiant du groupe", { exact: true }).count(),
      0,
    );
    const collective = page.getByLabel("Identifiant collectif", {
      exact: true,
    });
    assert.match(
      (await collective.getAttribute("aria-describedby")) || "",
      /collective/,
    );
    await page
      .getByText(
        "Identifiant partagé par les membres pour consulter le groupe, sans modifier les données.",
        { exact: true },
      )
      .waitFor();
    await page.getByLabel("Nom du groupe", { exact: true }).fill("Test");
    await page.getByLabel("Membres du groupe", { exact: true }).fill(" , \n,");
    await page.getByLabel("Identifiant Admin", { exact: true }).fill("admin");
    await page
      .getByLabel("Mot de passe Admin", { exact: true })
      .fill("Test-Password");
    await page
      .getByLabel("Mot de passe collectif", { exact: true })
      .fill("Members-Password");
    await page
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await page
      .getByText("Ajoutez au moins un membre.", { exact: true })
      .waitFor();
    assert.equal(sent.length, 0);
    await page
      .getByLabel("Membres du groupe", { exact: true })
      .fill("Alice,   Bob\nCamille Dupont, , Diane");
    await page
      .getByLabel("Mot de passe Admin", { exact: true })
      .fill("Test-Password");
    await page
      .getByLabel("Mot de passe collectif", { exact: true })
      .fill("Members-Password");
    await page
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await page.getByText("Envoi de test", { exact: true }).waitFor();
    assert.deepEqual(
      sent[0].members.map((m) => m.name),
      ["Alice", "Bob", "Camille Dupont", "Diane"],
    );
    assert.equal("group_id" in sent[0], false);
    await page
      .getByRole("button", { name: "J’ai déjà des identifiants", exact: true })
      .click();
    assert.equal(
      await page.getByLabel("Identifiant du groupe", { exact: true }).count(),
      1,
    );
  } finally {
    await browser.close();
  }
});
