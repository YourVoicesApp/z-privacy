// **The chat's parity** — paper 123 §2.5.
//
//     node bridges/web/tests/chat_parity.mjs <web-core-dir> <parity_replay binary> [work-dir]
//
// For each of the six languages' fixtures, a three-turn chat is run through
// the **browser build**: the document copied and answered (turn one, 122's
// doors), then two questions, each copied with `z_question_to_take_out` and
// answered against its handle; the thread read with `z_turns`; the chat ended;
// and «Start over» (`z_close`). Every call is written down, and the native
// replay sends the same requests through the same doors built against the
// **native** core — with a vault in a temporary folder (`--vault`), because
// the app keeps a chat nowhere else — and what each side **hands out** must be
// the same: every take-out text, every turn (as it left, as it arrived, and
// restored), every restored answer, every refusal.
//
// Marks are compared by `parity.mjs`; this one compares what is handed out. Tokens are named by the order they first
// appear on each side (⟪T1⟫, …), so a token that moves is still refused.
//
// Checks on the web side as well: turn two carries the exchange before it and
// no protected value in the clear; every answer restores the chat's names; each
// turn keeps its question; after `z_close` the session is refused by name and
// its codes do not restore on the next bench.
//
// Exit status is the verdict. Fixtures only.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const [webDir, replayBin, workArg] = process.argv.slice(2);
if (!webDir || !replayBin) {
  console.error('usage: chat_parity.mjs <web-core-dir> <parity_replay binary> [work-dir]');
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const work = workArg ?? fs.mkdtempSync(path.join(os.tmpdir(), 'z-chat-parity-'));

const z = await import(pathToFileURL(path.resolve(webDir, 'z_web.js')).href);
await z.default({ module_or_path: fs.readFileSync(path.resolve(webDir, 'z_web_bg.wasm')) });

// Two questions per language, each naming a value the document protected.
const LANGUAGES = [
  ['en', 'maren.holt@example.com', ['What does maren.holt@example.com need from us?', 'Draft a reply to maren.holt@example.com and Ilse Carrow.']],
  ['ar', 'lina.haddad@example.com', ['ماذا تريد lina.haddad@example.com منا؟', 'اكتب رداً إلى lina.haddad@example.com.']],
  ['de', 'jana.weidlich@example.com', ['Was braucht jana.weidlich@example.com von uns?', 'Schreiben Sie an jana.weidlich@example.com und Tilman Osterkamp.']],
  ['fr', 'lucie.marchetti@example.com', ['Que veut lucie.marchetti@example.com ?', 'Écrivez à lucie.marchetti@example.com.']],
  ['es', 'ines.arriaga@example.com', ['¿Qué necesita ines.arriaga@example.com?', 'Escriba a ines.arriaga@example.com.']],
  ['sv', 'malin.oberg@example.com', ['Vad vill malin.oberg@example.com ha?', 'Skriv till malin.oberg@example.com och Astrid Wennerholm.']],
];

const transcript = [];
const problems = [];
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

const summary = [];
let oldCodes = null;
for (const [lang, value, questions] of LANGUAGES) {
  const text = fs.readFileSync(path.join(here, 'fixtures', `${lang}.txt`), 'utf8');
  // Each language's chat begins on an empty vault on the native side, as the
  // web begins with nothing (see the replay).
  transcript.push({ door: '__fresh_vault', request: '{}', response: '{"ok":{}}' });
  const session = ok(lang, 'open', call('z_open', { pack: lang }))?.session;
  if (session === undefined) continue;
  const view = ok(lang, 'import', call('z_import_text', { session, text }))?.view;
  if (!view) continue;
  for (let guard = 0; guard < 64; guard++) {
    const scanCall = transcript.length;
    const m = (call('z_scan', { session }).ok?.view.marks ?? []).find((x) => x.state === 'suggested');
    if (!m) break;
    // The replay answers the mark at this place in its own numbering.
    const before = transcript.length;
    const a = ok(lang, 'answer', call('z_answer_finding', { session, finding: m.finding, answer: 'protect' }));
    transcript[before].finding = { call: scanCall, start: m.start, end: m.end };
    if (!a) break;
  }
  // The codes of the language before, pasted into this bench after Start over.
  if (oldCodes) {
    const oldBuild = transcript.length;
    const payload = ok(lang, 'build for the old codes', call('z_build_payload', { session }))?.payload;
    const prefix = 'Old codes: ';
    const a = ok(lang, 'ingest the old codes', call('z_ingest_answer', { payload, text: prefix + oldCodes.text }, { call: oldCodes.call, prefix, payload: oldBuild }))?.answer;
    const r = ok(lang, 'restore the old codes', call('z_restored_view', { session, answer: a }));
    expect(lang, 'the codes of a closed session restored on the next bench', r && !r.segments.some((s) => s.piece === 'restored'));
    // That paste was a turn of this chat; the chat measured below starts after it.
    ok(lang, 'end the old codes\' chat', call('z_end_the_chat', { session }));
  }

  // Turn one: the document, as 122 built it.
  const firstCall = transcript.length;
  const first = ok(lang, 'take out', call('z_payload_to_take_out', { session }));
  const buildCall = transcript.length;
  const payload = ok(lang, 'build', call('z_build_payload', { session }))?.payload;
  if (!first || !payload) continue;
  expect(lang, 'the value left in the clear at turn one', !first.text.includes(value));
  ok(lang, 'ingest 1', call('z_ingest_answer', { payload, text: `Answer one:\n${first.text}` }, { call: firstCall, prefix: 'Answer one:\n', payload: buildCall }));

  // Turns two and three: the question, its take-out, the answer against it.
  let lastAnswer = null;
  for (const [i, q] of questions.entries()) {
    const set = ok(lang, `set question ${i + 2}`, call('z_set_question', { session, text: q }));
    expect(lang, `question ${i + 2} left the value in the clear`, set && !set.text.includes(value));
    const outCall = transcript.length;
    const out = ok(lang, `take out ${i + 2}`, call('z_question_to_take_out', { session }));
    if (!out) continue;
    expect(lang, `take-out ${i + 2} carries the exchange before it`, out.text.startsWith('--- Earlier request ---'));
    expect(lang, `take-out ${i + 2} carries the value in the clear`, !out.text.includes(value));
    const prefix = `Answer ${i + 2}:\n`;
    lastAnswer = ok(lang, `ingest ${i + 2}`, call('z_ingest_answer', { payload: out.payload, text: prefix + out.text }, { call: outCall, prefix, payload: outCall }))?.answer;
  }
  const restored = ok(lang, 'restore', call('z_restored_view', { session, answer: lastAnswer }));
  expect(lang, 'the last answer restores the value', restored && restored.text.includes(value));
  const thread = ok(lang, 'turns', call('z_turns', { session }));
  expect(lang, 'three turns in the open chat', thread && thread.turns.filter((t) => t.chat === thread.chat).length === 3);
  expect(lang, 'every turn keeps its question', thread && thread.turns.every((t) => t.question_as_it_left.trim().length > 0));
  expect(lang, 'the thread is coded and the restored side is not', thread && thread.turns.every((t) => !t.answer_as_written.includes(value)) && thread.turns.some((t) => t.answer.text.includes(value)));
  const ended = ok(lang, 'end the chat', call('z_end_the_chat', { session }));
  const after = ok(lang, 'turns after the end', call('z_turns', { session }));
  expect(lang, 'the ended chat is not the open one', ended && after && after.chat === ended.chat && after.turns.every((t) => t.chat !== after.chat));

  oldCodes = { text: first.text, call: firstCall };
  ok(lang, 'close', call('z_close', { session }));
  const refused = call('z_turns', { session });
  expect(lang, 'a closed session is refused by name', refused.error === 'invalid_session');
  expect(lang, 'a closed session cannot be closed twice', call('z_close', { session }).error === 'invalid_session');
  summary.push(`${lang}: ${thread?.turns.length ?? 0} turns, take-outs ${questions.length}, restored «${value}»`);
}

// ------------------------------------------------------------- the replay
const vault = fs.mkdtempSync(path.join(work, 'vaults-'));
const file = path.join(work, 'chat-transcript.jsonl');
fs.writeFileSync(file, transcript.map((t) => JSON.stringify(t)).join('\n') + '\n');
const run = spawnSync(replayBin, ['--vault', vault, file], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
fs.rmSync(vault, { recursive: true, force: true });
if (run.status !== 0) {
  console.error(`the native replay failed (${run.status}): ${run.stderr} (transcript kept at ${file})`);
  process.exit(1);
}
// kept for a failing run: fs.rmSync below
if (process.env.Z_KEEP_TRANSCRIPT !== "1") fs.rmSync(file, { force: true });
const native = run.stdout.split('\n').filter((l) => l.trim()).map((l) => JSON.parse(l));
if (native.length !== transcript.length) problems.push(`the native replay answered ${native.length} calls of ${transcript.length}`);

// What each door hands out, compared; tokens named by first appearance.
const TOKEN = /__Z_[0-9A-Za-z]+_[A-Z0-9]+_[0-9A-Za-z]+__/g;
function namer() {
  const names = new Map();
  return (s) => s.replace(TOKEN, (t) => {
    if (!names.has(t)) names.set(t, `⟪T${names.size + 1}⟫`);
    return names.get(t);
  });
}
function handedOut(door, response) {
  const r = JSON.parse(response);
  if (r.error !== undefined) return JSON.stringify(r);
  const o = r.ok;
  switch (door) {
    case 'z_payload_to_take_out':
    case 'z_question_to_take_out':
    case 'z_restored_view':
      return o.text;
    case 'z_set_question':
      return o.text;
    case 'z_turns':
      return JSON.stringify({ chat: o.chat, turns: o.turns.map((t) => [t.chat, t.question_as_it_left, t.answer_as_written, t.question.text, t.answer.text]) });
    case 'z_end_the_chat':
    case 'z_close':
      return JSON.stringify(o);
    default:
      return 'ok';
  }
}
// **The blocks are the app's** — paper 123, the lead's ruling of 14 November:
// the web does what native-with-a-vault does. The es letter was where they
// parted: «Valdecasas» protected at «la señora Valdecasas confirmará» left in
// the clear at the letter's opening, which only a block protects. Pinned
// first as the clear text (green before the trial had blocks, red after), and
// now the other way round.
const esOut = transcript.find((t) => t.door === 'z_payload_to_take_out' && t.response.includes('Estimada señora'));
if (!esOut || JSON.parse(esOut.response).ok?.text.includes('Valdecasas')) {
  problems.push('the es letter sent «Valdecasas» in the clear beside its own token');
}

function compare(web, nat) {
  const w = namer();
  const n = namer();
  const differ = [];
  let same = 0;
  for (let i = 0; i < Math.min(web.length, nat.length); i++) {
    const a = w(handedOut(web[i].door, web[i].response));
    const b = n(handedOut(nat[i].door, nat[i].response));
    if (nat[i].door !== web[i].door) differ.push(`call ${i}: ${nat[i].door} for ${web[i].door}`);
    else if (a !== b) differ.push(`call ${i} (${web[i].door}): web and native differ`);
    else same++;
  }
  return { same, differ };
}
const { same, differ } = compare(transcript, native);
problems.push(...differ);

// **The control**: one native take-out with its history cut off must be seen.
const at = native.findIndex((n) => n.door === 'z_question_to_take_out' && n.response.includes('"ok"'));
if (at < 0) {
  problems.push('CONTROL: no take-out was answered, so nothing was compared');
} else {
  const r = JSON.parse(native[at].response);
  const cut = r.ok.text.split('\n\n').pop();
  const planted = native.slice();
  planted[at] = { ...native[at], response: JSON.stringify({ ok: { ...r.ok, text: cut } }) };
  if (compare(transcript, planted).differ.length === 0) problems.push('CONTROL: a take-out without its history was not seen');
}

for (const line of summary) console.log(line);
console.log(`chat parity: ${same} of ${transcript.length} calls handed out the same by the web and the native core, over ${LANGUAGES.length} languages`);
if (problems.length > 0) {
  for (const p of problems) console.error(`PROBLEM ${p}`);
  process.exit(1);
}
