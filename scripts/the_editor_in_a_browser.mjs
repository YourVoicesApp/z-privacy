// **Scribe's editor in the web trial, in Chrome** — paper 124, rule 88 (ح).
//
//   node scripts/the_editor_in_a_browser.mjs DEVTOOLS_PORT BASE_URL [SHOTS_DIR]
//
// Driven by `scripts/check_the_editor_in_a_browser.sh`, which serves the
// assembled `site-trial/` (Z's page and Scribe's, the real modules) with
// `scripts/preview_trial.sh` and starts Chrome with a profile of its own.
// Over the DevTools protocol, the way a visitor goes:
//
//   1. Z's page, `/en/try/`; the page's semantics switched on, so a button is
//      found by its words, never by a coordinate;
//   2. the Scribe button → Scribe's frame stands beside Z, in the end two
//      thirds of the width (rule 88 (ط); over Z below 1080 px), at
//      `scribe/`, and says it is ready;
//   3. words typed into the frame by the browser's own input (CDP
//      `insertText`, the IME's path) → the report counts them as Keyboard;
//   4. «Send to the editor» — the message Z's page sends, `scribe-insert`,
//      posted to the frame by the page → the report counts AI;
//   5. the control: a page of another origin (about:blank) may not hold the
//      editor — `frame-ancestors 'self'` refuses it, and Chrome says so;
//   5b. Z's copy handed over (`scribe-z-copy`) and pasted → AI; the control,
//      other text pasted → Paste (the frame's clipboard a stub in memory);
//      the browser's own paste (no Ctrl+V: a trusted paste event from
//      Chrome's in-memory clipboard) → AI for Z's copy, Paste for other
//      text, never Keyboard, each counted once; typing still Keyboard;
//      no save, print, export or download control; both pages load CanvasKit
//      from `/try/canvaskit/`;
//   6. «Close» → the frame is hidden and keeps the words; the button again →
//      it stands again with them;
//   7. «Start over» → the frame is gone from the page;
//   7b. «Copy the answer to the editor», in Arabic: disabled before an
//      answer; after a real turn (typed, «Copy Protected», an answer added)
//      it opens the editor on the left two thirds and the answer counts as AI;
//   8. the browser's storage, read: localStorage, sessionStorage, cookies,
//      IndexedDB, Cache Storage and service workers — all empty (85 (c)) —
//      and no Content-Security-Policy violation was reported, in either page.
//
// With SHOTS_DIR, the editor with its report is photographed in English,
// Arabic and Swedish at 390 and 1440 px wide. Prints `ok …` / `FAIL …` lines;
// exits 1 on any FAIL.
import { writeFileSync } from 'node:fs';

const [port, base, shots] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failed = 0;
const ok = (what) => console.log(`ok    ${what}`);
const fail = (what) => { failed += 1; console.log(`FAIL  ${what}`); };
const check = (cond, what) => (cond ? ok(what) : fail(what));

const version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
const ws = new WebSocket(version.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let id = 0;
const waiting = new Map();
const violations = [];
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && waiting.has(m.id)) { waiting.get(m.id)(m); waiting.delete(m.id); }
  const text = m.method === 'Log.entryAdded' ? m.params.entry.text
    : m.method === 'Runtime.consoleAPICalled' ? m.params.args.map((a) => a.value ?? '').join(' ') : '';
  if (/Content Security Policy|violates|Refused to/.test(text)) violations.push(text.slice(0, 200));
});
const send = (method, params = {}, sessionId) => new Promise((r) => {
  const i = ++id; waiting.set(i, r);
  ws.send(JSON.stringify({ id: i, method, params, sessionId }));
});

async function openPage(url, width, height) {
  const { result: { targetId } } = await send('Target.createTarget', { url: 'about:blank' });
  const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => send(m, p, sessionId);
  await s('Runtime.enable'); await s('Log.enable'); await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width < 600 });
  // A new tab is about:blank already; navigating it there again would land
  // after the next step and wipe what it did.
  if (url !== 'about:blank') await s('Page.navigate', { url });
  const js = async (expression) => {
    const r = await s('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    if (r.result?.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 300));
    return r.result?.result?.value;
  };
  const until = async (expression, ms = 30000) => {
    for (let t = 0; t < ms; t += 250) { if (await js(expression)) return true; await sleep(250); }
    return false;
  };
  return { targetId, s, js, until };
}

// What the page can read of a document: its semantics, switched on once.
const helpers = `
  window.__sem = (doc) => {
    const p = doc.querySelector('flt-semantics-placeholder');
    if (p) p.click();
    return doc.querySelectorAll('flt-semantics').length;
  };
  window.__words = (doc) => [...doc.querySelectorAll('flt-semantics, flt-semantics *')]
    .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.childElementCount ? '' : e.textContent || ''))
    .join('\\n');
  window.__press = (doc, re) => {
    const r = new RegExp(re);
    const b = [...doc.querySelectorAll('[role="button"], flt-semantics[flt-tappable]')]
      .find((e) => e.getAttribute('aria-disabled') !== 'true' &&
        r.test((e.getAttribute('aria-label') || '') + (e.textContent || '')));
    if (!b) return false;
    b.click();
    return true;
  };
  window.__frame = () => document.getElementById('scribe-editor');
  window.__fdoc = () => window.__frame() && window.__frame().contentDocument;
  true`;

async function theEditorOpen(page, lang) {
  const { js, until } = page;
  check(await until(`!!document.querySelector('flutter-view, flt-glass-pane')`), `${lang}: Z's page stands`);
  await js(helpers);
  await until(`window.__sem(document) > 0`);
  const scribeButton = { en: 'Scribe: a text editor', ar: 'Scribe: محرر نصوص', sv: 'Scribe: en textredigerare' }[lang];
  check(await until(`window.__press(document, ${JSON.stringify(scribeButton)})`, 20000), `${lang}: the Scribe button is pressed by its words`);
  check(await until(`!!window.__frame()`), `${lang}: Scribe's frame stands over the page`);
  check(await js(`new URL(window.__frame().src).pathname`) === `/${lang}/try/scribe/`, `${lang}: at /${lang}/try/scribe/`);
  check(await until(`!!(window.__fdoc() && window.__fdoc().querySelector('flutter-view, flt-glass-pane'))`), `${lang}: the editor's page stands in it`);
  await until(`window.__sem(window.__fdoc()) > 0`);
  check(await until(`/Keyboard|لوحة المفاتيح|Tangentbord/.test(window.__words(window.__fdoc()))`), `${lang}: the editor shows its report`);
}

async function type(page, text) {
  const { s, js } = page;
  // The middle of the sheet, wherever the frame stands (beside Z or over it).
  const box = await js(`(() => { const r = window.__frame().getBoundingClientRect(); return [r.left, r.width, r.height]; })()`);
  const x = box[0] + box[1] / 2;
  const y = Math.min(box[2] * 0.45, 420);
  await s('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await s('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  await sleep(600);
  await s('Input.insertText', { text });
  await sleep(800);
}

const post = (type, text) =>
  `window.__frame().contentWindow.postMessage({type: ${JSON.stringify(type)}, text: ${JSON.stringify(text)}}, location.origin)`;

// ---------------------------------------------------------------- the flow
{
  const page = await openPage(`${base}/en/try/`, 1440, 900);
  const { js, until } = page;
  await theEditorOpen(page, 'en');
  // Rule 88 (ط): at 1440 px the editor stands beside Z, in two thirds of the
  // width on the end side — the right in English.
  const rect = await js(`(() => { const r = window.__frame().getBoundingClientRect(); return [r.left, r.width, r.height]; })()`);
  check(Math.abs(rect[0] - 480) <= 1 && Math.abs(rect[1] - 960) <= 1 && rect[2] === 900,
    `the editor stands beside Z, in the right two thirds: x ${rect[0]}, ${rect[1]} × ${rect[2]} px`);

  await type(page, 'three typed words');
  check(await until(`/3 words \\(100%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    'typed words count as the keyboard\'s: 3 words (100%)');

  await js(post('scribe-insert', 'An answer from AI.'));
  // 4 and 3 of 7 words: 57.1 and 42.9, no tie in the remainders.
  check(await until(`/4 words \\(57%\\)/.test(window.__words(window.__fdoc())) &&
      /3 words \\(43%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    '«Send to the editor» counts as AI: 4 words (57%), keyboard 3 (43%)');

  // A paste (88 (د)). The frame's clipboard is a stub in the page's memory —
  // `navigator.clipboard.readText` answers the fixture — so no test reads or
  // writes the machine's clipboard; Ctrl+V is the browser's own key.
  const paste = async (text) => {
    await js(`Object.defineProperty(window.__fdoc().defaultView.navigator.clipboard, 'readText',
      {value: async () => ${JSON.stringify(text)}, configurable: true}); true`);
    await page.s('Input.insertText', { text: ' ' });
    const control = { key: 'Control', code: 'ControlLeft', windowsVirtualKeyCode: 17, nativeVirtualKeyCode: 17 };
    const v = { key: 'v', code: 'KeyV', windowsVirtualKeyCode: 86, nativeVirtualKeyCode: 86 };
    await page.s('Input.dispatchKeyEvent', { type: 'rawKeyDown', modifiers: 2, ...control });
    await page.s('Input.dispatchKeyEvent', { type: 'rawKeyDown', modifiers: 2, ...v });
    await page.s('Input.dispatchKeyEvent', { type: 'keyUp', modifiers: 2, ...v });
    await page.s('Input.dispatchKeyEvent', { type: 'keyUp', modifiers: 0, ...control });
    await sleep(800);
  };
  // Z's copy, as Z's page hands it over (`scribe-z-copy`), then pasted:
  // 8 of 11 words are AI's, 72.7 → 73 % and 27.3 → 27 %.
  // The editor writes Z's copy to the clipboard too: in this test, to the
  // stub's memory, never the machine's.
  await js(`Object.defineProperty(window.__fdoc().defaultView.navigator.clipboard, 'writeText',
    {value: async (t) => { window.__written = t; }, configurable: true}); true`);
  await js(post('scribe-z-copy', 'Copied from Z here.'));
  await sleep(300);
  await paste('Copied from Z here.');
  check(await until(`/8 words \\(73%\\)/.test(window.__words(window.__fdoc())) &&
      /3 words \\(27%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    'a paste of Z\'s copy counts as AI: 8 words (73%), keyboard 3 (27%)');
  // The control: other text, pasted, is Paste. 8, 3 and 2 of 13 words:
  // 61.5, 23.1 and 15.4 → 62, 23 and 15 by the largest remainder.
  await paste('Other words.');
  check(await until(`/8 words \\(62%\\)/.test(window.__words(window.__fdoc())) &&
      /3 words \\(23%\\)/.test(window.__words(window.__fdoc())) &&
      /2 words \\(15%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    'the control: any other paste counts as Paste: 2 words (15%); AI 8 (62%), keyboard 3 (23%)');

  // **The browser's own paste** — its menu, a long press on a phone — comes
  // with no Ctrl+V key: a trusted \`paste\` event, which once went into the
  // hidden text field and was counted as Keyboard (pinned red against the
  // editor before the fix). It must go by the paste door: Z's copy is AI,
  // other text Paste. The text is put on Chrome's own clipboard — in memory,
  // Chrome is started with no display — and the edit command pastes it.
  await send('Browser.grantPermissions', { origin: base,
    permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'] });
  const nativePaste = async (text) => {
    await js(`(() => { const w = window.__fdoc().defaultView;
      return w.Clipboard.prototype.writeText.call(w.navigator.clipboard, ${JSON.stringify(text)}); })()`);
    await page.s('Input.insertText', { text: ' ' });
    await page.s('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'F24', code: 'F24',
      windowsVirtualKeyCode: 135, commands: ['paste'] });
    await page.s('Input.dispatchKeyEvent', { type: 'keyUp', key: 'F24', code: 'F24', windowsVirtualKeyCode: 135 });
    await sleep(800);
  };
  const report = () => js(`(window.__words(window.__fdoc()).match(/\\d+ words \\(\\d+%\\)/g) || []).join(' · ')`);
  // Z's copy again: 12, 3 and 2 of 17 words → 70, 18 and 12 %.
  await nativePaste('Copied from Z here.');
  check(await until(`/12 words \\(70%\\)/.test(window.__words(window.__fdoc())) &&
      /3 words \\(18%\\)/.test(window.__words(window.__fdoc())) &&
      /2 words \\(12%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    `the browser's own paste of Z's copy counts as AI, not Keyboard: 12 words (70%), keyboard 3 (18%), paste 2 (12%) — ${await report()}`);
  // Other text: 12, 3 and 4 of 19 → 63, 16 and 21 %.
  await nativePaste('Other native.');
  check(await until(`/12 words \\(63%\\)/.test(window.__words(window.__fdoc())) &&
      /3 words \\(16%\\)/.test(window.__words(window.__fdoc())) &&
      /4 words \\(21%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    `the browser's own paste of other text counts as Paste, once: 4 words (21%) — ${await report()}`);
  // The control: typing is still the keyboard's. 12, 5 and 4 of 21 → 57, 24, 19.
  await page.s('Input.insertText', { text: ' two more' });
  await sleep(800);
  check(await until(`/12 words \\(57%\\)/.test(window.__words(window.__fdoc())) &&
      /5 words \\(24%\\)/.test(window.__words(window.__fdoc())) &&
      /4 words \\(19%\\)/.test(window.__words(window.__fdoc()))`, 8000),
    `the control: typed words still count as Keyboard: 5 words (24%) — ${await report()}`);

  // No save and no print (88 (و)): no control the visitor could press says so.
  const controls = await js(`[...window.__fdoc().querySelectorAll('[role="button"], [role="menuitem"], flt-semantics[flt-tappable]')]
    .map((e) => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).join('\\n')`);
  check(controls.length > 0 && !/\b(save|print|export|download)\b/i.test(controls),
    'no save, print, export or download control in the editor');

  // One CanvasKit, at one absolute address, for both pages (paper 124).
  const canvaskit = await js(`[document, window.__fdoc()].map((d) => d.defaultView.performance
    .getEntriesByType('resource').map((e) => new URL(e.name).pathname)
    .filter((p) => /canvaskit[.]wasm$/.test(p)).join(' '))`);
  check(canvaskit.every((p) => /^\/try\/canvaskit\//.test(p)) && canvaskit.join(' ').includes('/try/canvaskit/'),
    `both pages load CanvasKit from /try/canvaskit/ (${canvaskit.map((p) => p || 'none').join('; ')})`);

  check(await js(`window.__press(window.__fdoc(), '^Close$')`), '«Close» is pressed');
  check(await until(`window.__frame().style.display === 'none'`, 5000), '«Close» hides the frame');
  check(await until(`window.__press(document, 'Scribe: a text editor')`, 5000), 'the Scribe button again');
  check(await until(`window.__frame().style.display === 'block'`, 5000) &&
    await until(`/12 words \\(57%\\)/.test(window.__words(window.__fdoc()))`, 5000),
    '…opens the same editor, its words kept');

  // Close it, then «Start over»: with no document Z erases at once.
  await js(`window.__press(window.__fdoc(), '^Close$')`);
  await until(`window.__frame().style.display === 'none'`, 5000);
  check(await until(`window.__press(document, 'Start over')`, 5000), '«Start over» is pressed');
  check(await until(`!window.__frame()`, 5000), '«Start over» takes the frame out of the page');

  const kept = await js(`(async () => {
    const out = [];
    if (localStorage.length) out.push('localStorage');
    if (sessionStorage.length) out.push('sessionStorage');
    if (document.cookie) out.push('cookies');
    if ((await indexedDB.databases()).length) out.push('IndexedDB');
    if ((await caches.keys()).length) out.push('Cache Storage');
    if ((await navigator.serviceWorker.getRegistrations()).length) out.push('service workers');
    return out.join(', ');
  })()`);
  check(kept === '', `the browser keeps nothing after the editor's flow${kept ? ': ' + kept : ''}`);
  await send('Target.closeTarget', { targetId: page.targetId });
}
// **«Copy the answer to the editor»** (rule 88 (ط)), on a page of its own:
// disabled before an answer; after a real turn — a text typed, «Copy
// Protected», an answer pasted and added, all by the real module — it sends
// the answer into the editor, which opens beside Z, and counts it as AI. In
// Arabic, so the editor stands on the left.
{
  await send('Browser.grantPermissions', { origin: base,
    permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'] });
  const page = await openPage(`${base}/ar/try/`, 1440, 900);
  const { s, js, until } = page;
  await until(`!!document.querySelector('flutter-view, flt-glass-pane')`);
  await js(helpers);
  await until(`window.__sem(document) > 0`);
  const label = 'انسخ الجواب إلى المحرر';
  const state = (re) => js(`(() => { const b = [...document.querySelectorAll('flt-semantics[role="button"]')]
    .find((e) => new RegExp(${JSON.stringify(re)}).test(e.textContent || '')); return b ? String(b.getAttribute('aria-disabled')) : 'none'; })()`);
  check(await until(`!!document.querySelectorAll('textarea').length`, 10000) && await state(label) === 'true',
    '«Copy the answer to the editor» is there, and disabled before an answer');
  // A box by its own words (its hint, as the page names it), or the first.
  const typeInto = async (hint, text) => {
    const at = await js(`(() => { const all = [...document.querySelectorAll('textarea')];
      const box = ${JSON.stringify(hint)} ? all.find((e) => (e.getAttribute('aria-label') || '').startsWith(${JSON.stringify(hint)})) : all[0];
      const r = box.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; })()`);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await s('Input.dispatchMouseEvent', { type, x: at[0], y: at[1], button: 'left', clickCount: 1 });
    }
    await sleep(500);
    await s('Input.insertText', { text });
    await sleep(800);
  };
  await typeInto('', 'Dear Anna Lindqvist, Björn wrote to anna@example.org about the contract.');
  check(await until(`window.__press(document, ${JSON.stringify('نسخ النص المحمي')})`, 15000), '«Copy Protected» is pressed');
  await sleep(800);
  await typeInto('ألصِق الجواب', 'The boats are in the harbour.');
  check(await until(`window.__press(document, ${JSON.stringify('^أضِف جواباً$')})`, 10000), '«Add an answer» is pressed');
  check(await until(`(() => { const b = [...document.querySelectorAll('flt-semantics[role="button"]')]
      .find((e) => /${label}/.test(e.textContent || '')); return b && b.getAttribute('aria-disabled') !== 'true'; })()`, 10000),
    '…and «Copy the answer to the editor» is enabled');
  check(await until(`window.__press(document, ${JSON.stringify(label)})`, 5000), '«Copy the answer to the editor» is pressed');
  check(await until(`!!window.__frame()`), 'the editor opens');
  await until(`!!(window.__fdoc() && window.__fdoc().querySelector('flutter-view, flt-glass-pane'))`);
  await until(`window.__sem(window.__fdoc()) > 0`);
  const rect = await js(`(() => { const r = window.__frame().getBoundingClientRect(); return [r.left, r.width]; })()`);
  check(Math.abs(rect[0]) <= 1 && Math.abs(rect[1] - 960) <= 1,
    `in Arabic the editor stands on the left two thirds, Z on the right: x ${rect[0]}, ${rect[1]} px`);
  check(await until(`/6 كلمات \\(100\\u200e?%/.test(window.__words(window.__fdoc()))`, 10000),
    `the answer arrives counted as AI: 6 words, 100 % — ${(await js(`window.__words(window.__fdoc())`)).match(/\d+ كلمات[^\n]*|[^\n]*كلمات[^\n]*/g)?.slice(0, 3).join(' · ')}`);
  await send('Target.closeTarget', { targetId: page.targetId });
}

check(violations.length === 0, `no Content-Security-Policy violation in either page${violations.length ? ': ' + violations[0] : ''}`);

// The control: the editor in a page of another origin is refused.
{
  const page = await openPage('about:blank', 800, 600);
  await page.js(`(() => { const f = document.createElement('iframe');
    f.src = ${JSON.stringify(base + '/en/try/scribe/')}; document.body.appendChild(f); return true; })()`);
  let refused = false;
  for (let t = 0; t < 10000 && !refused; t += 250) {
    refused = violations.some((v) => /frame-ancestors/.test(v));
    await sleep(250);
  }
  check(refused, 'the control: a page of another origin may not hold the editor (frame-ancestors \'self\')');
  violations.length = 0;
  await send('Target.closeTarget', { targetId: page.targetId });
}

// ---------------------------------------------------------------- the shots
if (shots) {
  const lines = {
    en: ['I wrote these words by hand. ', 'This paragraph is the answer AI gave, sent from Z.'],
    ar: ['كتبت هذه الكلمات بيدي. ', 'هذه الفقرة جواب الذكاء الاصطناعي، أرسلت من Z.'],
    sv: ['Jag skrev de här orden själv. ', 'Det här stycket är svaret som AI gav, skickat från Z.'],
  };
  for (const lang of ['en', 'ar', 'sv']) {
    for (const [w, h] of [[390, 844], [1440, 900]]) {
      const page = await openPage(`${base}/${lang}/try/`, w, h);
      await theEditorOpen(page, lang);
      await type(page, lines[lang][0]);
      await page.js(post('scribe-insert', lines[lang][1]));
      await sleep(1500);
      const shot = await page.s('Page.captureScreenshot', { format: 'png' });
      writeFileSync(`${shots}/scribe-${lang}-${w}.png`, Buffer.from(shot.result.data, 'base64'));
      ok(`shot scribe-${lang}-${w}.png`);
      await send('Target.closeTarget', { targetId: page.targetId });
    }
  }
}

ws.close();
process.exit(failed ? 1 : 0);
