#!/usr/bin/env bash
# **Preview the web trial on this machine** — paper 122 §4, rule 86.
#
#     scripts/preview_trial.sh [DIR] [PORT]     # DIR defaults to site-trial/
#
# Serves DIR on **127.0.0.1 only** — never 0.0.0.0, so nothing on the network
# can reach it — with the headers of DIR/_headers applied exactly as written
# (the trial's Content-Security-Policy among them), and `.wasm` served as
# `application/wasm`. Python's standard library and nothing else; it writes
# nothing anywhere, and Ctrl+C stops it.
#
# **The trial is served at `/<lang>/try/`** — `/en/try/`, `/ar/try/`,
# `/sv/try/`, and de, fr, es the same way. The page takes its language from the
# first segment of its address (`theLanguageOfTheAddress`), so the language is
# the folder in front of `try/`, and the page's own files are found relative to
# that address (it has no <base>). `/` goes to `/en/try/`. Where the trial
# stands on the live site is the owner's word (paper 122 §4); this is only the
# preview's address.
#
# **Every other address is the live site's tree, read and never written**:
# `/en/`, `/en/download/` and the rest come from `site/`, with `site/_headers`,
# so the trial's two links («About Z, download and guide» and the band's
# download link) open the pages they will open on the site. Swedish has no
# site pages yet, so those links go to English (paper 122, the lead).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:-$ROOT/site-trial}"
PORT="${2:-8722}"
die() { echo "preview_trial: $*" >&2; exit 1; }
[ -f "$DIR/index.html" ] && [ -f "$DIR/_headers" ] && [ -f "$DIR/z_web.js" ] \
  || die "no trial in $DIR — build it first: scripts/build_site_trial.sh"

exec python3 -I - "$DIR" "$ROOT/site" "$PORT" <<'PY'
import fnmatch, http.server, os, posixpath, signal, sys, urllib.parse

# **Ctrl+C stops it, wherever it was started from.** A program started in the
# background of a script inherits SIGINT as ignored, and Python then leaves it
# ignored; so the handler is set here, and SIGTERM stops it the same way.
def _stop(*_):
    raise KeyboardInterrupt
signal.signal(signal.SIGINT, _stop)
signal.signal(signal.SIGTERM, _stop)

TRIAL, SITE, PORT = sys.argv[1], sys.argv[2], int(sys.argv[3])
HOST = '127.0.0.1'  # this machine only; G75 holds the file to it
LANGS = ('en', 'ar', 'de', 'fr', 'es', 'sv')


def read_headers(path):
    """`_headers` as the site writes it: a path pattern on its own line, its
    headers indented under it, `#` for a comment. Applied exactly as written."""
    rules, pattern = [], None
    if not os.path.isfile(path):
        return rules
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            pattern = line.strip()
            rules.append((pattern, []))
        elif pattern is not None and ':' in line:
            name, value = line.strip().split(':', 1)
            rules[-1][1].append((name.strip(), value.strip()))
    return rules


TRIAL_HEADERS = read_headers(os.path.join(TRIAL, '_headers'))
SITE_HEADERS = read_headers(os.path.join(SITE, '_headers'))
MIME = {'.wasm': 'application/wasm', '.js': 'text/javascript', '.mjs': 'text/javascript',
        '.json': 'application/json', '.ttf': 'font/ttf', '.otf': 'font/otf',
        '.woff2': 'font/woff2', '.html': 'text/html; charset=utf-8', '.png': 'image/png',
        '.svg': 'image/svg+xml', '.css': 'text/css', '.frag': 'application/octet-stream'}


class Preview(http.server.BaseHTTPRequestHandler):
    server_version = 'preview'
    sys_version = ''

    def _where(self):
        """(root, the path inside it, the headers that apply) — or a redirect."""
        path = urllib.parse.urlsplit(self.path).path
        if path in ('', '/'):
            return ('redirect', '/en/try/')
        parts = path.split('/')
        if len(parts) >= 3 and parts[1] in LANGS and parts[2] == 'try':
            if len(parts) == 3:
                return ('redirect', path + '/')
            inner = '/'.join(parts[3:])
            return (TRIAL, inner or 'index.html', TRIAL_HEADERS)
        return (SITE, path.lstrip('/'), SITE_HEADERS)

    def _send_file(self, root, inner, rules):
        inner = posixpath.normpath(urllib.parse.unquote(inner)).lstrip('/')
        if inner.startswith('..') or inner == '_headers' or inner.endswith('/_headers'):
            return self.send_error(404)
        full = os.path.join(root, inner)
        if os.path.isdir(full):
            full = os.path.join(full, 'index.html')
        if not os.path.isfile(full):
            return self.send_error(404)
        body = open(full, 'rb').read()
        self.send_response(200)
        self.send_header('Content-Type', MIME.get(os.path.splitext(full)[1], 'application/octet-stream'))
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        url_path = urllib.parse.urlsplit(self.path).path
        for pattern, headers in rules:
            if fnmatch.fnmatchcase(url_path, pattern) or fnmatchcase_root(pattern, url_path):
                for name, value in headers:
                    self.send_header(name, value)
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def do_GET(self):
        where = self._where()
        if where[0] == 'redirect':
            self.send_response(302)
            self.send_header('Location', where[1])
            self.end_headers()
            return
        self._send_file(*where)

    do_HEAD = do_GET

    def log_message(self, fmt, *args):
        sys.stderr.write('  ' + (fmt % args) + '\n')


def fnmatchcase_root(pattern, path):
    # `/*` covers every path, `/` itself included.
    return pattern == '/*'


server = http.server.ThreadingHTTPServer((HOST, PORT), Preview)
base = f'http://{HOST}:{server.server_address[1]}'
print('The web trial, on this machine only (Ctrl+C stops it):')
for lang, name in (('en', 'English'), ('ar', 'Arabic'), ('sv', 'Swedish')):
    print(f'  {name:8} {base}/{lang}/try/')
print(f'  (and {base}/de/try/, /fr/try/, /es/try/)')
sys.stdout.flush()
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
    print('\npreview_trial: stopped')
PY
