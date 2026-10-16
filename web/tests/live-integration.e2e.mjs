import test from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, readFileSync } from "node:fs";
import { chromium } from "playwright";
const base = process.env.STATOO_PARITY_URL || "http://127.0.0.1:19095/";

test(
  "INT-11/14/15 live input on real Flutter web and persistence",
  { timeout: 120000 },
  async () => {
    const browser = await chromium.launch({
      channel: "chrome",
      headless: true,
    });
    try {
      const context = await browser.newContext({
        viewport: { width: 393, height: 852 },
      });
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (e) => errors.push(e.message));
      await page.goto(base);
      await page
        .getByRole("button", { name: "Passer", exact: true })
        .waitFor({ timeout: 45000 });
      await page.getByRole("button", { name: "Passer", exact: true }).click();
      await page.getByText("Créez votre équipe", { exact: true }).waitFor();
      await page
        .getByRole("textbox", {
          name: "ex: FC Urban, Les Galactiques...",
          exact: true,
        })
        .fill("Statoo QA Parité");
      const shortName = page.getByRole("textbox", { name: /Nom court/ });
      await shortName.click();
      await shortName.fill("SQ");
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
        await page
          .getByRole("textbox", {
            name: "Nom ou prénom (ex: Lucas, Karim...) *",
            exact: true,
          })
          .fill(name);
        await page
          .getByRole("button", { name: "Ajouter ce joueur", exact: true })
          .click();
      }
      await page
        .getByRole("button", {
          name: "Terminer et aller à l'Accueil",
          exact: true,
        })
        .click();
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
      mkdirSync("docs/live-captures", { recursive: true });
      await page.screenshot({
        path: "docs/live-captures/before-start-393.png",
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
      await page.getByRole('button',{name:'Ajouter un but',exact:true}).click();
      await page.getByRole('button',{name:/^(Alice|Bob|Camille|Diane|Émile|Fatou)$/,exact:true}).first().click();
      await page.getByText(/^But de /).waitFor();
      await page.getByRole('button',{name:'Aucun passeur',exact:true}).click();
      await page.getByRole('button',{name:'Modifier ce but',exact:true}).waitFor();
      await page.screenshot({path:'docs/live-captures/live-goal-393.png'});
      await page.getByRole('button',{name:'Modifier ce but',exact:true}).click();
      await page.getByRole('button',{name:'Buteur non renseigné',exact:true}).click();
      await page.getByRole('button',{name:'Annuler la dernière action',exact:true}).waitFor();
      await page.getByRole('button',{name:'Annuler la dernière action',exact:true}).click();
      await page.getByRole('button',{name:'Modifier ce but',exact:true}).waitFor();
      await page.reload();
      await page.goto(base);
      await page.getByRole('button',{name:'Reprendre le match en direct',exact:true}).click();
      await page.getByRole('button',{name:'Modifier ce but',exact:true}).waitFor({timeout:45000});
      await page.screenshot({path:'docs/live-captures/live-restored-393.png'});
      assert.deepEqual(errors,[]);
    }finally{
      const p=browser.contexts()[0]?.pages()[0];
      if(p){console.log((await p.locator('body').innerText()).slice(-3000));await p.screenshot({path:'docs/live-captures/final-debug.png'});}
      await browser.close();
    }
  },
);
