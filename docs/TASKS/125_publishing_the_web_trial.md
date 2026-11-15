# 125 — Publishing the web trial on z-privacy.com

**Owner of the paper:** the lead. **The owner publishes:** every server and Cloudflare step below is the owner's hand. The lead has no server access and does not ask a builder to act for it.
**Builder:** e2, for the small part A (records in the repository and the sitemap).
**Source:** rules 85, 86 (أ), 87 and 88. Papers 122 and 123 built the trial. Paper 124 (Scribe's editor) is published later, by an addendum to this paper (§7).
**Why now:** Web Summit's competitions for Doha open in about 7–10 days (from 15 Nov). The judges will open the site.

## 0 · What is there today (measured, 15 Nov)

**The trial:**
- `feat/web-trial` at 70dd7b8, pushed; the lead's gates show 683 checks and 0 failed.
- `scripts/build_site_trial.sh` writes `site-trial/`: 25 MB, 33 files. It is **one build for all six languages**: the page reads its language from its own address (`/<lang>/try/`).
- The trial's top line opens today's front page, `/<lang>/` (Swedish opens `/en/`, because the site has no Swedish pages). The notice band opens `/<lang>/download/`.

**The site:**
- It is served by nginx on our origin server, behind Cloudflare.
- The pages are in `/srv/zprivacy/site/`.
- The headers come from `/etc/nginx/snippets/zprivacy-headers.conf`. `site/_headers` is the record of them: `default-src 'none'`, and no script at all.
- «/» is a 302 by `Accept-Language` to `/$lang/`, in five languages (`site/_root_redirect.nginx`, paper 121).
- `robots.txt` allows everything. `sitemap.xml` lists the five front pages and the other pages.

**Cloudflare (the owner's shots, 7–14 Nov):**
- 871 unique visitors, 5.92k requests and 73 MB served;
- **17.86 % cached**;
- 1.19k requests from AI crawlers.

**Measured by ed, 15 Nov:**
- He ran Ubuntu's own nginx 1.28.3 package, unpacked without root, on `127.0.0.1` against `site-trial/` (scratchpad `ngx125/`).
- The first draft of §3 answered **500** on `/<lang>/try/`: an `alias` to a file, plus the index module, gives `index.htmlindex.html`.
- A map that kept the old line above the new one sent Swedish to `/en/try/`.
- Both are corrected below, and every other line works as written:
  - the 301;
  - `alias` with `$trial_file`, with the right types and headers;
  - no traversal (`../` → 404, `%2e%2e` → 400);
  - `.wasm` as `application/wasm`;
  - the front pages unchanged.

## 1 · Where the trial stands (rule 85: the first screen is the chat)

- **The trial lives at `/<lang>/try/`** for `en ar de fr es sv`.
- **«/» sends a visitor to the trial:** `/$lang/try/`, chosen by `Accept-Language` as today, with **Swedish added** (rule 86 (هـ)). The visitor's first screen is the chat.
- **The front pages stay where they are, unchanged,** at `/<lang>/`. Links from outside and the crawlers' index keep working, and the trial's top line still leads there.
- Optional, on the owner's word (§6): one line on each front page, «Try Z in your browser», leading to `/<lang>/try/`.

## 2 · Part A (e2): the records, before the publish

1. **`site/_root_redirect.nginx`:**
   - the map gains `sv`;
   - the redirect becomes `/$zprivacy_lang/try/`;
   - the comment cites this paper.
2. **A new record, `site-trial/_trial.nginx`,** written by the build beside `_headers`. It holds the lines of §3 exactly. A check fails when its CSP and the other headers differ from `site-trial/_headers`.
3. **`site/sitemap.xml`** gains the six `/<lang>/try/` addresses, with `hreflang` alternates as the front pages have. `scripts/check_sitemap.py` passes.
4. **Nothing else in `site/` changes,** and the trial's build still never writes there (G75).
5. **Cache headers in the record (§4):**
   - `index.html` and `flutter_bootstrap.js` are sent with `Cache-Control: no-cache`;
   - every other file under `/try/` is sent with `public, max-age=3600`.
6. Gates green, with counts. Commit after them, never while they run, and do not push.

## 3 · The server (the owner)

**Before:** keep a copy of the two files that change.

```
cp /etc/nginx/sites-available/<the z-privacy.com file> ~/nginx-z-before-125.conf
cp /etc/nginx/snippets/zprivacy-headers.conf ~/zprivacy-headers-before-125.conf
```

**1. Upload the trial from this machine.** `_headers` and `_trial.nginx` are records, not pages, so they are not uploaded.

```
rsync -a --delete --exclude _headers --exclude _trial.nginx \
  ~/z/build-lead-122/site-trial/  root@<server>:/srv/zprivacy/site-trial/
```

**2. The trial's headers:** a new snippet, `/etc/nginx/snippets/zprivacy-trial-headers.conf`, holding the same five headers as `site-trial/_headers`, plus the HSTS line the site already sends. A location's `add_header` replaces the server's own, so all of them are written here:

```
add_header Content-Security-Policy "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'none'" always;
add_header Referrer-Policy no-referrer always;
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options DENY always;
add_header Permissions-Policy "geolocation=(), camera=(), microphone=(), interest-cohort=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

**3. The locations,** in the z-privacy.com `server {}` block, **above every existing `location ~` line.** nginx checks regex locations in file order, so an existing one such as `location ~* \.(js|css|wasm)$` placed above would take the trial's files.

First, look at what is there:

```
grep -n 'location' <the z-privacy.com file>
```

If it shows a `location ^~ /en/` (or `/ar/`, `/de/`, and so on), stop and send the lead the output: such a prefix stops the trial's regexes from ever being checked.

The lines:

```
# /<lang>/try → /<lang>/try/
location ~ ^/(en|ar|de|fr|es|sv)/try$ { return 301 /$1/try/; }

# The page itself and its bootstrap: always asked again.
location ~ ^/(?:en|ar|de|fr|es|sv)/try/(?:index\.html)?$ {
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "no-cache" always;
    root /srv/zprivacy/site-trial;
    try_files /index.html =404;
}
location ~ ^/(?:en|ar|de|fr|es|sv)/try/flutter_bootstrap\.js$ {
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "no-cache" always;
    root /srv/zprivacy/site-trial;
    try_files /flutter_bootstrap.js =404;
}
# Every other file of the trial.
location ~ ^/(?:en|ar|de|fr|es|sv)/try/(?<trial_file>.+)$ {
    include snippets/zprivacy-trial-headers.conf;
    add_header Cache-Control "public, max-age=3600" always;
    alias /srv/zprivacy/site-trial/$trial_file;
}
```

**4. «/» to the trial:** in the `map` (in `http {}`), **replace** the regex line with this one. There must be only one regex line: with the old one left above it, Swedish is sent to English (measured).

```
    "~*(?:^|,)\s*(?<zp>ar|de|fr|es|en|sv)(?:[-;,\s]|$)" $zp;
```

In `location = /`, the redirect becomes:

```
    return 302 /$zprivacy_lang/try/;
```

**5. The WebAssembly type.** `grep wasm /etc/nginx/mime.types` must print `application/wasm wasm;`. If it prints nothing, add that line inside the `types {}` block of `mime.types`.

**6. Test, then reload:**

```
nginx -t && systemctl reload nginx
```

`nginx -t` must say «test is successful». If it does not, nothing is reloaded: send the lead its words.

## 4 · Cloudflare (the owner): cache the trial's files

Without this, every visitor pulls the 25 MB from our server.

**Caching → Cache Rules → Create rule**, named «z trial files»:
- When: `URI Path` contains `/try/`, AND `URI Path` does not end with `/`, AND `URI Path` does not end with `index.html`, AND `URI Path` does not end with `flutter_bootstrap.js`.
- Then: **Eligible for cache**; Edge TTL: **use the cache-control header** (one hour); Browser TTL: **respect origin**.

**After every publish of a new trial build:** Caching → Configuration → **Purge Cache → Custom Purge → prefix** `z-privacy.com/en/try/`, and the same for `ar de fr es sv`. The file names of a Flutter build do not change between builds. Without the purge, a new `index.html` may meet an old `main.dart.js` for up to an hour.

## 5 · Checks after the publish

The lead runs these from this machine; they are only reads of our own site.

1. `curl -sI https://z-privacy.com/` → `302`, `location: /en/try/`. With `Accept-Language: sv` → `/sv/try/`. With `ar` → `/ar/try/`.
2. `curl -sI https://z-privacy.com/en/try/` → `200`, the trial's CSP (`'wasm-unsafe-eval'`, `connect-src 'self'`), `cache-control: no-cache`.
3. `curl -sI https://z-privacy.com/en/try/z_web_bg.wasm` → `200`, `content-type: application/wasm`, `max-age=3600`. On the second request, `cf-cache-status: HIT`.
4. `curl -sI https://z-privacy.com/en/` → `200`, the site's own strict CSP (`default-src 'none'`, no `script-src`). The front page is unchanged.
5. `curl -sI https://z-privacy.com/sv/` → `404`, as today. The site has no Swedish pages.
6. `curl -s https://z-privacy.com/sitemap.xml` holds the six `/try/` addresses.
7. **The owner,** on a phone and on the computer:
   - open `z-privacy.com`;
   - run one full flow in English and one in Arabic, with invented names;
   - press «Start over»;
   - follow the top line to the front page.

**Rolling back:**
- Put back the two copied files.
- `nginx -t && systemctl reload nginx`.
- The trial's folder can stay; nothing links to it then.

## 6 · Waiting for the owner's word (not part of the publish unless the owner says «نعم»)

1. **A line on each front page,** «Try Z in your browser», leading to `/<lang>/try/`, in the five languages. This changes `site/`. G59 must still pass.
2. **`llms.txt`,** a short plain text that says what Z is and links the trial, the front pages and the download page. It is read by AI crawlers. Its sentences must pass G59's rule: the site says nothing the tree does not.

## 7 · Paper 124's addendum (written when 124 is merged)

These go to the server in one later step, with their own checks:
- the shared CanvasKit path `/try/canvaskit/`;
- the Scribe bundle at `/<lang>/try/scribe/`;
- `frame-src 'self'` in the trial snippet;
- a location for `/<lang>/try/scribe/` with `frame-ancestors 'self'` and `X-Frame-Options SAMEORIGIN`, and not DENY.
