import test from "node:test";
import assert from "node:assert/strict";
import { chromium } from "playwright";
const api = process.env.STATOO_PARITY_API || "http://127.0.0.1:18088";
const base = process.env.STATOO_PARITY_URL || "http://127.0.0.1:18087/";
async function enter(locator, value) {
  await locator.click();
  await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, {delay: 10});
  await locator.page().keyboard.press('Tab');
}
const password = "QA-Password-2026";
async function request(
  path,
  body,
  token,
  method = body === undefined ? "GET" : "POST",
) {
  const response = await fetch(api + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: "Bearer " + token } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  assert.ok(response.ok, await response.clone().text());
  return response.json();
}
test(
  "PAR14/18/21 browser joins a real shared group and resumes its active session",
  { timeout: 90000 },
  async () => {
    const members = ["Alice", "Bob", "Camille", "Diane", "Émile", "Fatou"].map(
      (name, i) => ({ id: "p" + i, name, is_active: 1 }),
    );
    const admin = await request("/groups", {
      name: "Partage QA",
      username: "admin",
      password,
      shared_username: "membres",
      shared_password: password,
      members,
    });
    const group = "/groups/" + encodeURIComponent(admin.group_id);
    await request(
      group + "/sport-settings",
      { min_players_per_session: 2 },
      admin.token,
      "PUT",
    );
    for (const [i, role] of ["SG", "PDT", "TR"].entries())
      await request(
        group + "/accounts",
        { username: role, password, member_id: "p" + i, roles: [role] },
        admin.token,
      );
    const sport = await request("/auth/login", {
      group_id: admin.group_id,
      username: "SG",
      password,
    });
    await request(
      group + "/sync",
      {
        operation_id: "start-" + admin.group_id,
        occurrence_id: "qa-session",
        domain: "sport",
        base_revision: 0,
        generation: 0,
        reason: "QA",
        payload: {
          is_active: true,
          session: {
            id: "active-" + admin.group_id.replace("#", ""),
            team_id: admin.group_id,
            played_at: "2026-10-16T10:00:00",
            status: "DRAFT",
            session_type: "CLASSIC_2",
            is_ranked: 1,
            score_a: 0,
            score_b: 0,
            team_names: JSON.stringify({ A: "Atlas", B: "Union" }),
            team_colors: JSON.stringify({ A: 4282090230, B: 4294143798 }),
          },
          participations: members
            .slice(0, 2)
            .map((m, i) => ({
              id: "part-" + m.id,
              session_id: "active-" + admin.group_id.replace("#", ""),
              player_id: m.id,
              team: i ? "B" : "A",
              goals: 0,
              assists: 0,
              yellow_cards: 0,
              red_cards: 0,
            })),
        },
      },
      sport.token,
    );
    console.log("Browser regression: launching Chrome");
    const browser = await chromium.launch({
      channel: "chrome",
      headless: true,
    });
    console.log("Browser regression: Chrome ready");
    try {
      const page = await browser.newPage({
        viewport: { width: 1100, height: 1200 },
      });
      const errors = [];
      page.on("pageerror", (error) => errors.push(error.message));
      await page.goto(base);
      await page.getByRole("button", {name: "Rejoindre un groupe", exact: true}).click();
      await enter(page.getByRole("textbox").nth(0), admin.group_id);
      await enter(page.getByRole("textbox").nth(1), "SG");
      await enter(page.getByRole("textbox").nth(2), password);
      await page
        .getByRole("button", { name: "Se connecter", exact: true })
        .click();
      await page
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .waitFor({ timeout: 20000 });
      await page
        .getByRole("button", {
          name: "Reprendre le match en direct",
          exact: true,
        })
        .click();
      await page
        .getByRole("button", {
          name: "Ajouter un but",
          exact: true,
        })
        .waitFor();
      assert.deepEqual(errors, []);
    } finally {
      const p=browser.contexts()[0]?.pages()[0];
      if(p){console.log((await p.locator("body").innerText()).slice(-2500));await p.screenshot({path:"docs/parity-captures/shared-merge-final.png"});}
      await browser.close();
    }
  },
);
