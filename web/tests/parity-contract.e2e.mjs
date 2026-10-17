import test from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, readFileSync } from "node:fs";
import { chromium } from "playwright";
const base = process.env.STATOO_PARITY_URL || "http://127.0.0.1:18087/";
async function enter(locator, value) {
  await locator.click();
  await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, {delay: 10});
  await locator.page().keyboard.press('Tab');
}

test(
  "PAR02/06/08/09/16/17 local group, explicit start, persistence and backup on web",
  { timeout: 120000 },
  async () => {
    console.log("Browser regression: launching Chrome");
    const browser = await chromium.launch({
      channel: "chrome",
      headless: true,
    });
    console.log("Browser regression: Chrome ready");
    try {
      const context = await browser.newContext({
        viewport: { width: 393, height: 852 },
      });
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (e) => errors.push(e.message));
      await page.goto(base);
      await page.getByRole("button", {name: "Créer un groupe", exact: true}).click();
      await page
        .getByRole("button", { name: "Passer", exact: true })
        .waitFor({ timeout: 45000 });
      await page.getByRole("button", { name: "Passer", exact: true }).click();
      await page.getByText("Créez votre équipe", { exact: true }).waitFor();
      await enter(page
        .getByRole("textbox", {
          name: "ex: FC Urban, Les Galactiques...",
          exact: true,
        }), "Statoo QA Parité");
      const shortName = page.getByRole("textbox", { name: /Nom court/ });
      await shortName.click();
      await enter(shortName, "SQ");
      await shortName.press("Tab");
      await page
        .getByRole("button", { name: "Continuer vers l'effectif", exact: true })
        .click();
      for (const name of [
        "Alice",
        "Bob",
        "Camille",
        "Diane",
        "Émile",
        "Fatou",
      ]) {
        await enter(page
          .getByRole("textbox", {
            name: "Nom ou prénom (ex: Lucas, Karim...) *",
            exact: true,
          }), name);
        await page
          .getByRole("button", { name: "Ajouter ce joueur", exact: true })
          .click();
      }
      await page
        .getByRole("button", {
          name: "Continuer vers l’accès Admin",
          exact: true,
        })
        .click();
      await page.getByRole("button", {name: "Continuer sur cet appareil", exact: true}).click();
      await page
        .getByRole("button", { name: "Nouvelle séance", exact: true })
        .click();
      await page.getByText("Date & Options", { exact: true }).waitFor();
      await page
        .getByRole("button", { name: "Continuer", exact: true })
        .click();
      assert.equal(
        await page
          .getByRole("button", { name: "Clôturer la séance", exact: true })
          .count(),
        0,
      );
      await page
        .getByRole("button", { name: "Tout cocher", exact: true })
        .click();
      await page
        .getByRole("button", { name: "Tirer au sort", exact: true })
        .click();
      await page
        .getByRole("button", { name: "Bleu · Équipe A", exact: true })
        .click();
      await page
        .getByRole("button", { name: "Orange · Équipe B", exact: true })
        .click();
      mkdirSync("docs/parity-captures", { recursive: true });
      await page.screenshot({
        path: "docs/parity-captures/before-start-393.png",
      });
      await page
        .getByRole("button", { name: "Débuter la séance", exact: true })
        .click();
      await page
        .getByRole("heading", { name: "Détail séance", exact: true })
        .waitFor();
      await page
        .getByRole("button", { name: "Clôturer la séance", exact: true })
        .first()
        .waitFor();
      await page.screenshot({ path: "docs/parity-captures/active-393.png" });
      await page.goto(base);
      await page
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .waitFor({ timeout: 30000 });
      await page.getByRole("button", { name: "Réglages", exact: true }).click();
      await page.mouse.move(200, 400);
      await page.mouse.wheel(0, 3000);
      const [file] = await Promise.all([
        page.waitForEvent("download"),
        page.getByRole("button", { name: /^Sauvegarder les données/ }).click(),
      ]);
      const payload = JSON.parse(readFileSync(await file.path(), "utf8"));
      assert.equal(payload.players.length, 6);
    assert.equal(payload.meta["team_short_name_"+payload.teams[0].id],"SQ");
      assert.equal(payload.sessions.length, 1);
      assert.equal(payload.participations.length, 6);
      assert.ok(
        Object.keys(payload.meta).some((k) =>
          k.startsWith("active_session_id_"),
        ),
      );
      assert.deepEqual(errors, []);
      await page.goto(base);
      await page
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .waitFor({ timeout: 30000 });
      await page.evaluate(async () => {
        await navigator.serviceWorker.ready;
      });
      await context.setOffline(true);
      await page.reload();
      await page
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .waitFor({ timeout: 30000 });
      await context.setOffline(false);
      const restored = await browser.newContext({
        viewport: { width: 393, height: 852 },
      });
      const restoredPage = await restored.newPage();
      await restoredPage.goto(base);
      await restoredPage.getByRole("button", {name: "Créer un groupe", exact: true}).click();
      await restoredPage
        .getByRole("button", { name: "Passer", exact: true })
        .waitFor({ timeout: 30000 });
      await restoredPage
        .getByRole("button", { name: "Passer", exact: true })
        .click();
      const [chooser] = await Promise.all([
        restoredPage.waitForEvent("filechooser"),
        restoredPage
          .getByRole("button", {
            name: "J'ai déjà une sauvegarde Statoo",
            exact: true,
          })
          .click(),
      ]);
      await chooser.setFiles(await file.path());
      await restoredPage
        .getByRole("button", {
          name: "Remplacer toutes les données",
          exact: true,
        })
        .click();
      await restoredPage
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .waitFor({ timeout: 30000 });
      await restoredPage.screenshot({
        path: "docs/parity-captures/restored-393.png",
      });
      await restored.close();
      await context.close();
    } finally {
      const p=browser.contexts()[0]?.pages()[0];
      if(p){console.log((await p.locator("body").innerText()).slice(-2500));await p.screenshot({path:"docs/parity-captures/merge-final.png"});}
      await browser.close();
    }
  },
);
