import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const base = process.env.STATOO_ENTRY_URL || 'http://127.0.0.1:19101/';
async function enter(locator, value) {
  await locator.click();
  await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, {delay: 10});
  await locator.page().keyboard.press('Tab');
}
test('ENT02/05/06 create group, assign responsibility, join as member', {timeout: 150000}, async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 838, height: 1000}});
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  mkdirSync('docs/group-entry-captures', {recursive: true});
  try {
    await page.goto(base);
    await page.getByRole('button', {name: 'Créer un groupe', exact: true}).waitFor({timeout: 45000});
    await page.screenshot({path:'docs/group-entry-captures/entry-web.png'});
    await page.getByRole('button', {name: 'Créer un groupe', exact: true}).click();
    await page.getByRole('button', {name: 'Passer', exact: true}).press('Enter');
    await enter(page.getByRole('textbox', {name: 'ex: FC Urban, Les Galactiques...', exact: true}), 'Groupe QA Entrée');
    await page.getByRole('button', {name: "Continuer vers l'effectif", exact: true}).click();
    for (const name of ['Alice', 'Bob', 'Camille', 'Diane', 'Émile', 'Fatou']) {
      await enter(page.getByRole('textbox', {name: 'Nom ou prénom (ex: Lucas, Karim...) *', exact: true}), name);
      await page.getByRole('button', {name: 'Ajouter ce joueur', exact: true}).click();
    }
    await page.getByRole('button', {name: 'Continuer vers l’accès Admin', exact: true}).click();
    await page.getByText('Créer votre accès Admin', {exact:true}).waitFor();
    await enter(page.getByRole('textbox', {name:/Votre identifiant/}), 'adminqa');
    await enter(page.getByRole('textbox', {name:/^Mot de passe Au/}), 'QA-Password-2026');
    await enter(page.getByRole('textbox', {name:/Mot de passe commun/}), 'QA-Members-2026');
    let interruptSnapshot = true;
    await page.route('**/groups/*', async route => {
      if (interruptSnapshot && route.request().method() === 'GET') {
        interruptSnapshot = false;
        await route.abort('failed');
      } else await route.continue();
    });
    const registered = page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === '/groups');
    await page.getByRole('button', {name:'Créer le groupe partagé', exact:true}).click();
    const response = await registered;
    assert.ok(response.ok(), await response.text());
    const identity = await response.json();
    await page.getByText(/Impossible de joindre Statoo/).waitFor();
    await page.getByRole('button', {name:'Créer le groupe partagé',exact:true}).waitFor();
    const replayed = page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === '/groups');
    await page.getByRole('button', {name:'Créer le groupe partagé',exact:true}).click();
    const replay = await replayed;
    assert.ok(replay.ok(), await replay.text());
    assert.equal((await replay.json()).group_id, identity.group_id);
    await page.getByText('Désigner les responsables', {exact:true}).waitFor();
    await page.screenshot({path:'docs/group-entry-captures/responsibilities.png'});
    await page.getByRole('button', {name:/Ajouter un gestionnaire/}).click();
    await page.getByText('Membre', {exact:true}).click();
    await page.keyboard.press('Home');
    await page.keyboard.press('Enter');
    await enter(page.getByRole('textbox', {name:'Identifiant', exact:true}), 'presidentqa');
    await enter(page.getByRole('textbox', {name:'Mot de passe (8 caractères minimum)', exact:true}), 'QA-President-2026');
    await page.getByRole('checkbox', {name:'Président', exact:true}).check();
    const created = page.waitForResponse(r=>r.request().method()==='POST' && r.url().endsWith('/accounts'));
    await page.getByRole('button', {name:'Créer', exact:true}).click();
    assert.ok((await created).ok());
    await page.getByRole('button', {name:/presidentqa/}).waitFor();
    const snapshot = await (await fetch(`http://127.0.0.1:19102/groups/${encodeURIComponent(identity.group_id)}`, {headers:{Authorization:`Bearer ${identity.token}`}})).json();
    assert.equal(snapshot.members.length, 6);
    await page.getByRole('button', {name:'Terminer et ouvrir le groupe', exact:true}).click();
    await page.getByRole('button', {name:'Nouvelle séance', exact:true}).waitFor();
    const member = await browser.newContext({viewport:{width:393,height:852}});
    const joined = await member.newPage();
    await joined.goto(base);
    await joined.getByRole('button', {name:'Rejoindre un groupe',exact:true}).waitFor({timeout:45000});
    await joined.getByRole('button', {name:'Rejoindre un groupe',exact:true}).click();
    await enter(joined.getByRole('textbox', {name:/Identifiant du groupe/}), identity.group_id);
    await enter(joined.getByRole('textbox', {name:/^Identifiant Ex/}), 'membres');
    await enter(joined.getByRole('textbox', {name:/Mot de passe/}), 'QA-Members-2026');
    await joined.getByRole('button', {name:'Se connecter',exact:true}).click();
    await joined.waitForURL(url => !url.hash.includes('groupe-partage'));
    await joined.screenshot({path:'docs/group-entry-captures/member-home.png'});
    await joined.getByText(/Groupe QA Entrée/).first().waitFor();
    assert.equal(await joined.getByRole('button', {name:/Ajouter un gestionnaire/}).count(),0);
    await joined.screenshot({path:'docs/group-entry-captures/member-home.png'});
    await member.close();
  } catch (error) {
    console.log((await page.locator('body').innerText()).slice(-4000));
    await page.screenshot({path:'docs/group-entry-captures/failure.png'});
    throw error;
  } finally { await context.close(); await browser.close(); }
});
