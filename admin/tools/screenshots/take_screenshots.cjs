// Desktop screenshots of the admin dashboard via the Chrome DevTools protocol.
// node tools/screenshots/take_screenshots.cjs ../docs/screenshots/admin http://localhost:5174
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const [outDir, base = 'http://localhost:5174'] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const port = 9334;
const profile = path.join(require('os').tmpdir(), 'orwickle-admin-shots-' + Date.now());
const proc = spawn(chrome, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--hide-scrollbars', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));

const WIDTH = 1440, HEIGHT = 900;
const session = JSON.stringify({
  accessToken: 'mock', refreshToken: 'mock', refreshedAt: Date.now(),
  user: { id: 'a0000000-0000-4000-8000-000000000001', email: 'subhash@gmail.com', role: 'admin', fullName: 'Subhash Rai', emailVerified: true, profileCompleted: true, approvalStatus: 'approved' },
});

(async () => {
  let wsUrl;
  for (let i = 0; i < 50 && !wsUrl; i++) {
    try { wsUrl = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find(t => t.type === 'page')?.webSocketDebuggerUrl; } catch {}
    if (!wsUrl) await sleep(200);
  }
  const ws = new WebSocket(wsUrl);
  await new Promise(r => ws.addEventListener('open', r, { once: true }));
  let id = 0; const pending = new Map();
  ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } });
  const send = (method, params = {}) => new Promise(r => { const n = ++id; pending.set(n, r); ws.send(JSON.stringify({ id: n, method, params })); });
  const evaluate = expression => send('Runtime.evaluate', { expression, awaitPromise: true });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 2, mobile: false });

  async function shot(name, { full = true } = {}) {
    let height = HEIGHT;
    if (full) {
      const r = await evaluate('Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)');
      height = Math.min(Math.max(r.result.result.value || HEIGHT, HEIGHT), 3000);
      await send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height, deviceScaleFactor: 2, mobile: false });
      await sleep(600);
    }
    const res = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(outDir, `${name}.png`), Buffer.from(res.result.data, 'base64'));
    await send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 2, mobile: false });
    console.log('saved', name, height);
  }

  // 1. login page, with the admin's email typed in
  await send('Page.navigate', { url: base + '/' });
  await sleep(4000);
  await evaluate(`(() => {
    const input = document.querySelector('input[type=email], input[name=email], input');
    if (!input) return;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(input, 'subhash@gmail.com');
    input.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);
  await sleep(500);
  await shot('01_admin_login', { full: false });

  // clicks the button or link that contains exactly this text
  const click = text => evaluate(`(() => {
    const el = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && e.textContent.trim() === ${JSON.stringify(text)});
    let target = el;
    while (target && !(target.tagName === 'BUTTON' || target.tagName === 'A' || target.getAttribute('role') === 'button')) target = target.parentElement;
    (target || el)?.click();
  })()`);

  // 2. signed in as Subhash Rai
  await evaluate(`sessionStorage.setItem('orwickle-admin-session', ${JSON.stringify(session)})`);
  // [file name, route, entry to open in a queue, also capture the review dialog]
  const pages = [
    ['02_admin_overview', '/'],
    ['03_admin_investor_verification', '/reviews/investors', 'Bilal Ahmed', true],
    ['04_admin_project_verification', '/reviews/listings', 'Smart irrigation kit', true],
    ['05_admin_owner_buyer_verification', '/reviews/accounts', 'Hamza Ali'],
    ['06_admin_users', '/users'],
    ['07_admin_user_detail', '/users/u4'],
    ['08_admin_verification_history', '/reviews/history'],
    ['09_admin_audit_log', '/audit'],
    ['10_admin_change_password', '/password'],
  ];
  for (const [name, route, open, dialog] of pages) {
    await send('Page.navigate', { url: base + route });
    await sleep(3500);
    await shot(name);
    if (!open) continue;
    // the queue again with the first entry opened
    await click(open);
    await sleep(1500);
    await shot(name + '_open');
    if (!dialog) continue;
    // "Start review" marks it Under Review and opens the decision dialog
    await click('Start review');
    await sleep(1500);
    await shot(name + '_review', { full: false });
  }
  ws.close(); proc.kill(); process.exit(0);
})().catch(e => { console.error(e); proc.kill(); process.exit(1); });
