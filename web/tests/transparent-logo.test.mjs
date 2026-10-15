import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
test('LOGO-01/02/03 header uses an alpha PNG without a CSS background',()=>{
 const file=n=>readFileSync(new URL('../'+n,import.meta.url));
 assert.ok(file('index.html').toString().includes('icons/logo-transparent.png'),'Header must use transparent logo');
 const png=file('icons/logo-transparent.png');assert.equal(png.readUInt32BE(0),0x89504e47);assert.ok([4,6].includes(png[25]),'PNG must include alpha');
 const css=file('styles.css').toString();const rule=css.match(/\.brand img\s*\{([^}]+)\}/)[1];assert.ok(!/background:\s*#fff/i.test(rule),'Remove white CSS backing');
 assert.ok(file('sw.js').toString().includes('icons/logo-transparent.png'));
});
