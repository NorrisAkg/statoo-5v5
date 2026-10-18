import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
import {chromium} from 'playwright';

const api = process.env.STATOO_ACCESS_API || 'http://127.0.0.1:19112';
const base = process.env.STATOO_ACCESS_URL || 'http://127.0.0.1:19111/';
const password = 'QA-Members-2026';
async function enter(locator, value) {
  await locator.click();
  await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, {delay: 10});
  await locator.page().keyboard.press('Tab');
}
test('ACC browser: verify, protected persistence, explicit copy, rotation and member permissions', {timeout: 150000}, async () => {
  const created = await fetch(api + '/groups', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({name:'Atlas QA accès', username:'adminqa', password:'QA-Admin-2026', shared_username:'membres', shared_password:password, members:[{id:'a', name:'Alice'}]})});
  assert.equal(created.status, 201);
  const identity = await created.json();
  const browser = await chromium.launch({channel:'chrome', headless:true});
  const context = await browser.newContext({viewport:{width:393,height:852}, permissions:['clipboard-read','clipboard-write']});
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  mkdirSync('docs/collective-access-captures', {recursive:true});
  async function join(target, username, pwd) {
    await target.goto(base);
    await target.getByRole('button', {name:'Passer',exact:true}).waitFor({timeout:45000});
    await target.getByRole('button', {name:'Passer',exact:true}).click();
    await target.getByRole('button', {name:'Rejoindre un groupe',exact:true}).click();
    await enter(target.getByRole('textbox', {name:/Identifiant du groupe/}), identity.group_id);
    await enter(target.getByRole('textbox', {name:/^Identifiant Ex/}), username);
    await enter(target.getByRole('textbox', {name:/Mot de passe/}), pwd);
    await target.getByRole('button', {name:'Se connecter',exact:true}).click();
    await target.waitForURL(url => !url.hash.includes('groupe-partage'));
  }
  try {
    await join(page, 'adminqa', 'QA-Admin-2026');
    await page.getByRole('button', {name:'Réglages',exact:true}).click();
    await page.getByRole('button', {name:'Renseigner le mot de passe commun',exact:true}).click();
    await enter(page.getByRole('textbox', {name:/Mot de passe commun/}), 'Wrong-Password');
    await page.getByRole('button', {name:'Vérifier et mémoriser',exact:true}).click();
    await page.getByText('Le mot de passe commun est incorrect.', {exact:true}).waitFor();
    await enter(page.getByRole('textbox', {name:/Mot de passe commun/}), password);
    await page.screenshot({path:'docs/collective-access-captures/form-light.png'});
    await page.getByRole('button', {name:'Vérifier et mémoriser',exact:true}).click();
    await page.getByRole('button', {name:'Copier les accès',exact:true}).waitFor();
    assert.equal(await page.getByText(password,{exact:true}).count(),0);
    await page.reload();
    await page.getByRole('button', {name:'Copier les accès',exact:true}).waitFor({timeout:45000});
    await page.getByRole('button', {name:'Copier les accès',exact:true}).click();
    await page.getByText('Accès copiés',{exact:true}).waitFor();
    const clipboard = await page.evaluate(() => navigator.clipboard.readText());
    assert.ok(clipboard.includes(identity.group_id));
    assert.ok(clipboard.includes(password));
    assert.ok(!clipboard.includes('QA-Admin-2026'));
    const localValues = await page.evaluate(() => Object.values(localStorage).join('\n'));
    assert.ok(!localValues.includes(password), 'plaintext must not appear in localStorage');
    await page.screenshot({path:'docs/collective-access-captures/saved-light.png'});
    await page.emulateMedia({colorScheme:'dark'});
    await page.waitForTimeout(500);
    await page.screenshot({path:'docs/collective-access-captures/saved-dark.png'});
    await page.getByRole('button',{name:'Vérifier un autre mot de passe',exact:true}).click();
    await page.screenshot({path:'docs/collective-access-captures/form-dark.png'});
    await page.getByRole('button',{name:'Annuler',exact:true}).click();
    const rotated = await fetch(api + '/groups/' + encodeURIComponent(identity.group_id) + '/shared-access', {method:'PUT', headers:{'Content-Type':'application/json',Authorization:'Bearer '+identity.token},body:JSON.stringify({group_id:identity.group_id,username:'new-members',password:'QA-Rotated-2026'})});
    assert.ok(rotated.ok);
    await page.getByRole('button',{name:'Copier les accès',exact:true}).click();
    await page.getByRole('button',{name:'Renseigner le mot de passe commun',exact:true}).waitFor();
    const memberContext = await browser.newContext({viewport:{width:393,height:852}});
    const member = await memberContext.newPage();
    await join(member, 'new-members', 'QA-Rotated-2026');
    await member.getByRole('button',{name:'Réglages',exact:true}).click();
    assert.equal(await member.getByText('Accès des membres',{exact:true}).count(),0);
    await memberContext.close();
  } catch (error) {
    await page.screenshot({path:'docs/collective-access-captures/failure.png'});
    console.log((await page.locator('body').innerText()).slice(-3000));
    throw error;
  } finally { await context.close(); await browser.close(); }
});
