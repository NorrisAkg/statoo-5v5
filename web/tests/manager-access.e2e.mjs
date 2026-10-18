import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
import {chromium} from 'playwright';

const api = process.env.STATOO_MANAGER_API || 'http://127.0.0.1:19122';
const base = process.env.STATOO_MANAGER_URL || 'http://127.0.0.1:19121/';
async function enter(locator, value) {
  await locator.click(); await locator.press('ControlOrMeta+A');
  await locator.pressSequentially(value, {delay:10});
  await locator.page().keyboard.press('Tab');
}
async function visible(page, locator) {
  for (let i=0; i<14; i++) {
    if (await locator.count() && await locator.first().isVisible()) return;
    await page.mouse.wheel(0,450); await page.waitForTimeout(120);
  }
  await locator.waitFor();
}
async function login(page, group, username, password) {
  await page.goto(base);
  await page.getByRole('button',{name:'Passer',exact:true}).waitFor({timeout:45000});
  await page.getByRole('button',{name:'Passer',exact:true}).click();
  await page.getByRole('button',{name:'Rejoindre un groupe',exact:true}).click();
  await enter(page.getByRole('textbox',{name:/Identifiant du groupe/}),group);
  await enter(page.getByRole('textbox',{name:/^Identifiant Ex/}),username);
  await enter(page.getByRole('textbox',{name:/Mot de passe/}),password);
  await page.getByRole('button',{name:'Se connecter',exact:true}).click();
  await page.waitForURL(url=>!url.hash.includes('groupe-partage'));
}
test('GES browser: create generated manager access, copy, login, persistence and confirmed reset', {timeout:180000}, async () => {
  const created = await fetch(api+'/groups',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:'Atlas QA gestionnaires',username:'adminqa',password:'QA-Admin-2026',shared_username:'membres',shared_password:'QA-Members-2026',members:[{id:'a',name:'Alice'}]})});
  assert.equal(created.status,201);
  const identity=await created.json();
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:393,height:852},permissions:['clipboard-read','clipboard-write']});
  const page=await context.newPage();page.setDefaultTimeout(20000);
  mkdirSync('docs/manager-access-captures',{recursive:true});
  try {
    await login(page,identity.group_id,'adminqa','QA-Admin-2026');
    await page.goto(base+'#/groupe-partage');
    const add=page.getByRole('button',{name:/Ajouter un gestionnaire/});
    await visible(page,add);await add.click();
    assert.equal(await page.getByRole('textbox').count(),1);
    await page.getByText('Membre',{exact:true}).click();await page.keyboard.press('Home');await page.keyboard.press('Enter');
    await enter(page.getByRole('textbox',{name:/Identifiant/}),'sportqa');
    await page.getByRole('checkbox',{name:'Secrétaire général',exact:true}).check();
    await page.screenshot({path:'docs/manager-access-captures/create-light.png'});
    const accountResponse=page.waitForResponse(r=>r.request().method()==='POST'&&r.url().endsWith('/accounts'));
    await page.getByRole('button',{name:'Créer',exact:true}).click();
    const response=await accountResponse;assert.equal(response.status(),201);
    const account=await response.json();
    const generated=response.request().postDataJSON().password;
    assert.match(generated,/^[A-Za-z0-9]{8}$/);
    const access=page.getByRole('button',{name:'Accès de sportqa',exact:true});
    await visible(page,access);await access.click();
    await page.getByRole('button',{name:'Copier les accès',exact:true}).click();
    await page.getByText('Accès copiés',{exact:true}).first().waitFor();
    const clipboard=await page.evaluate(()=>navigator.clipboard.readText());
    assert.ok(clipboard.includes(generated));assert.ok(clipboard.includes('sportqa'));assert.ok(clipboard.includes(identity.group_id));
    assert.ok(!clipboard.includes('QA-Admin-2026'));
    assert.ok(!(await page.evaluate(()=>Object.values(localStorage).join('\n'))).includes(generated));
    await page.screenshot({path:'docs/manager-access-captures/access-light.png'});
    await page.getByRole('button',{name:'Fermer',exact:true}).click();
    await page.reload();await visible(page,access);await access.click();
    await page.getByRole('button',{name:'Copier les accès',exact:true}).waitFor();
    const member=await browser.newContext({viewport:{width:393,height:852}});const joined=await member.newPage();
    await login(joined,identity.group_id,'sportqa',generated);
    await joined.getByText(/Atlas QA gestionnaires/).first().waitFor();
    await page.emulateMedia({colorScheme:'dark'});
    await page.getByRole('button',{name:'Générer un nouveau mot de passe',exact:true}).click();
    await page.screenshot({path:'docs/manager-access-captures/reset-dark.png'});
    await page.getByRole('button',{name:'Annuler',exact:true}).click();
    let verification=await fetch(api+'/groups/'+encodeURIComponent(identity.group_id)+'/accounts/'+account.id+'/password/verify',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+identity.token},body:JSON.stringify({password:generated})});
    assert.ok(verification.ok);
    await page.getByRole('button',{name:'Générer un nouveau mot de passe',exact:true}).click();
    const resetResponse=page.waitForResponse(r=>r.request().method()==='POST'&&r.url().endsWith('/accounts/'+account.id+'/password'));
    await page.getByRole('button',{name:'Remplacer et mémoriser',exact:true}).click();
    const reset=await resetResponse;assert.ok(reset.ok());
    const newPassword=reset.request().postDataJSON().password;assert.match(newPassword,/^[A-Za-z0-9]{8}$/);assert.notEqual(newPassword,generated);
    await page.getByRole('button',{name:'Copier les accès',exact:true}).click();
    await page.getByText('Accès copiés',{exact:true}).first().waitFor();
    assert.ok((await page.evaluate(()=>navigator.clipboard.readText())).includes(newPassword));
    await page.screenshot({path:'docs/manager-access-captures/access-dark.png'});
    await member.close();
  } catch(error) {
    await page.screenshot({path:'docs/manager-access-captures/failure.png'});
    console.log((await page.locator('body').innerText()).slice(-3000));throw error;
  } finally {await context.close();await browser.close();}
});
