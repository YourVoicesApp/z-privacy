// **A protected value is protected at every place, in the trial too** —
// paper 123, the lead's ruling of 14 November (rules 85 and 089).
//
//     node bridges/web/tests/the_blocks.mjs <web-core-dir>
//
// The trial had no blocks, so a value protected at one place left in the clear
// at a place the scan had not marked, beside its own token: the es letter's
// «Estimada señora Valdecasas:». The web now keeps the app's blocks in its own
// memory. Measured here on the browser build:
//
// 1. **the pin, turned**: that opening is protected, with the same token as
//    the place that was answered (it read in the clear before the blocks —
//    `chat_parity.mjs` carried that pin, green then red, then turned);
// 2. **the control**: the value inside a longer word is not protected — whole
//    words only;
// 3. a value answered «leave» is protected nowhere and is not asked again;
// 4. after «Start over», no value of the old session is protected in the next
//    session's text.
//
// Exit status is the verdict. Invented text only.

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: the_blocks.mjs <web-core-dir>');
  process.exit(2);
}
const z = await import(pathToFileURL(path.resolve(dir, 'z_web.js')).href);
await z.default({ module_or_path: fs.readFileSync(path.resolve(dir, 'z_web_bg.wasm')) });
const call = (door, request) => JSON.parse(z[door](JSON.stringify(request)));
const problems = [];
const expect = (what, cond) => { if (!cond) problems.push(what); };

// The es letter's shape: the name opens it unmarked, and is suggested later.
// «Valdecasasero» is an invented longer word holding it.
const LETTER = 'Estimada señora Valdecasas:\n\n' +
  'El taller Valdecasasero cierra el martes. ' +
  'La señora Valdecasas confirmará las fechas con Herrera Ingeniería S.L.\n';

function open(text) {
  const session = call('z_open', { pack: 'es' }).ok.session;
  call('z_import_text', { session, text });
  return session;
}
function suggestedAt(session, word) {
  const v = call('z_scan', { session }).ok.view;
  return v.marks.find((m) => m.state === 'suggested' && v.text.slice(m.start, m.end) === word);
}
function answerAll(session, answer) {
  for (let guard = 0; guard < 64; guard++) {
    const v = call('z_scan', { session }).ok.view;
    const m = v.marks.find((x) => x.state === 'suggested');
    if (!m) return;
    call('z_answer_finding', { session, finding: m.finding, answer: answer(v.text.slice(m.start, m.end)) });
  }
}

// 1 and 2: protect the suggestion, rescan, take out.
{
  const session = open(LETTER);
  const m = suggestedAt(session, 'Valdecasas');
  expect('the fixture does not suggest «Valdecasas», so it measures nothing', m);
  answerAll(session, () => 'protect');
  const out = call('z_payload_to_take_out', { session });
  const text = out.ok?.text ?? '';
  expect(`the take-out was refused: ${JSON.stringify(out.error ?? null)}`, out.ok);
  expect('«Estimada señora Valdecasas:» left in the clear beside its own token', !text.includes('señora Valdecasas'));
  const opening = text.match(/^Estimada señora (__Z_[0-9A-Za-z]+_PERSON_[0-9A-Za-z]+__):/);
  const later = text.match(/La señora (__Z_[0-9A-Za-z]+_PERSON_[0-9A-Za-z]+__) confirmará/);
  expect('the opening is not protected as a person', opening);
  expect('the two places do not wear the same token', opening && later && opening[1] === later[1]);
  expect('CONTROL: «Valdecasasero» was protected — a block works on whole words only', text.includes('Valdecasasero'));
  call('z_close', { session });
}

// 3: «leave» — protected nowhere, and not asked again on a rescan.
{
  const session = open(LETTER);
  answerAll(session, (word) => (word === 'Valdecasas' ? 'leave' : 'protect'));
  const again = suggestedAt(session, 'Valdecasas');
  expect('a value answered «leave» was asked about again', !again);
  const text = call('z_payload_to_take_out', { session }).ok?.text ?? '';
  expect('a value answered «leave» did not stay as written at every place',
    text.includes('Estimada señora Valdecasas:') && text.includes('La señora Valdecasas confirmará'));
  call('z_close', { session });
}

// 4: after «Start over», the old session's values protect nothing new.
{
  const first = open(LETTER);
  answerAll(first, () => 'protect');
  call('z_close', { session: first });
  const NEXT = 'Estimada señora Valdecasas:\n\nGracias por todo.\n';
  const session = open(NEXT);
  const v = call('z_scan', { session }).ok.view;
  const covered = v.marks.filter((m) => v.text.slice(m.start, m.end) === 'Valdecasas' && m.state === 'protected');
  expect('a value of the closed session was protected in the next session\'s text', covered.length === 0);
  call('z_close', { session });
  // The control of this one: the same text in the same session *is* covered.
  const same = open(LETTER);
  answerAll(same, () => 'protect');
  const w = call('z_scan', { session: same }).ok.view;
  expect('CONTROL: the opening is not protected even within its own session',
    w.marks.some((m) => m.state === 'protected' && m.start === 'Estimada señora '.length));
  call('z_close', { session: same });
}

if (problems.length > 0) {
  for (const p of problems) console.error(`PROBLEM ${p}`);
  process.exit(1);
}
console.log('blocks: a protected value is protected at every whole-word place with one token; inside a longer word it is not (control); «leave» protects nothing; «Start over» carries nothing to the next session');
