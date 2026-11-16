#!/usr/bin/env python3
"""**The trial's server record** — paper 125 §2.2 and §3.

    python3 -I scripts/write_trial_nginx.py DIR          # write DIR/_trial.nginx from DIR/_headers
    python3 -I scripts/write_trial_nginx.py --check DIR  # its headers must equal DIR/_headers

`site-trial/_trial.nginx` is a record, like `site/_headers` and
`site/_root_redirect.nginx`: it is not served and nothing here reads it. It
holds what the owner puts on the server for the trial (paper 125 §3, steps 2
and 3): the snippet with the trial's headers, and the locations under
`/<lang>/try/`.

**The headers are derived from `_headers`, not typed twice.** The snippet's
`add_header` lines are written from `site-trial/_headers` — the same headers
the preview sends — plus the HSTS line the site already sends. `--check`
reads a written record back and fails when its headers and `_headers`
differ, so a hand edit of either is caught.

**The locations are paper 125 §3's, as ed measured them on nginx 1.28.3.**
The page and its bootstrap use `root` with `try_files`, not `alias`: for
`/en/try/` — the address «/» sends everyone to — the URI ends in `/`, so with
an `alias` to a file in a regex location nginx's index module appends
`index.html` to the alias (`…/index.htmlindex.html`), and the paper's first
form answered 500. `try_files` serves the file inside the same location, so
the trial's headers stay, and its type comes from its own extension, so no
`default_type`. Every other file keeps the paper's `alias` to
`$trial_file`: that URI never ends in `/`, and it was measured to serve.
"""
import pathlib
import re
import sys

HSTS = ('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
LANGS = 'en|ar|de|fr|es|sv'
ROOT = '/srv/zprivacy/site-trial'
SNIPPET = '/etc/nginx/snippets/zprivacy-trial-headers.conf'
SCRIBE_SNIPPET = '/etc/nginx/snippets/zprivacy-trial-scribe-headers.conf'
SCRIBE_RULE = '/*/try/scribe/*'


def rules_of(path: pathlib.Path) -> dict[str, list[tuple[str, str | None]]]:
    """`_headers`' rules, each pattern with its lines in order: `(name,
    value)`, or `(name, None)` for a `! Name` that takes off what an earlier
    rule set."""
    rules: dict[str, list[tuple[str, str | None]]] = {}
    pattern = None
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            pattern = line.strip()
            rules[pattern] = []
        elif pattern is not None and line.strip().startswith('!'):
            rules[pattern].append((line.strip()[1:].strip(), None))
        elif pattern is not None:
            name, _, value = line.strip().partition(':')
            rules[pattern].append((name.strip(), value.strip()))
    return rules


def headers_of(path: pathlib.Path) -> list[tuple[str, str]]:
    """What every page of the trial is sent: the `/*` rule."""
    return [(n, v) for n, v in rules_of(path).get('/*', []) if v is not None]


def scribe_headers_of(path: pathlib.Path) -> list[tuple[str, str]]:
    """What Scribe's page is sent (paper 124): the `/*` rule, less what its
    own rule takes off, then its own — as the preview applies them."""
    rules = rules_of(path)
    sent = [(n, v) for n, v in rules.get('/*', []) if v is not None]
    for name, value in rules.get(SCRIBE_RULE, []):
        if value is None:
            sent = [(n, v) for n, v in sent if n.lower() != name.lower()]
        else:
            sent.append((name, value))
    return sent


def add_header(name: str, value: str) -> str:
    quoted = f'"{value}"' if re.search(r'[\s;,"]', value) else value
    return f'add_header {name} {quoted} always;'


def the_record(headers: list[tuple[str, str]], scribe: list[tuple[str, str]]) -> str:
    snippet = '\n'.join(add_header(n, v) for n, v in headers + [HSTS])
    scribe_snippet = '\n'.join(add_header(n, v) for n, v in scribe + [HSTS])
    return f'''# The web trial on the server — paper 125 §3. A RECORD: not served, and not
# read by anything in this repository. Written by scripts/build_site_trial.sh
# from site-trial/_headers by scripts/write_trial_nginx.py; never edit it by
# hand — its headers are checked against _headers.

# ---- 2. {SNIPPET}
# The same headers as site-trial/_headers, plus the HSTS line the site already
# sends. A location's `add_header` replaces the server's own, so all of them are
# written here.
{snippet}

# ---- 2b. {SCRIBE_SNIPPET} (paper 124)
# Scribe's page: the trial's headers, with `frame-ancestors 'self'` and
# `X-Frame-Options SAMEORIGIN` in place of the two that forbid any frame.
{scribe_snippet}

# ---- 3. In the z-privacy.com `server {{}}` block, ABOVE every existing
# `location ~` line. Regex locations are checked in file order, so an existing
# one such as `location ~* \\.(js|css|wasm)$` placed above would take the
# trial's files. A `location ^~ /en/` (or /ar/, /de/, …) stops the trial's
# regexes from ever being checked: if `grep -n location` shows one, stop and
# send the lead its output. The page and the bootstrap use `root` with
# `try_files`, not `alias` (see the head of scripts/write_trial_nginx.py).
#
# The map line for «/» (§3.4) is in site/_root_redirect.nginx: it REPLACES the
# old regex line; there is only one.

# /<lang>/try → /<lang>/try/
location ~ ^/({LANGS})/try$ {{ return 301 /$1/try/; }}

# CanvasKit (paper 124): one copy, at one absolute address, for every language
# and for both pages, Z's and Scribe's — their bootstraps name /try/canvaskit/.
location ~ ^/try/canvaskit/(?<canvaskit_file>.+)$ {{
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "public, max-age=3600" always;
    alias {ROOT}/canvaskit/$canvaskit_file;
}}

# Scribe's editor (paper 124), at /<lang>/try/scribe/ — the one page that may
# be framed, by our own origin only: its own snippet (section 2b). Above the
# trial's last location, which would otherwise take its files.
location ~ ^/(?:{LANGS})/try/scribe/(?:index\\.html)?$ {{
    include snippets/zprivacy-trial-scribe-headers.conf;
    add_header Cache-Control "no-cache" always;
    root {ROOT};
    try_files /scribe/index.html =404;
}}
location ~ ^/(?:{LANGS})/try/scribe/flutter_bootstrap\\.js$ {{
    include snippets/zprivacy-trial-scribe-headers.conf;
    add_header Cache-Control "no-cache" always;
    root {ROOT};
    try_files /scribe/flutter_bootstrap.js =404;
}}
location ~ ^/(?:{LANGS})/try/scribe/(?<scribe_file>.+)$ {{
    include snippets/zprivacy-trial-scribe-headers.conf;
    add_header Cache-Control "public, max-age=3600" always;
    alias {ROOT}/scribe/$scribe_file;
}}

# The page itself and its bootstrap: always asked again.
location ~ ^/(?:{LANGS})/try/(?:index\\.html)?$ {{
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "no-cache" always;
    root {ROOT};
    try_files /index.html =404;
}}
location ~ ^/(?:{LANGS})/try/flutter_bootstrap\\.js$ {{
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "no-cache" always;
    root {ROOT};
    try_files /flutter_bootstrap.js =404;
}}
# Every other file of the trial.
location ~ ^/(?:{LANGS})/try/(?<trial_file>.+)$ {{
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "public, max-age=3600" always;
    alias {ROOT}/$trial_file;
}}
'''


def snippet_headers(record: str, scribe: bool = False) -> list[tuple[str, str]]:
    """The `add_header` lines of the record's snippet — the trial's, or with
    [scribe] Scribe's (section 2b) — read back."""
    before, _, after = record.split('# ---- 3.')[0].partition('# ---- 2b.')
    part = after if scribe else before
    out = []
    for m in re.finditer(r'^add_header (\S+) (?:"([^"]*)"|(\S+)) always;$', part, re.M):
        out.append((m.group(1), m.group(2) if m.group(2) is not None else m.group(3)))
    return out


def page_locations_with_alias(record: str) -> list[str]:
    """The page's and the bootstrap's locations that use `alias` or lack
    `try_files` — paper 125 §3, measured: such a page answers 500."""
    bad = []
    for m in re.finditer(r'^location ~ (\S+) \{\n(.*?)^\}', record, re.M | re.S):
        pattern, body = m.group(1), m.group(2)
        if 'index' in pattern or 'flutter_bootstrap' in pattern:
            if 'alias ' in body or 'try_files ' not in body:
                bad.append(pattern)
    return bad


def main(argv: list[str]) -> int:
    check = argv[:1] == ['--check']
    args = argv[1:] if check else argv
    if len(args) != 1:
        print(__doc__.splitlines()[2].strip(), file=sys.stderr)
        return 2
    folder = pathlib.Path(args[0])
    headers = headers_of(folder / '_headers')
    if not headers:
        print(f'write_trial_nginx: no headers in {folder / "_headers"}', file=sys.stderr)
        return 1
    scribe = scribe_headers_of(folder / '_headers')
    record = folder / '_trial.nginx'
    if not check:
        record.write_text(the_record(headers, scribe), encoding='utf-8')
        print(f'write_trial_nginx: {record} ({len(headers) + 1} headers; Scribe\'s page {len(scribe) + 1})')
        return 0
    if not record.is_file():
        print(f'write_trial_nginx: no {record}', file=sys.stderr)
        return 1
    text = record.read_text(encoding='utf-8')
    for what, found, want in (
        ('the trial', snippet_headers(text), headers + [HSTS]),
        ('Scribe\'s page', snippet_headers(text, scribe=True), scribe + [HSTS]),
    ):
        if found != want:
            print(f'write_trial_nginx: the record\'s headers for {what} are not _headers\'s:', file=sys.stderr)
            for n, v in want:
                if (n, v) not in found:
                    print(f'  missing or changed: {n}: {v}', file=sys.stderr)
            for n, v in found:
                if (n, v) not in want:
                    print(f'  not in _headers: {n}: {v}', file=sys.stderr)
            return 1
    bad = page_locations_with_alias(text)
    if bad:
        print('write_trial_nginx: the page and the bootstrap must use root and try_files, '
              f'not alias (nginx answers 500 on /<lang>/try/): {bad}', file=sys.stderr)
        return 1
    # Regex locations are tried in order: Scribe's must stand above the
    # trial's last one, which would take /<lang>/try/scribe/… otherwise.
    if text.find('try/scribe/(?<scribe_file>') > text.find('try/(?<trial_file>'):
        print('write_trial_nginx: Scribe\'s locations stand below the trial\'s last one', file=sys.stderr)
        return 1
    print(f'write_trial_nginx: {record} sends exactly _headers\'s {len(headers)} headers and HSTS, '
          f'and Scribe\'s page its {len(scribe)} and HSTS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
