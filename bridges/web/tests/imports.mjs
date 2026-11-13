// **What the browser module may ask of the page** — paper 122, gate G1g.
//
//     node bridges/web/tests/imports.mjs <web-core-dir>
//
// Two readings, both by name:
//
// 1. The `.wasm` itself: every import it declares. wasm-bindgen names each one
//    `__wbg_<what>_<hash>`; the hash is dropped and the rest must be on the
//    list below. Nothing else can reach the page from inside the module.
// 2. The glue (`z_web.js`): the import object that answers those imports may
//    touch only the two clocks and the browser's randomness, and the whole
//    file may name none of the network or storage doors. Its one `fetch` is
//    the page loading this module from its own address.
//
// Then the controls: a module that imports `fetch`, and a glue that answers an
// import with one, are built here and must both be refused. A gate that cannot
// refuse what it is for is not a gate.
//
// Exit status is the verdict.

import fs from 'node:fs';
import path from 'node:path';

const ALLOWED = new Map([
  ['__wbg_now', 'a clock: performance.now (durations) or Date.now (the wall)'],
  ['__wbg_getRandomValues', "the browser's randomness, for getrandom's wasm_js"],
  ['__wbg___wbindgen_throw', "wasm-bindgen's own glue: a Rust error raised as a JS one"],
  ['__wbindgen_init_externref_table', "wasm-bindgen's own glue: its reference table"],
]);
const MODULE = './z_web_bg.js';
// What the import object may call, and nothing else of the page's.
const PAGE_CALLS = ['Date.now()', 'performance.now()', 'globalThis.crypto.getRandomValues('];
const NEVER = /\b(fetch|XMLHttpRequest|WebSocket|EventSource|sendBeacon|RTCPeerConnection|eval|Function|importScripts|Worker|SharedWorker|localStorage|sessionStorage|indexedDB|caches|cookie|navigator|postMessage|open)\b/g;

function moduleProblems(bytes) {
  const problems = [];
  let imports;
  try {
    imports = WebAssembly.Module.imports(new WebAssembly.Module(bytes));
  } catch (e) {
    return [`the module does not compile: ${e.message}`];
  }
  for (const i of imports) {
    const name = i.name.replace(/_[0-9a-f]{16}$/, '');
    if (i.module !== MODULE) problems.push(`import from ${i.module}: ${i.name}`);
    else if (!ALLOWED.has(name)) problems.push(`import not on the list: ${i.name}`);
  }
  return problems;
}

function glueProblems(js) {
  const problems = [];
  const start = js.indexOf('function __wbg_get_imports() {');
  const end = start < 0 ? -1 : js.indexOf('\n}\n', start);
  if (start < 0 || end < 0) return ['no import object in the glue'];
  const body = js.slice(start, end);
  // Every reference to the page from the import object is one of the three.
  let rest = body;
  for (const c of PAGE_CALLS) rest = rest.split(c).join('');
  for (const m of rest.matchAll(/\b(globalThis|window|self|document|Date|performance|crypto)\b[.\[]/g)) {
    problems.push(`the import object reaches the page: ${m[0]}`);
  }
  for (const m of body.matchAll(NEVER)) problems.push(`the import object names ${m[0]}`);
  // The whole file: one fetch, the module loading itself, and nothing else.
  const outside = js.slice(0, start) + js.slice(end);
  const fetches = outside.match(/\bfetch\(/g) ?? [];
  if (fetches.length !== 1 || !outside.includes('module_or_path = fetch(module_or_path);')) {
    problems.push(`the glue fetches ${fetches.length} time(s); one is the module loading itself`);
  }
  const named = [...outside.replace('module_or_path = fetch(module_or_path);', '').matchAll(NEVER)]
    .map((m) => m[0])
    // A second fetch is already counted above; said once is enough.
    .filter((w) => w !== 'fetch');
  for (const w of new Set(named)) problems.push(`the glue names ${w}`);
  return problems;
}

/// A module with one import, written byte by byte: (module, name) as a
/// function of no arguments.
function oneImport(module, name) {
  const str = (s) => {
    const b = Buffer.from(s, 'utf8');
    return [b.length, ...b];
  };
  const imports = [1, ...str(module), ...str(name), 0x00, 0x00];
  return new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x04, 0x01, 0x60, 0x00, 0x00,
    0x02, imports.length, ...imports,
  ]);
}

const dir = process.argv[2];
if (!dir) {
  console.error('usage: imports.mjs <web-core-dir>');
  process.exit(2);
}
const wasm = fs.readFileSync(path.join(dir, 'z_web_bg.wasm'));
const glue = fs.readFileSync(path.join(dir, 'z_web.js'), 'utf8');
const problems = [...moduleProblems(wasm), ...glueProblems(glue)];
const imports = WebAssembly.Module.imports(new WebAssembly.Module(wasm)).map((i) => i.name.replace(/_[0-9a-f]{16}$/, ''));

// The controls.
const plantedModule = moduleProblems(oneImport(MODULE, '__wbg_fetch_0123456789abcdef'));
if (plantedModule.length === 0) problems.push('CONTROL: a module importing fetch was not refused');
const plantedGlue = glueProblems(glue.replace(
  '        __wbindgen_init_externref_table: function() {',
  '        __wbg_send_0123456789abcdef: function(a) { return fetch(a); },\n        __wbindgen_init_externref_table: function() {',
));
if (plantedGlue.length === 0) problems.push('CONTROL: a glue answering an import with fetch was not refused');
if (!glue.includes('        __wbindgen_init_externref_table: function() {')) {
  problems.push('CONTROL: the glue has changed shape, so the planted import was not planted');
}

if (problems.length > 0) {
  for (const p of problems) console.error(`PROBLEM ${p}`);
  process.exit(1);
}
console.log(`imports: ${imports.length} (${[...new Set(imports)].join(', ')}), all on the list; the glue touches Date.now, performance.now and crypto.getRandomValues only; both controls refused`);
