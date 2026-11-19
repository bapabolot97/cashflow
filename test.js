// Offline cloud UI smoke tests: auth and database are isolated in memory.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const {JSDOM, VirtualConsole} = require('jsdom');
const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const errors = [], results = [], windows = [];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(fn, label) {
  for (let i = 0; i < 150; i++) { if (fn()) return; await delay(10); }
  throw new Error('Timed out waiting for ' + label);
}
function check(label, fn) {
  try { fn(); results.push(true); console.log('PASS  ' + label); }
  catch (e) { results.push(false); console.log('FAIL  ' + label + ': ' + e.message); }
}

// Unsupported operations fail instead of silently succeeding.
function mockSupabase() {
  const tables = Object.fromEntries(['transactions','categories','budgets','recurring','wallets','portfolio','settings'].map(t => [t, []]));
  const account = {id:'mock-user-1', email:'smoke@cashflow.app', user_metadata:{name:'Smoke User', username:'smoke'}};
  const copy = value => JSON.parse(JSON.stringify(value));
  let session = null, nextId = 1;
  function from(table) {
    if (!tables[table]) throw new Error('Unsupported table: ' + table);
    let operation = 'select', payload, filters = [], single = false;
    const q = {
      select() { return q; },
      insert(value) { operation = 'insert'; payload = value; return q; },
      eq(key, value) { filters.push([key, value]); return q; },
      order() { return q; },
      maybeSingle() { single = true; return q; },
      then(resolve, reject) {
        return Promise.resolve().then(() => {
          if (!session) throw new Error('Database access without mock session');
          let rows;
          if (operation === 'insert') {
            rows = (Array.isArray(payload) ? payload : [payload]).map(row => {
              if (row.user_id !== account.id) throw new Error('Wrong mock user_id');
              const stored = {...copy(row), id:'mock-row-' + nextId++};
              tables[table].push(stored); return stored;
            });
          } else rows = tables[table].filter(row => filters.every(([key, value]) => row[key] === value));
          return {data:single ? (rows[0] ? copy(rows[0]) : null) : copy(rows), error:null};
        }).then(resolve, reject);
      }
    };
    return q;
  }
  const client = {
    from,
    rpc(name, args) {
      if (name === 'resolve_user_email') return Promise.resolve({data:args.p_identifier === 'smoke' ? account.email : null, error:null});
      if (name === 'is_admin') return Promise.resolve({data:false, error:null});
      if (name === 'log_user_login') return Promise.resolve({data:null, error:null});
      return Promise.reject(new Error('Unsupported RPC: ' + name));
    },
    auth: {
      getSession: () => Promise.resolve({data:{session}}),
      onAuthStateChange: () => ({data:{subscription:{unsubscribe(){}}}}),
      signInWithPassword({email, password}) {
        if (email !== account.email || password !== 'fake-password') return Promise.resolve({data:{user:null, session:null}, error:{message:'Invalid login credentials'}});
        session = {user:copy(account)};
        return Promise.resolve({data:{user:copy(account), session:copy(session)}, error:null});
      },
      signOut() { session = null; return Promise.resolve({error:null}); }
    }
  };
  return {createClient:() => client};
}
const mock = mockSupabase();
function makeDom() {
  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push('jsdom: ' + e.message));
  vc.on('error', (...args) => errors.push('console.error: ' + args.join(' ')));
  const dom = new JSDOM(html, {
    runScripts:'dangerously', pretendToBeVisual:true, url:'http://localhost/', virtualConsole:vc,
    // Default jsdom resource loader does not fetch external scripts or other resources.
    beforeParse(w) {
      w.supabase = mock;
      w.addEventListener('error', e => errors.push('window: ' + (e.error && e.error.stack || e.message)));
      w.fetch = () => { errors.push('Blocked fetch'); return Promise.reject(new Error('Network disabled')); };
      w.XMLHttpRequest = class { constructor() { errors.push('Blocked XMLHttpRequest'); throw new Error('Network disabled'); } };
      w.WebSocket = class { constructor() { errors.push('Blocked WebSocket'); throw new Error('Network disabled'); } };
      w.scrollTo = () => {};
      w.HTMLCanvasElement.prototype.getContext = () => ({clearRect(){},fillRect(){},fillText(){},beginPath(){},moveTo(){},lineTo(){},arc(){},closePath(){},fill(){},stroke(){}});
    }
  });
  windows.push(dom.window); return dom.window;
}
function click(w, selector) { const el = w.document.querySelector(selector); assert(el, 'Missing element ' + selector); el.click(); }
const text = (w, id) => w.document.getElementById(id).textContent.trim();
const digits = s => s.replace(/\D/g, '');

(async () => {
  let w = makeDom();
  const $ = id => w.document.getElementById(id);
  const has = (id, cls) => $(id).classList.contains(cls);
  await until(() => w.sb && text(w, 'modeLabel').includes('Cloud'), 'cloud boot');
  check('boot shows login and hides app', () => { assert(!has('authView','hid')); assert(!has('appView','on')); });
  click(w, '#modeBtn');
  check('mode button remains cloud-only', () => { assert.equal(w.mode, 'cloud'); assert.match(text(w, 'modeLabel'), /Cloud/); assert.equal(JSON.parse(w.localStorage.getItem('cf_mode')), 'cloud'); });
  $('le').value = 'smoke'; $('lp').value = 'wrong-password'; click(w, '#btnDoLogin');
  await until(() => text(w, 'toasts').includes('Username atau password salah'), 'invalid login feedback');
  check('invalid login is rejected', () => { assert(!has('authView','hid')); assert(!has('appView','on')); });
  $('lp').value = 'fake-password'; click(w, '#btnDoLogin');
  await until(() => has('appView','on') && w.cats.length === 9 && text(w, 'uName') === 'Smoke User', 'login and cloud pull');
  check('login renders authenticated user', () => { assert(has('authView','hid')); assert.equal(text(w, 'uName'), 'Smoke User'); });
  check('cloud categories render', () => assert(w.document.querySelectorAll('#qCats .cat').length > 0));
  $('qAmt').value = '25000'; click(w, '[onclick="saveQuick()"]');
  await until(() => text(w, 'sCnt') === '1', 'quick transaction');
  check('quick expense updates dashboard and clears input', () => { assert.equal(digits(text(w, 'sExp')), '25000'); assert.equal($('qAmt').value, ''); });
  click(w, '[onclick="openTx()"]');
  check('transaction modal opens', () => assert(has('mTx','on')));
  $('txN').value = 'Smoke rent'; $('txA').value = '750000';
  click(w, '#mTx [onclick="saveTx()"]');
  await until(() => !has('mTx','on') && text(w, 'sCnt') === '2', 'modal transaction');
  check('modal expense appears in dashboard', () => { assert.equal(digits(text(w, 'sExp')), '775000'); assert.match(text(w, 'recentList'), /Smoke rent/); });
  click(w, 'nav a[data-p="tx"]');
  check('transaction page lists saved transaction', () => { assert(has('p-tx','on')); assert.match(text(w, 'p-tx'), /Smoke rent/); });
  click(w, 'nav a[data-p="rep"]');
  check('report shows both expenses', () => { assert(has('p-rep','on')); assert.equal(digits(text(w, 'rExp')), '775000'); assert.equal(text(w, 'rCnt'), '2'); });
  // New DOM has fresh localStorage; only the mock cloud/session survives.
  w.close(); w = makeDom();
  await until(() => has('appView','on') && text(w, 'sCnt') === '2', 'new page cloud restore');
  check('new page restores session and cloud transactions', () => { assert.equal(text(w, 'uName'), 'Smoke User'); assert.equal(digits(text(w, 'sExp')), '775000'); assert.match(text(w, 'recentList'), /Smoke rent/); });
  click(w, '[title="Keluar"]');
  check('logout returns to login', () => { assert(!has('authView','hid')); assert(!has('appView','on')); });
  // Start another fresh page so this assertion cannot pass from stale UI state.
  w.close(); w = makeDom();
  await until(() => w.sb && text(w, 'modeLabel').includes('Cloud'), 'logged-out page boot');
  check('logged-out session does not reopen app', () => assert(!has('appView','on')));
  $('le').value = 'smoke'; $('lp').value = 'fake-password'; click(w, '#btnDoLogin');
  await until(() => has('appView','on') && text(w, 'sCnt') === '2', 'login after logout');
  check('login after logout reloads cloud transactions', () => { assert.equal(text(w, 'uName'), 'Smoke User'); assert.match(text(w, 'recentList'), /Smoke rent/); });
})().catch(e => { results.push(false); console.log('FAIL  flow completed: ' + (e.stack || e)); })
.finally(() => {
  windows.forEach(w => w.close());
  const failed = results.filter(ok => !ok).length;
  console.log(`\nTotal: ${results.length}  Passed: ${results.length - failed}  Failed: ${failed}`);
  console.log('Runtime errors captured: ' + errors.length);
  errors.forEach(e => console.log('  ! ' + e));
  if (failed || errors.length) process.exitCode = 1;
});
