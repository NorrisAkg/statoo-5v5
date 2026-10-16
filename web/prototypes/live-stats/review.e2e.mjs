import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
const url = "http://127.0.0.1:19094/prototypes/live-stats/";
test("LIVE-15/16 mobile wins are compact rows and undo remains near input", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const p = await browser.newPage({ viewport: { width: 393, height: 852 } });
    await p.goto(url);
    const rows = await p
      .locator(".score-team")
      .evaluateAll((nodes) =>
        nodes.map((n) => ({
          x: n.getBoundingClientRect().x,
          y: n.getBoundingClientRect().y,
        })),
      );
    assert.ok(rows[0].y < rows[1].y && rows[1].y < rows[2].y);
    const goal = await p
      .getByRole("button", { name: "Ajouter un but", exact: true })
      .boundingBox();
    const undo = await p
      .getByRole("button", { name: "Annuler la dernière action", exact: true })
      .boundingBox();
    assert.ok(
      undo.y - goal.y < 200,
      "Undo must remain close to the event actions",
    );
  } finally {
    await browser.close();
  }
});
test("LIVE-13 unsaved state remains truthful after switching modes", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const p = await browser.newPage();
    await p.addInitScript(() => {
      Storage.prototype.setItem = function () {
        throw Error("quota");
      };
    });
    await p.goto(url);
    await p
      .getByRole("button", {
        name: "Ajouter une victoire à Racing Atlas",
        exact: true,
      })
      .click();
    await p
      .getByRole("button", { name: "Match · 2 équipes", exact: true })
      .click();
    await p
      .getByRole("button", { name: "Tournoi · 3 équipes", exact: true })
      .click();
    assert.match(await p.locator("#save-status").innerText(), /Non enregistré/);
  } finally {
    await browser.close();
  }
});
test("LIVE-14 corruption blocks closing and preserves original data", async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  try {
    const p = await browser.newPage();
    await p.addInitScript(() =>
      localStorage.setItem("statoo-live-prototype:tournament", "{broken"),
    );
    await p.goto(url);
    await p.getByRole("alert").filter({ hasText: "illisible" }).waitFor();
    assert.equal(
      await p
        .getByRole("button", { name: "Terminer la séance", exact: true })
        .isDisabled(),
      true,
    );
    assert.equal(
      await p
        .getByRole("button", { name: "Ajouter un but", exact: true })
        .isDisabled(),
      true,
    );
    assert.equal(
      await p.evaluate(() =>
        localStorage.getItem("statoo-live-prototype:tournament"),
      ),
      "{broken",
    );
  } finally {
    await browser.close();
  }
});
