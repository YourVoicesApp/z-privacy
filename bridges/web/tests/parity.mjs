// **The parity test** — paper 122 §2.4.
//
//     node bridges/web/tests/parity.mjs <web-core-dir> <parity_replay binary> [work-dir]
//
// For each of the six languages' fixtures, the trial's whole flow is run
// through the **browser build** (`z_web.js` + `z_web_bg.wasm`, loaded with the
// same `init` the page calls), and every call is written down as
// `{door, request, response}`. The native replay (`examples/parity_replay.rs`)
// then sends the same requests, in the same order, through the same doors
// built against the **native** core — since paper 123 the app's own, with a
// vault in a temporary folder, because the trial keeps the app's blocks in its
// memory and is measured against the app — and every answer must be the same:
// findings, marks, protected text, restored text, refusals.
//
// Tokens are the one thing allowed to differ, and only in their letters: each
// session draws its own at random, on both sides. So a token is named by the
// order it first appears in (⟪T1⟫, ⟪T2⟫, …) before the two are compared, which
// still refuses a token that stands in a different place.
//
// The flow, per language: open → import → scan → a hand protection, once,
// taken back, then for the conversation → the pin (below) → every suggestion
// answered, the first with «leave» and the rest with «protect» → the two
// `not_on_web` refusals → take out → build → paste an answer back → restore.
//
// **The pin**: `z_protect` on a suggested mark protects the place but does not
// answer the suggestion, so the payload stays blocked by it. Measured and
// pinned here, so that the day it changes this test says so; the screen's
// suggestion buttons call `z_answer_finding`.
//
// Exit status is the verdict. Fixtures only; nothing is read but this folder.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const [webDir, replayBin, workArg] = process.argv.slice(2);
if (!webDir || !replayBin) {
  console.error('usage: parity.mjs <web-core-dir> <parity_replay binary> [work-dir]');
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const work = workArg ?? fs.mkdtempSync(path.join(os.tmpdir(), 'z-parity-'));

const z = await import(pathToFileURL(path.resolve(webDir, 'z_web.js')).href);
await z.default({ module_or_path: fs.readFileSync(path.resolve(webDir, 'z_web_bg.wasm')) });

// One word per language that no layer marks, protected by hand.
const LANGUAGES = [
  ['en', 'Jonas Bergqvist', 'person'],
  ['ar', 'يوسف العمري', 'person'],
  ['de', 'Dienstag', 'custom'],
  ['fr', 'mardi', 'custom'],
  ['es', 'martes', 'custom'],
  ['sv', 'tisdags', 'custom'],
];

const transcript = [];
const problems = [];
// `from`: a request that carries text the core wrote (the pasted answer holds
// the payload's tokens) names the call it was taken from, so that the replay
// takes the same text from its own answer to that call.
function call(door, request, from) {
  const req = JSON.stringify(request);
  const response = z[door](req);
  transcript.push({ door, request: req, response, ...(from ? { from } : {}) });
  return JSON.parse(response);
}
function ok(lang, what, answer) {
  if (!answer || answer.ok === undefined) {
    problems.push(`${lang}: ${what} refused: ${JSON.stringify(answer)}`);
    return null;
  }
  return answer.ok;
}
function expect(lang, what, cond) {
  if (!cond) problems.push(`${lang}: ${what}`);
}
const utf16 = (text, needle) => text.indexOf(needle);

const summary = [];
for (const [lang, handWord, handKind] of LANGUAGES) {
  const text = fs.readFileSync(path.join(here, 'fixtures', `${lang}.txt`), 'utf8');
  // Each language on an empty vault on the native side (see the replay).
  transcript.push({ door: '__fresh_vault', request: '{}', response: '{"ok":{}}' });
  const session = ok(lang, 'open', call('z_open', { pack: lang }))?.session;
  if (session === undefined) continue;
  ok(lang, 'import', call('z_import_text', { session, text }));
  let view = ok(lang, 'scan', call('z_scan', { session }))?.view;
  if (!view) continue;
  const scanned = view.marks.length;

  // A hand protection: once, taken back, then for the conversation.
  const at = utf16(view.text, handWord);
  expect(lang, `the hand word is in the fixture`, at >= 0);
  const hand = { session, start: at, end: at + handWord.length, kind: handKind };
  const once = ok(lang, 'hand protect', call('z_protect', { ...hand, scope: 'once' }));
  expect(lang, 'a hand protection is applied', once && once.outcome.applied);
  const undo = ok(lang, 'unprotect', call('z_unprotect', { session, start: hand.start, end: hand.end }));
  expect(lang, 'a hand protection is taken back', undo && undo.outcome.undone);
  view = ok(lang, 'hand protect again', call('z_protect', { ...hand, scope: 'conversation' }))?.view ?? view;

  // The vault's scopes are refused by name, on both doors.
  const profile = call('z_protect', { ...hand, scope: 'profile' });
  expect(lang, 'scope profile is not_on_web', profile.error === 'not_on_web');

  let suggested = view.marks.filter((m) => m.state === 'suggested');
  const before = call('z_payload_to_take_out', { session });
  expect(lang, 'open suggestions block the payload', suggested.length === 0 || before.error === 'open_suggestions');

  // The pin: z_protect on a suggestion does not answer it.
  if (suggested.length > 0) {
    const last = suggested[suggested.length - 1];
    const always = call('z_answer_finding', { session, finding: last.finding, answer: 'always' });
    expect(lang, 'answer always is not_on_web', always.error === 'not_on_web');
    const p = ok(lang, 'protect on a suggestion', call('z_protect', { session, start: last.start, end: last.end, kind: last.kind, scope: 'conversation' }));
    const still = call('z_payload_to_take_out', { session });
    expect(lang, 'PIN: z_protect on a suggestion leaves it open', still.error === 'open_suggestions' && still.count === before.count);
    ok(lang, 'unprotect the pinned place', call('z_unprotect', { session, start: last.start, end: last.end }));
    view = ok(lang, 'scan after the pin', call('z_scan', { session }))?.view ?? view;
    // Since paper 123 the trial has the app's blocks: the value is still
    // protected at its other place, so a rescan protects this one again (as the
    // app does) or asks again — it never leaves it in the clear.
    expect(lang, 'the pinned place is not left in the clear', view.marks.some((m) => m.start === last.start && m.end === last.end));
    void p;
  }

  // Every suggestion answered: the first is left, the rest are protected.
  let left = null;
  for (let guard = 0; guard < 64; guard++) {
    suggested = view.marks.filter((m) => m.state === 'suggested');
    if (suggested.length === 0) break;
    const m = suggested[0];
    expect(lang, 'a suggested mark carries its finding', Number.isInteger(m.finding));
    const answer = left === null ? 'leave' : 'protect';
    if (left === null) left = view.text.slice(m.start, m.end);
    const a = ok(lang, `answer ${answer}`, call('z_answer_finding', { session, finding: m.finding, answer }));
    if (!a) break;
    view = a.view;
  }
  expect(lang, 'every suggestion is answered', view.marks.every((m) => m.state !== 'suggested'));

  const outCall = transcript.length;
  const out = ok(lang, 'take out', call('z_payload_to_take_out', { session }));
  if (!out) continue;
  expect(lang, 'no suggestion is open', out.open_suggestions === 0);
  if (left !== null) {
    expect(lang, `the left value stays in the payload as written`, out.text.includes(left));
  }
  expect(lang, `the hand word is not in the payload`, !out.text.includes(handWord));
  const payload = ok(lang, 'build', call('z_build_payload', { session }))?.payload;
  if (!payload) continue;
  const prefix = 'Answer:\n';
  const answerId = ok(lang, 'ingest', call('z_ingest_answer', { payload, text: prefix + out.text }, { call: outCall, prefix }))?.answer;
  const restored = ok(lang, 'restore', call('z_restored_view', { session, answer: answerId }));
  if (!restored) continue;
  expect(lang, 'the restored answer is the document, with every value back', restored.text === `Answer:\n${view.text}`);
  expect(lang, 'something was restored', restored.segments.some((s) => s.piece === 'restored'));
  summary.push(`${lang}: ${scanned} marks after the scan, ${out.protected_count} protected, left «${left ?? '-'}»`);
  // Each language is its own trial: «Start over» before the next.
  ok(lang, 'close', call('z_close', { session }));
}

// ------------------------------------------------------------- the replay
const file = path.join(work, 'transcript.jsonl');
fs.writeFileSync(file, transcript.map((t) => JSON.stringify(t)).join('\n') + '\n');
// **Against the app, vault and all** — paper 123: the trial keeps its blocks
// in memory as the app keeps them in its vault, so the native side it is
// measured against is the app's own, with a vault in a temporary folder.
const vaults = fs.mkdtempSync(path.join(work, 'vaults-'));
const run = spawnSync(replayBin, ['--vault', vaults, file], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
fs.rmSync(vaults, { recursive: true, force: true });
if (run.status !== 0) {
  console.error(`the native replay failed (${run.status}): ${run.stderr}`);
  process.exit(1);
}
const native = run.stdout.split('\n').filter((l) => l.trim()).map((l) => JSON.parse(l));
if (native.length !== transcript.length) {
  problems.push(`the native replay answered ${native.length} calls of ${transcript.length}`);
}

// Tokens by their order of first appearance, each side on its own.
function namer() {
  const names = new Map();
  const visit = (v) => {
    if (Array.isArray(v)) v.forEach(visit);
    else if (v && typeof v === 'object') {
      for (const [k, x] of Object.entries(v)) {
        if (k === 'token' && typeof x === 'string' && !names.has(x)) names.set(x, `⟪T${names.size + 1}⟫`);
        else if (k === 'tokens' && Array.isArray(x)) x.forEach((t) => { if (!names.has(t)) names.set(t, `⟪T${names.size + 1}⟫`); });
        else visit(x);
      }
    }
  };
  return (response) => {
    visit(JSON.parse(response));
    let s = response;
    // Longest first, so that no token is replaced inside another.
    for (const [t, n] of [...names].sort((a, b) => b[0].length - a[0].length)) s = s.split(t).join(n);
    return s;
  };
}
function compare(web, nat) {
  const webName = namer();
  const nativeName = namer();
  const differ = [];
  let same = 0;
  for (let i = 0; i < Math.min(web.length, nat.length); i++) {
    const w = webName(web[i].response);
    const n = nativeName(nat[i].response);
    if (nat[i].door !== web[i].door) differ.push(`call ${i}: the replay answered ${nat[i].door} for ${web[i].door}`);
    else if (w !== n) differ.push(`call ${i} (${web[i].door}): web and native differ`);
    else same++;
  }
  return { same, differ };
}
const { same, differ } = compare(transcript, native);
problems.push(...differ);

// **The comparison must be able to fail**: two tokens trade places in one
// native payload, and nothing else changes. Naming the tokens may not hide it.
const outs = native.map((n, i) => [n, i]).filter(([n]) => n.door === 'z_payload_to_take_out' && n.response.includes('"ok"'));
let bit = false;
for (const [n, i] of outs) {
  const tokens = [...new Set(n.response.match(/__Z_[0-9A-Za-z_]+?__/g) ?? [])];
  if (tokens.length < 2) continue;
  const swapped = n.response.split(tokens[0]).map((piece) => piece.split(tokens[1]).join('\u0000')).join(tokens[1]).split('\u0000').join(tokens[0]);
  const planted = native.slice();
  planted[i] = { ...n, response: swapped };
  bit = compare(transcript, planted).differ.length > 0;
  break;
}
if (!bit) problems.push('CONTROL: two tokens trading places in a payload were not seen');
for (const line of summary) console.log(line);
console.log(`parity: ${same} of ${transcript.length} calls answered the same by the web and the native core, over ${LANGUAGES.length} languages`);
if (problems.length > 0) {
  for (const p of problems) console.error(`PROBLEM ${p}`);
  process.exit(1);
}
