import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
const base = process.env.STATOO_TEST_URL || "http://127.0.0.1:18085";
test("OFF-09 abandoning a preparation requires confirmation", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage();
    await page.addInitScript(() =>
      localStorage.setItem("statoo-onboarding-complete", "1"),
    );
    await page.goto(base + "/portal/");
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    await page.getByLabel("Nom du groupe", { exact: true }).fill("À conserver");
    await page.getByLabel("Membres du groupe", { exact: true }).fill("Alice");
    page.once("dialog", (d) => d.dismiss());
    await page
      .getByRole("button", { name: "Abandonner la préparation", exact: true })
      .click();
    assert.notEqual(
      await page.evaluate(() =>
        localStorage.getItem("statoo-registration-draft"),
      ),
      null,
    );
    page.once("dialog", (d) => d.accept());
    await page
      .getByRole("button", { name: "Abandonner la préparation", exact: true })
      .click();
    assert.equal(
      await page.evaluate(() =>
        localStorage.getItem("statoo-registration-draft"),
      ),
      null,
    );
    await page
      .getByRole("button", { name: "Se connecter", exact: true })
      .waitFor();
  } finally {
    await browser.close();
  }
});
test("OFF-01/02/03/04/05 offline preparation, reload, lost response and safe publication retry", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const context = await browser.newContext(),
      p = await context.newPage();
    await p.addInitScript(() =>
      localStorage.setItem("statoo-onboarding-complete", "1"),
    );
    await p.goto(base + "/portal/");
    await p.evaluate(async () => {
      await navigator.serviceWorker.ready;
      if (!navigator.serviceWorker.controller)
        await new Promise((r) =>
          navigator.serviceWorker.addEventListener("controllerchange", r, {
            once: true,
          }),
        );
    });
    await context.setOffline(true);
    await p
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    assert.equal(
      await p.getByLabel("Mot de passe Admin", { exact: true }).count(),
      0,
    );
    await p
      .getByLabel("Nom du groupe", { exact: true })
      .fill("Club préparé hors ligne");
    await p
      .getByLabel("Membres du groupe", { exact: true })
      .fill("Alice, Bob\nCamille");
    await p
      .getByRole("button", {
        name: "Enregistrer sur cet appareil",
        exact: true,
      })
      .click();
    await p
      .getByText("Enregistré sur cet appareil — en attente de connexion.", {
        exact: true,
      })
      .waitFor();
    await p.reload();
    await p
      .getByRole("button", { name: "Reprendre la préparation", exact: true })
      .click();
    assert.equal(
      await p.getByLabel("Nom du groupe", { exact: true }).inputValue(),
      "Club préparé hors ligne",
    );
    await context.setOffline(false);
    await p.getByLabel("Identifiant Admin", { exact: true }).waitFor();
    let count = 0,
      created,
      firstBody;
    await p.route("**/groups", async (route) => {
      count++;
      if (count === 1) {
        firstBody = route.request().postDataJSON();
        const response = await route.fetch();
        assert.equal(response.status(), 201);
        created = (await response.json()).group_id;
        await route.abort("failed");
      } else await route.continue();
    });
    const credentials = async () => {
      await p.getByLabel("Identifiant Admin", { exact: true }).fill("admin");
      await p
        .getByLabel("Mot de passe Admin", { exact: true })
        .fill("Test-Offline-Password");
      await p
        .getByLabel("Mot de passe collectif", { exact: true })
        .fill("Members-Offline-Password");
    };
    await credentials();
    await p
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await p.waitForFunction(
      () =>
        document.querySelector('form [role="alert"]')?.textContent.length > 0,
    );
    assert.equal(count, 1);
    await p
      .getByText(
        "Publication à vérifier. Ressaisissez les mêmes accès pour reprendre sans créer de doublon.",
        { exact: true },
      )
      .waitFor({ timeout: 2000 });
    const persisted = await p.evaluate(() =>
      JSON.stringify({ ...localStorage }),
    );
    assert.equal(persisted.includes("Test-Offline-Password"), false);
    assert.equal(persisted.includes("Members-Offline-Password"), false);
    await p.reload();
    await p
      .getByRole("button", { name: "Reprendre la préparation", exact: true })
      .click();
    assert.equal(
      await p.getByLabel("Nom du groupe", { exact: true }).isDisabled(),
      true,
    );
    await credentials();
    await p
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await p
      .getByRole("heading", { name: "Club préparé hors ligne", exact: true })
      .waitFor();
    await p
      .getByText("Identifiant du groupe : " + created, { exact: true })
      .waitFor();
    assert.equal(count, 2);
    assert.ok(firstBody.operation_id);
    assert.equal(
      await p.evaluate(() => localStorage.getItem("statoo-registration-draft")),
      null,
    );
  } finally {
    await browser.close();
  }
});
