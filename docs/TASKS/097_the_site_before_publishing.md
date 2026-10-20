# 097 — The site before publishing: a terms page, and a way to be told of a new release

**Owner, 20 October (rules 78–79, «نعم»):** «قبل النشر نحتاج أمرين في الويب وليس التطبيق. الأول قوانين تخص التطبيق، الثاني نسأل المستخدم منحنا صلة تواصل نرسل له في حال تم تطوير أو التعديلات.»
**Base:** lead line at `2b4fad9` or later; the site is `site/` in the product repository, nginx behind Cloudflare, three languages (`en`, `de`, `ar`), deployed by the lead. Branch `fix/the-site-before-publishing` from the lead line's head. No push.
**Builder:** e2 (the designer seat owns the site). After sitting four, before publishing; it does not touch the app.
**Law:** the site names its proving file for every promise (`scripts/check_site_claims.py` requires the three languages to name the same set); no third party reaches the browser (`site/_headers`: `default-src 'none'`, `form-action 'none'` — a form is refused by our own policy); the site names Faruk AB as publisher and controller (the privacy page's footer); «a claim that cannot survive the first question is worth less than the honest version».

## 1 · Terms of use — rule 78

A new page `site/{en,de,ar}/terms/index.html`, linked from the header's Help menu and the footer beside «Privacy and data protection» and «License» on all nine pages (the guard that counts the footer's identical colophon stays green). Written in the voice of the privacy page: short sections, each promise with its proving file or its CLAIMS id.

The sections, in this order:

1. **Who publishes** — Faruk AB, the same footer block as the privacy page (Org.nr, Falkenberg address, the mailbox). Swedish law.
2. **What Z does, and what it does not claim** — taken from `docs/CLAIMS.md` (paper 094) **by reference, not rewritten**: the page quotes the claim sentences and links the file; the «What we do not claim» section is quoted whole. If 094 has not merged when you start, write the page against the paper's fifteen claims and the lead reconciles the words when CLAIMS.md lands — the page may not say more than the file.
3. **Your part** — review is yours: Z finds a starting point; a suggestion you do not answer stops the exit, and a word Z did not find is a word you cover by hand. What you release leaves this device.
4. **Where it goes** — to the AI provider you chose, with your own credential, under that provider's terms; Z has no server and no account; the provider sees the protected text, your address and the time (the honest half of claim C-03).
5. **The licence** — Apache-2.0 (link the licence page); the source repository; no warranty, in the licence's own words («AS IS», section 7), quoted rather than paraphrased.
6. **Changes** — this page carries its date and the commit it was written against; a change is a new commit.

German by the lead's vocabulary of 092 (Tresor, geschützt, Sitzung, Zugangsdaten, «solange die App offen ist»); Arabic as the privacy page's Arabic. No soft hyphen, no invisible character (G55's rule applies to the site too — extend `check_site.sh` with the same check over `site/`).

## 2 · Be told of a new release — rule 79

No form, no list service, no database, no cookie: the site's own policy forbids a form (`form-action 'none'`) and the privacy page promises no third party. One block on the first page of each language, under the download, and the same block on the terms page:

> **Be told when a new version is out.** Write to `zprivacy@mono-peak.com` with the subject «Updates». We write back only when a release is out, and we delete your address when you reply «stop».

The link is a `mailto:` with the subject prefilled (`?subject=Updates`); Cloudflare's email obfuscation rewrites it on the wire and that is fine (the lead measured it on yourvoicesapp.com; a `grep` of the live page will not see the address — `check_site.sh` must read the tree, not the wire, for this one).

**The privacy page changes in the same commit**, because its sentence «There is no newsletter and no customer list» becomes false the moment the block is published. The new sentence, in the three languages: «If you write «Updates» to zprivacy@mono-peak.com we keep your address in that mailbox and nowhere else, write to it only when a release is out, and delete it when you reply «stop». There is no newsletter beyond that and no customer list.» The retention blank the privacy page still names is not this round.

## Measurement

`scripts/check_site.sh` green (terms page in the three languages naming the same proving set; the footer colophon identical on twelve pages now; the new mailto on the three first pages and the three terms pages; no invisible character under `site/`); `scripts/check_sitemap.py` green with the three new canonicals and their alternates; `scripts/gates.sh` unchanged (the site is not in it). The lead reads the German and the Arabic line by line, then deploys and `curl`s the twelve pages for 200.
