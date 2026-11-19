// Isolated regressions: no network, real accounts, or cloud data are used.
const { JSDOM } = require('jsdom');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const dom = new JSDOM(fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8'), {
  runScripts: 'dangerously', url: 'http://localhost/'
});
const w = dom.window;
(async () => {
  await new Promise(resolve => setTimeout(resolve, 50));
  w.isAdminUser = true;
  w.user = { id: 'admin' };
  const maliciousName = "x');window.hits=42;//";
  w.sb = { rpc: name => Promise.resolve({ data: name === 'admin_users' ? [
    {id:'u1', name:maliciousName, email:'a@example.com', role:'user', banned:false, tx_count:0, tx_income:0, tx_expense:0}
  ] : {} }) };
  let received;
  const realResetPw = w.admResetPw;
  w.admResetPw = (id, name) => { received = [id, name]; };
  w.loadAdminUsers();
  await new Promise(resolve => setTimeout(resolve, 20));
  w.document.querySelector('#admUserBody button[title]').click();
  assert.equal(w.hits, undefined);
  assert.deepEqual(received, ['u1', maliciousName]);
  console.log('PASS admin malicious name remains data');

  w.admResetPw = realResetPw;
  let toastText = '', rpcArgs;
  w.toast = text => { toastText = text; };
  w.sb = {rpc: (name, params) => { rpcArgs = params; return Promise.resolve({error:null}); }};
  w.admResetPw('u1', 'Example');
  const passwordInput = w.document.getElementById('adminPasswordInput');
  assert.equal(passwordInput.type, 'password');
  assert.equal(passwordInput.value, '');
  passwordInput.value = 'example-secret-42';
  w.submitAdminPassword();
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(rpcArgs.p_target, 'u1');
  assert.equal(rpcArgs.p_new_password, 'example-secret-42');
  assert.equal(passwordInput.value, '');
  assert(!toastText.includes('example-secret-42'));
  console.log('PASS masked password reset clears input and never reveals it');
  for (const method of ['escape', 'backdrop']) {
    w.admResetPw('u1', 'Example');
    passwordInput.value = 'discard-me';
    if (method === 'escape') w.document.dispatchEvent(new w.KeyboardEvent('keydown', {key:'Escape', bubbles:true}));
    else w.document.getElementById('mAdminPassword').click();
    assert.equal(passwordInput.value, '');
    assert.equal(w.adminPasswordTarget, null);
    assert(!w.document.getElementById('mAdminPassword').classList.contains('on'));
  }
  console.log('PASS escape and backdrop clear password and target');
  let resolveRpc;
  w.sb = {rpc: () => new Promise(resolve => { resolveRpc = resolve; })};
  w.admResetPw('u1', 'Example');
  passwordInput.value = 'example-secret-42';
  w.submitAdminPassword();
  w.cancelAdminPassword();
  w.document.dispatchEvent(new w.KeyboardEvent('keydown', {key:'Escape', bubbles:true}));
  w.document.getElementById('mAdminPassword').click();
  assert(w.document.getElementById('mAdminPassword').classList.contains('on'));
  assert(w.document.getElementById('adminPasswordSubmit').disabled);
  resolveRpc({error:null});
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(passwordInput.value, '');
  assert(!w.document.getElementById('mAdminPassword').classList.contains('on'));
  console.log('PASS pending reset cannot be dismissed and clears on success');

  let readerCalled = false, message = '';
  w.mode = 'cloud';
  w.toast = value => { message = value; };
  w.FileReader = function () { readerCalled = true; };
  const before = w.tx;
  w.restore({target:{files:[{}], value:'example'}});
  assert.equal(readerCalled, false);
  assert.strictEqual(w.tx, before);
  assert(message.includes('dinonaktifkan'));
  console.log('PASS unsafe cloud restore stops before changing data');

  const RealDate = w.Date;
  w.Date = class extends RealDate { constructor(...args) { super(...(args.length ? args : ['2026-11-13T12:00:00+07:00'])); } };
  w.document.getElementById('rPeriod').value = 'lm';
  assert.equal(JSON.stringify(w.reportRange()), '["2026-10-01","2026-10-31"]');
  console.log('PASS report last month boundaries');
  dom.window.close();
})().catch(error => { console.error(error); process.exitCode = 1; dom.window.close(); });
