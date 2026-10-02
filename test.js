// Runtime smoke test: load index.html in jsdom, boot the app, exercise core flows
const fs = require('fs');
const { JSDOM } = require('jsdom');

const html = fs.readFileSync('D:/cashflow-app/index.html', 'utf8');

const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  resources: undefined,           // do NOT fetch the supabase CDN
  pretendToBeVisual: true,
  url: 'http://localhost/'
});
const { window } = dom;

window.addEventListener('error', e => errors.push('window.onerror: ' + (e.error && e.error.stack || e.message)));
window.onerror = (m, s, l, c, err) => { errors.push('onerror: ' + (err && err.stack || m)); };
const origErr = console.error;
window.console.error = (...a) => { errors.push('console.error: ' + a.join(' ')); };

// jsdom has no canvas; stub it
window.HTMLCanvasElement.prototype.getContext = function () {
  const noop = () => {};
  return {
    clearRect: noop, fillRect: noop, fillText: noop, beginPath: noop, moveTo: noop,
    lineTo: noop, arc: noop, closePath: noop, fill: noop, stroke: noop,
    set fillStyle(v) {}, get fillStyle() { return ''; },
    set strokeStyle(v) {}, get strokeStyle() { return ''; },
    set font(v) {}, get font() { return ''; },
    set textAlign(v) {}, get textAlign() { return ''; }
  };
};
const wait = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  await wait(300);  // let DOMContentLoaded/boot run

  const d = window.document;
  const $ = id => d.getElementById(id);
  const out = [];
  const check = (label, cond, extra) => out.push((cond ? 'PASS' : 'FAIL') + '  ' + label + (extra ? '  [' + extra + ']' : ''));

  // 1. boot happened
  check('boot: settings loaded', typeof window.S !== 'undefined' && window.S && window.S.appName === 'CashFlow');
  check('boot: default categories seeded', Array.isArray(window.cats) && window.cats.length >= 8, 'cats=' + (window.cats||[]).length);
  check('boot: quick amounts seeded', Array.isArray(window.qas) && window.qas.length === 6);
  check('boot: auth screen visible', !$('authView').classList.contains('hid'));
  check('boot: app hidden', !$('appView').classList.contains('on'));

  // 2. register in local mode
  $('rn').value = 'Budi';
  $('re').value = 'budi@test.com';
  $('rp').value = 'rahasia123';
  window.doReg();
  await wait(120);
  check('register: app visible', $('appView').classList.contains('on'));
  check('register: auth hidden', $('authView').classList.contains('hid'));
  check('register: user set', window.user && window.user.name === 'Budi');
  check('register: greeting rendered', $('uName').textContent === 'Budi', 'uName=' + $('uName').textContent);

  // 3. quick add a transaction
  window.setQType('exp');
  $('qAmt').value = '25000';
  window.saveQuick();
  await wait(80);
  check('quick add: transaction stored', window.tx.length === 1, 'tx=' + window.tx.length);
  check('quick add: amount correct', window.tx[0] && window.tx[0].amount === 25000);
  check('quick add: type expense', window.tx[0] && window.tx[0].type === 'exp');
  check('quick add: has date', !!(window.tx[0] && /^\d{4}-\d{2}-\d{2}$/.test(window.tx[0].date)));
  check('quick add: has time HH:MM (no seconds)', !!(window.tx[0] && /^\d{2}:\d{2}$/.test(window.tx[0].time)), 'time=' + (window.tx[0]||{}).time);
  check('quick add: input cleared', $('qAmt').value === '');

  // 4. dashboard reflects it
  check('dash: expense stat updated', $('sExp').textContent !== 'Rp 0', 'sExp=' + $('sExp').textContent);
  check('dash: transaction count = 1', $('sCnt').textContent === '1');
  check('dash: recent list rendered', $('recentList').innerHTML.indexOf('Transaksi') === -1 || $('recentList').innerHTML.indexOf('ti') !== -1);
  check('dash: category breakdown rendered', $('catBreak').innerHTML.length > 10);

  // 5. quick add income
  window.setQType('inc');
  $('qAmt').value = '5000000';
  window.saveQuick();
  await wait(80);
  check('income add: stored', window.tx.length === 2);
  check('dash: income stat updated', $('sInc').textContent !== 'Rp 0', 'sInc=' + $('sInc').textContent);
  check('dash: balance = 4,975,000', $('sBal').textContent.replace(/\D/g,'') === '4975000', 'sBal=' + $('sBal').textContent);

  // 6. full transaction modal
  window.openTx();
  await wait(50);
  check('tx modal: opens', $('mTx').classList.contains('on'));
  $('txN').value = 'Bayar kos';
  $('txA').value = '750000';
  window.saveTx();
  await wait(80);
  check('tx modal: saved', window.tx.length === 3, 'tx=' + window.tx.length);
  check('tx modal: closed after save', !$('mTx').classList.contains('on'));
  check('tx modal: name stored', window.tx.some(t => t.name === 'Bayar kos'));

  // 7. wallet
  window.openWp();
  await wait(40);
  $('wpN').value = 'BCA';
  $('wpA').value = '1000000';
  window.setWpType('bank');
  window.saveWp();
  await wait(80);
  check('wallet: created', window.wps.length === 1, 'wps=' + window.wps.length);
  check('wallet: balance', window.wps[0] && window.wps[0].balance === 1000000);
  check('wallet: rendered in list', $('wpList').innerHTML.indexOf('BCA') !== -1);

  // 8. amplop
  window.openAmp();
  await wait(40);
  $('ampN').value = 'Makan';
  $('ampA').value = '1500000';
  window.saveAmp();
  await wait(80);
  check('amplop: created', window.amps.length === 1);
  check('amplop: rendered', $('ampList').innerHTML.indexOf('Makan') !== -1);
  check('amplop: total label set', $('ampLbl').textContent.indexOf('1.500.000') !== -1, 'ampLbl=' + $('ampLbl').textContent);

  // 9. recurring
  window.openFrq();
  await wait(40);
  $('frqN').value = 'Spotify';
  $('frqA').value = '54990';
  window.setFrq('monthly');
  $('frqD').value = '5';
  window.saveFrq();
  await wait(80);
  check('recurring: created', window.frqs.length === 1);
  check('recurring: rendered', $('frqList').innerHTML.indexOf('Spotify') !== -1);
  check('calendar: rendered', $('calGrid').innerHTML.length > 50);
  check('calendar: month label', $('calLabel').textContent.length > 3, $('calLabel').textContent);

  // 10. portfolio
  window.openPf();
  await wait(40);
  $('pfN').value = 'BBCA';
  $('pfS').value = 'BBCA';
  $('pfCap').value = '10000000';
  $('pfVal').value = '12000000';
  window.setPfType('saham');
  window.savePf();
  await wait(80);
  check('portfolio: created', window.pfs.length === 1);
  check('portfolio: PnL = +2,000,000', $('pfPnl').textContent.replace(/\D/g,'') === '2000000', 'pfPnl=' + $('pfPnl').textContent);
  check('portfolio: rendered', $('pfList').innerHTML.indexOf('BBCA') !== -1);

  // 11. category admin
  window.openCat();
  await wait(40);
  $('catN').value = 'Jajan';
  $('catI').value = '🍰';
  $('catT').value = 'exp';
  $('catC').value = '#e91e63';
  window.saveCat();
  await wait(80);
  check('category: added', window.cats.length === 9, 'cats=' + window.cats.length);
  check('category: rendered in admin table', $('catBody').innerHTML.indexOf('Jajan') !== -1);

  // 12. navigation across all pages
  const pages = ['dash','tx','amp','frq','wp','pf','rep','admin','prof'];
  let navOk = true;
  pages.forEach(p => {
    window.go(p);
    const el = $('p-' + p);
    if (!el || !el.classList.contains('on')) { navOk = false; out.push('FAIL  nav: page ' + p + ' did not activate'); }
  });
  check('navigation: all 9 pages activate', navOk);

  // 13. report
  window.go('rep');
  window.renderReport();
  await wait(60);
  check('report: income total', $('rInc').textContent.replace(/\D/g,'') === '5000000', 'rInc=' + $('rInc').textContent);
  check('report: expense total', $('rExp').textContent.replace(/\D/g,'') === '775000', 'rExp=' + $('rExp').textContent);
  check('report: row count 3', $('rCnt').textContent === '3', 'rCnt=' + $('rCnt').textContent);
  check('report: table rows rendered', ($('rBody').innerHTML.match(/<tr>/g)||[]).length === 3);

  // 14. theme switching
  window.setTheme('dark');
  check('theme: dark applied', d.documentElement.getAttribute('data-theme') === 'dark');
  window.setTheme('senja');
  check('theme: senja applied', d.documentElement.getAttribute('data-theme') === 'senja');
  window.setTheme('light');
  check('theme: light removes attr', !d.documentElement.getAttribute('data-theme'));

  // 15. settings persistence
  $('setName').value = 'Duitku';
  $('setSym').value = 'IDR';
  window.saveSettings();
  await wait(50);
  check('settings: brand updated', $('brandName').textContent === 'Duitku', 'brand=' + $('brandName').textContent);
  check('settings: currency symbol applied', $('qSym').textContent === 'IDR', 'qSym=' + $('qSym').textContent);
  check('settings: saved to localStorage', JSON.parse(window.localStorage.getItem('cf_settings')).appName === 'Duitku');

  // 16. persistence across reload
  const saved = window.localStorage.getItem('cf_data');
  check('persist: data written to localStorage', !!saved);
  const parsed = JSON.parse(saved);
  check('persist: 3 transactions saved', parsed.tx.length === 3, 'saved tx=' + parsed.tx.length);
  check('persist: wallets saved', parsed.wps.length === 1);
  check('persist: portfolio saved', parsed.pfs.length === 1);

  // 17. delete a transaction
  const victim = window.tx[0].id;
  window.confirm = () => true;
  window.delTx(victim);
  await wait(80);
  check('delete: transaction removed', window.tx.length === 2, 'tx=' + window.tx.length);

  // 18. logout / login round trip
  window.doLogout();
  await wait(60);
  check('logout: auth screen shown', !$('authView').classList.contains('hid'));
  $('le').value = 'budi@test.com';
  $('lp').value = 'rahasia123';
  window.doLogin();
  await wait(120);
  check('login: back in app', $('appView').classList.contains('on'));
  check('login: name restored', window.user && window.user.name === 'Budi');
  check('login: transactions still there', window.tx.length === 2, 'tx=' + window.tx.length);

  // results
  console.log('\n===== SMOKE TEST RESULTS =====');
  out.forEach(l => console.log(l));
  const fails = out.filter(l => l.startsWith('FAIL'));
  console.log('\nTotal: ' + out.length + '  Passed: ' + (out.length - fails.length) + '  Failed: ' + fails.length);
  console.log('\nRuntime errors captured: ' + errors.length);
  errors.slice(0, 10).forEach(e => console.log('  ! ' + e.slice(0, 300)));
  process.exit(fails.length || errors.length ? 1 : 0);
})();
