import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
const url = (process.env.STATOO_TEST_URL || "http://127.0.0.1:18085") + "/portal/";
test("ACC09/10 short name is submitted and locked for uncertain publication", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({ serviceWorkers: "block" });
    await page.addInitScript(() =>
      localStorage.setItem("statoo-onboarding-complete", "1"),
    );
    let sent;
    await page.route("**/groups", (r) => {
      sent = r.request().postDataJSON();
      return r.fulfill({
        status: 503,
        json: { detail: "Publication à vérifier" },
      });
    });
    await page.goto(url);
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    for (const [label, value] of [
      ["Nom du groupe", "Football Club"],
      ["Nom court (facultatif)", " FC "],
      ["Membres du groupe", "Alice, Bob"],
      ["Identifiant Admin", "admin"],
      ["Mot de passe Admin", "Test-Password"],
      ["Mot de passe collectif", "Members-Password"],
    ])
      await page.getByLabel(label, { exact: true }).fill(value);
    await page
      .getByRole("button", { name: "Créer le groupe", exact: true })
      .click();
    await page.getByText("Publication à vérifier", { exact: true }).waitFor();
    assert.equal(sent.short_name, "FC");
    assert.equal(
      await page
        .getByLabel("Nom court (facultatif)", { exact: true })
        .isDisabled(),
      true,
    );
    await page.reload();
    await page
      .getByRole("button", { name: "Reprendre la préparation", exact: true })
      .click();
    assert.equal(
      await page
        .getByLabel("Nom court (facultatif)", { exact: true })
        .inputValue(),
      "FC",
    );
    assert.equal(
      await page
        .getByLabel("Nom court (facultatif)", { exact: true })
        .isDisabled(),
      true,
    );
  } finally {
    await browser.close();
  }
});
test("ACC03 skipping onboarding still works with unavailable storage", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({ serviceWorkers: "block" });
    await page.addInitScript(() =>
      Object.defineProperty(window, "localStorage", {
        get() {
          throw Error("blocked");
        },
      }),
    );
    await page.goto(url);
    await page.getByRole("button", { name: "Passer", exact: true }).click();
    await page
      .getByRole("heading", { name: "Retrouver votre groupe", exact: true })
      .waitFor({ timeout: 3000 });
  } finally {
    await browser.close();
  }
});
test("ACC03/04/05/06/11 returning visit and responsive forms", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({
      serviceWorkers: "block",
      reducedMotion: "reduce",
    });
    await page.addInitScript(() =>
      localStorage.setItem("statoo-onboarding-complete", "1"),
    );
    await page.goto(url);
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    for (const input of await page.locator("form input,form textarea").all())
      assert.ok(await input.getAttribute("placeholder"));
    await page.getByLabel("Nom court (facultatif)", { exact: true }).fill("FC");
    await page
      .getByLabel("Nom du groupe", { exact: true })
      .fill("Football Club des Amis au nom très long");
    for (const theme of ["light", "dark"])
      for (const width of [320, 393])
        for (const scale of [1, 1.3, 2]) {
          await page.setViewportSize({ width, height: 715 });
          await page.evaluate(
            ({ theme, scale }) => {
              document.documentElement.dataset.theme = theme;
              document.body.style.fontSize = 14 * scale + "px";
            },
            { theme, scale },
          );
          assert.ok(
            await page.evaluate(
              () => document.documentElement.scrollWidth <= innerWidth,
            ),
            `${theme} ${width} ${scale}`,
          );
          if (width === 393 && scale === 1) {
            mkdirSync("docs/welcome-captures", { recursive: true });
            await page.screenshot({
              path: `docs/welcome-captures/registration-${theme}.png`,
              fullPage: true,
            });
          }
        }
    const input = page.getByLabel("Mot de passe collectif", { exact: true });
    await input.fill("Secret-test");
    await page
      .getByRole("button", {
        name: "Afficher Mot de passe collectif",
        exact: true,
      })
      .click();
    assert.equal(await input.getAttribute("type"), "text");
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    assert.equal(
      await page
        .locator(".topbar")
        .evaluate((n) => Math.round(n.getBoundingClientRect().top)),
      0,
    );
  } finally {
    await browser.close();
  }
});
test("ACC01/02/04/05/06 onboarding, fields and sticky navigation", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const page = await browser.newPage({ serviceWorkers: "block" });
    await page.goto(url);
    await page
      .getByRole("heading", { name: "Suivez vos matchs 5v5", exact: true })
      .waitFor({ timeout: 5000 });
    mkdirSync("docs/welcome-captures", { recursive: true });
    await page.setViewportSize({ width: 393, height: 715 });
    await page.screenshot({
      path: "docs/welcome-captures/onboarding-1.png",
      fullPage: true,
    });
    await page.getByRole("button", { name: "Suivant", exact: true }).click();
    await page
      .getByRole("heading", { name: "Tirage rapide & équilibré", exact: true })
      .waitFor({ timeout: 5000 });
    await page.screenshot({
      path: "docs/welcome-captures/onboarding-2.png",
      fullPage: true,
    });
    await page.getByRole("button", { name: "Précédent", exact: true }).click();
    await page.getByRole("button", { name: "Suivant", exact: true }).click();
    await page.getByRole("button", { name: "Suivant", exact: true }).click();
    await page
      .getByRole("heading", { name: "Classement & Statistiques", exact: true })
      .waitFor({ timeout: 5000 });
    for (const theme of ["light", "dark"])
      for (const width of [320, 393])
        for (const scale of [1, 1.3, 2]) {
          await page.setViewportSize({ width, height: 715 });
          await page.evaluate(
            ({ theme, scale }) => {
              document.documentElement.dataset.theme = theme;
              document.body.style.fontSize = 14 * scale + "px";
            },
            { theme, scale },
          );
          assert.ok(
            await page.evaluate(
              () => document.documentElement.scrollWidth <= innerWidth,
            ),
          );
          assert.equal(
            await page
              .getByRole("button", { name: "Commencer", exact: true })
              .evaluate((button) => {
                const range = document.createRange();
                range.selectNodeContents(button);
                return range.getClientRects().length;
              }),
            1,
            `Commencer reste lisible : ${theme} ${width} ${scale}`,
          );
        }
    await page.screenshot({
      path: "docs/welcome-captures/onboarding-3-dark-200.png",
      fullPage: true,
    });
    await page.getByRole("button", { name: "Commencer", exact: true }).click();
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .click();
    const inputs = page.locator("form input, form textarea");
    for (const input of await inputs.all())
      assert.ok(await input.getAttribute("placeholder"));
    const short = page.getByLabel("Nom court (facultatif)", { exact: true });
    await short.fill("FC");
    for (const label of ["Mot de passe Admin", "Mot de passe collectif"]) {
      const input = page.getByLabel(label, { exact: true });
      await input.fill("Secret-test");
      assert.equal(await input.getAttribute("type"), "password");
      await page
        .getByRole("button", { name: "Afficher " + label, exact: true })
        .click();
      assert.equal(await input.getAttribute("type"), "text");
      assert.equal(await input.evaluate((n) => n.value), "Secret-test");
      await page
        .getByRole("button", { name: "Masquer " + label, exact: true })
        .click();
      assert.equal(await input.getAttribute("type"), "password");
    }
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    assert.equal(
      await page
        .locator(".topbar")
        .evaluate((n) => Math.round(n.getBoundingClientRect().top)),
      0,
    );
    await page.reload();
    await page
      .getByRole("button", { name: "Créer un groupe", exact: true })
      .waitFor({ timeout: 5000 });
  } finally {
    await browser.close();
  }
});
