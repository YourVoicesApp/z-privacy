# 121 — French and Spanish: the screens, the site, and no first screen

**Source:** the owner's rulings of 2 November 2026, given one by one. The Z lead holds the owner's delegation to 31 December 2026; the owner reviews. Builder: **e2**. Branch `feat/french-and-spanish-words` off the Z lead tip `01bb6b6`, in a tree of your own (`git -C ~/z/mono-privacy worktree add ~/z/build-e2-121 -b feat/french-and-spanish-words 01bb6b6`), with **its own `CARGO_TARGET_DIR`**. ed builds the packs in paper 120 at the same time.

## What the owner said

> French and Spanish versions of Z, «سواء للتطبيق أو لشاشات الويب».
> On the legal pages: «نضع في رأس الصفحة أن النص الإنكليزي هو النص الأساسي، والترجمة هي بطريقة الذكاء الصناعي، ونضع إيميلًا لتصحيح الأخطاء» — the same address.
> «نلغي الشاشة الأولى ونجعل المستخدم يدخل مباشرة… لا أجد داعيًا للشاشة الأولى التي تحتوي على خيارات اللغة فقط» — and the visitor enters «بلغة متصفحه إن وُجد، أو إنكليزية».

## What is built

### 1 · The app

- `app_fr.arb` and `app_es.arb`: **every** key of `app_en.arb` (702 today), through the one list (`the_sentences_in_one_list`), with the glossary the other languages keep (token, vault, protected, original, provider). French and Spanish in the language choice.
- Under the language choice, when French or Spanish is chosen, one line: the translation was made with AI, and errors go to **zprivacy@mono-peak.com** (subject «Translation (FR)» / «Translation (ES)»).
- The existing English suite is what catches a translation that changed a meaning: run it in both new languages as it runs in German and Swedish.

### 2 · The site

- `site/fr/` and `site/es/`: the six pages — home, download, guide, the 25 questions, privacy, terms — from the English, page for page, with `hreflang` on every page of every language, the sitemap, the FAQPage JSON-LD equal to the visible text, and every gate the three languages pass today (`check_site.sh`, the quoted app text, the absolutes, the claims, the FAQ pages).
- **Privacy and terms, at their head:** the English text is the primary text; this translation was made with AI; errors to zprivacy@mono-peak.com with the subject above.
- **Every other French and Spanish page, at its foot:** one short line saying the same, with the address.
- **What Z finds in French and Spanish, said plainly** wherever the site lists what Z recognises (in all five languages): the numbers of paper 120 are recognised; names are **suggested** by their shape and kept once accepted; **there is no French or Spanish names library yet — it is a later update.** No sentence may say more than paper 120 builds; take its table as the source.
- The top bar's language menu gains Français and Español on every page of every language.

### 3 · No first screen

- `site/index.html` — the language chooser — is removed **by moving it out of `site/`**, not by deleting it (keep it in `site/../packaging/retired/` or similar, named).
- `/` is answered by the server: **the visitor's browser language if we have it (ar, de, fr, es, en), else English**, as a redirect to `/<lang>/`. No script on any page (the CSP forbids it). Write the nginx lines in the repository beside the headers record (`site/_headers` explains why that record exists), so the lead puts them on the server at the publish; `x-default` then points at what `/` does.
- Every gate or link that names the first screen (`measure_first_screen.py`, `check_site.sh`, the sitemap) follows, with the reason in the commit.

## What is not in this paper

- Any change in `z_core` (paper 120).
- Publishing: nothing is deployed or pushed. The owner sees the pages and the screens first and says «انشر».

## Acceptance

- Gates green with `scripts/gates.sh`, and `check_site.sh --tree-only` for all five languages.
- `app_fr.arb` and `app_es.arb` with every key; the English suite passes in both.
- Shots of the app (language choice with the line, the main screen) and of each French and Spanish home page, at desktop and phone width.
- Tell the lead which sentences you were least sure of, in each language: the lead reads French and Spanish, as it read German.
- A named commit on your branch; nothing pushed. Report the SHA.
