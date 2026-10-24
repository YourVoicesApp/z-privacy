#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Every number on the site, and every word it borrowed, checked against the thing it is about.

The owner's rule for this round, in the lead's words: «لا رقمَ قبل فعله —
وقاعدةُ "كل جملة قياس" تسري على الموقع كما على التذييل». No number before its
deed, and «every sentence is a measurement» holds for the site as it does for
the footer.

A page is where a number goes to drift. The five it makes:

  1. **the crate table** — every name and version of other people's work, which
     is an attribution and not decoration. The count is not written here: it moves
     with `Cargo.lock`, and a number in a docstring moves with nothing. Checked against `Cargo.lock` in both
     directions. On 9 October it was short by one row: `windows-sys 0.59.0` was
     in the lock and not on the page, while `0.52.0` was on both.
  2. **the font faces** — 6 · 18 · 12 · 10 per family, checked against the
     `@font-face` rules the site actually serves.
  3. **the glossary** — 29 words that the page claims are the app's own and not
     a second wording invented here. Checked against the string literals the
     app really prints. On 9 October three of them («Found by rule», «Found by
     pack», «Found by vault») were nowhere in the product: the app's own badges
     read `Rule`, `Pack`, `Vault` and `You`, and the page had invented a
     sentence for three of them and omitted the fourth.
  4. **the path** — Import → Scan → Review → Protect → Review what will leave →
     AI → Restore, said to be «as it appears in the app».
  5. **the two fingerprints** — 103, and the only number on this site that is
     not read off another file but computed: the sha256 of the real artefact in
     the deploy tree, against what the three download pages print beside it.
     With nothing signing the installer, that number is the only thing a
     stranger has, so it is the one number here that is measured rather than
     compared.

Two words in the glossary are **not** printed by any screen, and they are named
here rather than quietly allowed: a word that the product does not say is a word
this page has to account for.

And since 105, two **sentences** rather than numbers: the front page's answer to
«which AI services?» and the guide's answer to «what if two copies write at
once?» were both wider than this tree, so each is now marked with the fact it
serves, in all three languages, and the wording it replaced is refused in the
served page. The table is `THE_NARROWED`, and the comment above it says why a
sentence needs a key at all.

  python3 scripts/check_site_claims.py        # the exit status is the verdict
"""
import io
import os
import pathlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The glossary's two honest exceptions, with the reason each one is allowed.
NOT_ON_A_SCREEN = {
    'Safe payload': 'the core’s own name for the text that leaves — `SafePayload`',
    'Local model': 'a model on your own machine, which the app lets you reach without naming it',
}


def read(*parts):
    with io.open(os.path.join(ROOT, *parts), encoding='utf-8') as fh:
        return fh.read()


def say(verdict, line):
    print('  %-6s %s' % (verdict, line))


def dart_strings():
    out = []
    for base, _, files in os.walk(os.path.join(ROOT, 'apps/flutter_app/lib')):
        for name in files:
            if name.endswith('.dart'):
                with io.open(os.path.join(base, name), encoding='utf-8') as fh:
                    src = fh.read()
                out += re.findall(r"'([^'\n]*)'", src) + re.findall(r'"([^"\n]*)"', src)
    return [s.lower() for s in out]


def crates():
    page = set(re.findall(r'<span class="cn">([a-z0-9_-]+)</span><span class="cv">([^<]+)</span>',
                          read('site/third-party/index.html')))
    lock = set(re.findall(r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"',
                          read('Cargo.lock')))
    # Our own two crates are the thing being licensed, not a third party.
    lock = {(n, v) for n, v in lock if n not in ('z_core', 'z_bridge')}
    missing, extra = sorted(lock - page), sorted(page - lock)
    bad = 0
    for n, v in missing:
        say('FAIL', 'the build uses %s %s and the notices page does not name it' % (n, v))
        bad = 1
    for n, v in extra:
        say('FAIL', 'the notices page names %s %s, which this build does not use' % (n, v))
        bad = 1
    if not bad:
        say('PASS', 'all %d crates on the notices page are exactly what Cargo.lock says' % len(page))
    return bad


def fonts():
    css = read('site/assets/fonts.css')
    served = {}
    for fam in re.findall(r"font-family: '([^']+)'", css):
        served[fam] = served.get(fam, 0) + 1
    page = re.findall(r'<span class="cn">([A-Za-z ]+)</span><span class="cv">(\d+)</span>',
                      read('site/third-party/index.html'))
    bad = 0
    for fam, said in page:
        n = served.get(fam)
        if n is None:
            say('FAIL', 'the page names the family %s, which this site does not serve' % fam)
            bad = 1
        elif int(said) != n:
            say('FAIL', 'the page says %s has %s faces; the site serves %d' % (fam, said, n))
            bad = 1
    if not page:
        say('FAIL', 'the notices page names no font family at all')
        bad = 1
    elif not bad:
        say('PASS', 'the face counts are the faces served: ' +
            ', '.join('%s %d' % (f, served[f]) for f, _ in page))
    return bad


def glossary(lits):
    page = read('site/en/index.html')
    terms = re.findall(r'<div class="ven"[^>]*><span class="vlab"[^>]*>EN</span>([^<]+)</div>', page)
    exact = inside = 0
    bad = 0
    for term in terms:
        k = term.lower()
        if any(l == k for l in lits):
            exact += 1
        elif any(k in l for l in lits):
            inside += 1
        elif term in NOT_ON_A_SCREEN:
            pass
        else:
            say('FAIL', 'the glossary says the app calls it «%s», and no screen '
                        'prints those words' % term)
            bad = 1
    if not terms:
        say('FAIL', 'there is no glossary on the English page')
        bad = 1
    elif not bad:
        say('PASS', 'the glossary is the app’s own words: %d of %d printed as a label, '
                    '%d inside a longer one, %d named as not on a screen'
            % (exact, len(terms), inside, len(NOT_ON_A_SCREEN)))
    return bad


def path(lits):
    steps = re.findall(r'<span class="step">([^<]+)</span>', read('site/en/index.html'))
    bad = 0
    for step in steps:
        if not any(step.lower() == l or step.lower() in l for l in lits):
            say('FAIL', 'the path shows the step «%s», which the app does not print' % step)
            bad = 1
    if not steps:
        say('FAIL', 'the path chain is not on the English page')
        bad = 1
    elif not bad:
        say('PASS', 'every step of the path is a word the app prints (%s)' % ' → '.join(steps))
    return bad


# **What the interface really speaks, and what it still owes** — 097.
#
# The site said «the interface is English today» for two days after it stopped
# being true, in five sentences on three pages, and nothing went red: a
# sentence is not a number, so no guard was reading it. The lead's ruling is
# that a number written in two places needs a gate that compares them, which
# is the same defect as C-15 in `docs/CLAIMS.md` one floor up.
#
# So the pages carry the two numbers in a span each, this reads them, and the
# answer comes from the **one** place the app measures them: the floor table in
# `scripts/check_the_one_list.py`, which the app's own `G50`/`G51` holds equal
# to the tree on every run. One source, two readers.
#
# The third number is the claim itself. A list whose values are still the
# English source is not a language the interface speaks — measured, not
# declared. So the languages a page may name are the ones whose list differs
# from the English in more values than it matches, and a page naming one it
# does not have, or missing one it does, is a red.
#
# **Swedish moved across that line on 23 October 2026** (paper 106, the owner's
# word): it differed from the English in exactly one value, `thisLanguageName`,
# and now differs in 680 of 691. The measurement is what moved the pages, not
# a hand — which is the whole design of this check. What the pages may **not**
# say is that the Swedish is good: the owner is the only native reviewer and
# his reading is a round of its own, so the sentence names the language and the
# date and says that nobody has read it yet.
#
# **And the absent language is French, not Arabic.** The first draft of this
# round reached for Arabic — the next language, untranslated on purpose — and
# it cannot be the control: all three pages **name** Arabic in order to deny it
# («Arabic is a reading pack and not a language of the interface»), so a
# word-absence control over it would red on a correct page. French is named
# nowhere in the three pages, there is no `app_fr.arb`, and `fr` is already the
# control on the floor below — `theListIsWrittenIn('fr')` is the case that
# keeps the app's own law biting. One language, both floors.
SPEAKS = {
    'en': ('English', 'German', 'Swedish'),
    'de': ('Englisch', 'Deutsch', 'Schwedisch'),
    'ar': ('الإنجليزيّة', 'الألمانيّة', 'السويديّة'),
}
NOT_SPOKEN = {'en': ('French',), 'de': ('Französisch',), 'ar': ('الفرنسيّة',)}
TRANSLATED = {'de': 'German', 'sv': 'Swedish'}   # what the measurement must come back with


# **Two sentences the outside review found larger than the tree** — paper 105,
# 23 October 2026, findings 2 and 3 of `docs/ATTACKS/CLAIMS_REVIEW_2026-10-23.md`.
#
# The front page said «works with any AI service, including local models» and
# the guide said «nothing is lost silently». Both were narrowed to what this
# tree measures — six services in one catalogue reached at an address you can
# change, and two copies of Z over one vault on one machine. Neither narrowing
# guards itself: a sentence of prose widens again by one word, and a translator
# can drop the half that carries the limit in one language with nobody the
# wiser. That is the same pair of faults the download pages answered with
# `data-fact=`, so this is the guide's trick a third time and not a control of
# its own:
#
#   * the corrected sentence is **marked on the element that serves it**, and
#     all three languages must mark it exactly once — so a page that loses the
#     fact is a page that disagrees with its siblings;
#   * the **retired wording is named, per language, and refused in the served
#     page.** A comment may still quote it — the comments above both sentences
#     do, because a correction whose reason nobody can read is a correction
#     nobody will keep — and `served()` is why that is allowed.
#
# Both halves are needed. Without the first, dropping the sentence is silent;
# without the second, writing «any AI service» back is.
THE_NARROWED = {
    'site/%s/index.html': ('which-services-z-speaks-to', {
        'en': 'works with any AI service',
        'de': 'arbeitet mit jedem KI-Dienst',
        'ar': 'يعمل مع أيّ خدمة ذكاء',
    }),
    'site/%s/guide/index.html': ('a-vault-write-is-not-lost-in-silence', {
        'en': 'nothing is lost silently',
        'de': 'nichts geht stillschweigend verloren',
        'ar': 'ولا يُفقَد شيءٌ في صمت',
    }),
}


def a_narrowed_sentence(rel_pattern, langs):
    """One corrected fact, in every language, and the old wording in none."""
    key, retired = THE_NARROWED[rel_pattern]
    bad = 0
    for lang in langs:
        rel = rel_pattern % lang
        if not os.path.exists(os.path.join(ROOT, rel)):
            continue   # the caller has already said so, in its own words
        page = served(read(rel))
        n = len(re.findall(r'data-fact="%s"' % re.escape(key), page))
        if n != 1:
            say('FAIL', '%s marks «%s» %d time(s), and each of the three carries it '
                        'once — a language has dropped a corrected sentence or doubled it'
                % (rel, key, n))
            bad = 1
        old = retired.get(lang)
        if old and old in page:
            say('FAIL', '%s serves «%s» again, and that wording was narrowed on '
                        '23 October because this tree does not measure it' % (rel, old))
            bad = 1
    return bad


# **What an in-app chat sends** — paper 108 §6, the owner, 24 October 2026, and
# a **condition of publishing** in his own word: we publish without the
# context-words memory, and the site says plainly what an in-app chat sends to
# the model.
#
# **And then he changed what it sends, the same morning.** Paper 110 (ed) makes
# a later question carry only the exchange before it — the previous question
# and its answer, protected — and never the document. So the sentence this
# gate holds is **not written yet**, and it will be taken from C-13's own line
# once that round has rewritten it. Not from a paraphrase of a paper: the
# register is where the measurement lives, and a site sentence written from
# anything else is a claim with nothing behind it.
#
# ## What stands today: the places, and the marker
#
# The three places the paper names, each in every language the site really
# has: the home page where in-app asking is described, the guide's chat
# section, and the privacy page, which does describe what reaches a provider.
# Each carries the fact's key once and, until the words arrive, the download
# section's own instrument — `class="provisional"`. That is deliberate reuse:
# a publishing run is red while one marker stands, a tree run reports the
# state, and the owner's condition therefore cannot be published around.
#
# ## The languages are discovered, not listed
#
# The paper asks for this fact in **en, de, ar and sv**, and the site has three
# language trees: there is no `site/sv/` in this tree at all. Hard-coding four
# would red on a page set nobody has written; hard-coding three would let a
# Swedish tree arrive one day without this sentence in it. So the languages are
# **read from the tree** — a directory with a guide in it is a language — and
# the day a fourth lands it must carry this fact on all three of its pages or
# this is red. The fourth language is a page set and not a sentence, and that
# is a paper of its own.
#
# ## Both directions, when the words come
#
# Filling them is one guarded edit: the prose on nine pages, the per-language
# needles in `THE_CHAT_SENDS_WORDS`, and the phrases of C-13's own limit in
# `C_13_MEASURES`. The gate refuses every half of that — words on the pages
# with nothing binding them to the claim, a binding with the markers still
# standing, a language that holds one half of the fact and not the other, and a
# year inside the element, because the sentence about what we are building next
# is an intent and an intent with a date on it is a promise.
THE_CHAT_SENDS = 'what-an-in-app-chat-sends'
THE_CHAT_SENDS_PLACES = ('index.html', 'guide/index.html', 'privacy/index.html')

# **The words, per language** — four short phrases out of each page's own
# sentence, which is `a_narrowed_sentence`'s doctrine one step further: a key
# says a language dropped the fact, and a needle says it dropped a **part** of
# it. The four are the four halves of the owner's «one payload, two sides of one
# law» (24 October 2026): what the app adds when it asks again (the exchange
# before it), what it never sends twice (the document, sent once), what stays
# where it was (nothing older is lost), and what the clipboard carries (the
# question, and nothing earlier). Each is a literal substring of the page it is
# checked against — taken out of the written prose rather than typed from
# memory, because an Arabic needle that differs from the page by one vowel mark
# reds on a page that is right, which is exactly what the first set of these
# did.
THE_CHAT_SENDS_WORDS = {
    'en': ('the exchange before it', 'sent once', 'nothing older is lost',
           'and nothing earlier'),
    'de': ('Austausch davor', 'einmal gesendet', 'nichts \u00c4lteres geht verloren',
           'und nichts davor'),
    'ar': ('\u0627\u0644\u062a\u0628\u0627\u062f\u0644\u064f \u0627\u0644\u0630\u064a \u0642\u0628\u0644\u0647',
           '\u062a\u064f\u0631\u0633\u064e\u0644 \u0645\u0631\u0651\u0629\u064b \u0648\u0627\u062d\u062f\u0629',
           '\u0648\u0644\u0627 \u064a\u064f\u0641\u0642\u064e\u062f',
           '\u0644\u0627 \u0634\u064a\u0621\u064e \u0642\u0628\u0644\u0647'),
}

# **The states are read off the register, not off this table.** Filling
# `C_13_AFTER` does not move the tree into state 1 — only the register does — and
# an empty `C_13_AFTER` is «the words are owed by another seat», not «nobody
# thought about it». The whole matrix, because this sentence has now crossed
# three rulings in one day:
#
#   | register    | C_13_AFTER | verdict                                        |
#   |-------------|------------|------------------------------------------------|
#   | 110's words | filled     | asserted phrase by phrase — PASS in both runs  |
#   | the line    | filled     | the binding is ready, the claim is not: a tree |
#   | before it   |            | run reports it, a publishing run is red        |
#   | the line    | empty      | the same, and the sentence says the words are  |
#   | before it   |            | owed — a publishing run is red                 |
#   | neither     | either     | red in both: nothing says what the pages are   |
#   |             |            | a reading of                                   |
#
# **`C_13_AFTER` is empty on purpose, and this is the third time in one day.**
# It was filled from ed's own line at `43d0fe0`; the owner then ruled on «Copy
# the chat» — it carries the payload as it stands, the current question and
# nothing earlier — and C-13 was written again. The pages carry that ruling
# now; the binding does not, because **a binding is a byte-for-byte quotation
# of the register** and ed's final line is not committed anywhere this tree can
# read: his branch tip is still `43d0fe0`, which is the line before it.
#
# Three phrases of a line that is being rewritten is a binding to a sentence
# that does not exist, which is what this gate refuses everywhere else — and
# the hour between the second ruling and the third is what that costs when it
# is guessed at.
#
# **Filled, by the hand that wrote the line** — paper 110's own seat, on the
# assembled tip where the register and the pages are in one tree. Three phrases,
# one per side of the owner's law, each read out of the committed limit line and
# not typed from memory:
#
#   * «the payload as it stands» — what a person carries to a model of their own,
#     which is the clipboard's whole half;
#   * «one exchange before it» — what the in-app door **adds** on top of that
#     same payload, and the words «one» and «before» are the fact: not two, and
#     not what came after;
#   * «sent once» — the document, which is what neither door sends twice.
#
# The fourth phrase the pages are checked by («nothing older is lost») is in the
# line too and is deliberately not here: these three are the binding, and a
# binding that quoted the whole sentence would red on any rewording of any part
# of it rather than on a change of the fact.
#
# Two of the lead's three candidates were byte-exact and one was not — «the
# exchange before it» is «the **one** exchange before it» in the register — which
# is the whole reason this table is read off the line instead of off a summary
# of it.
# **And `C_13_BEFORE` stays, although nothing in the tree matches it any more.**
# e2 asked for it to be retired on the merged line, and the reason was good: it
# is the recogniser for «this tree's register is still the line before 110», and
# state 2 was real for exactly one day — 24 October 2026, the hours when his
# branch carried the pages and ed's carried the register. On this line it is
# `False` for ever.
#
# It is kept because `False` for ever is what a regression detector looks like
# from the inside. The day this needle matches again, something has taken C-13
# back to «carries the earlier turns» — a revert, a bad merge, a resolved
# conflict that chose the older hunk — and the matrix answers «the binding is
# ready, the claim is not» instead of passing in silence. Three lines for that
# is a bargain, and the sentence that would have to be written after a silent
# pass is not.
C_13_BEFORE = 'carries the earlier turns'
C_13_AFTER = ('the payload as it stands', 'one exchange before it', 'sent once')


def the_language_trees():
    """Every language the site really has — a directory with a guide in it.

    Read from the tree rather than listed, so that a fourth language cannot
    arrive without the facts the three have, and a fourth that does not exist
    yet cannot red a gate for not carrying them.
    """
    site = os.path.join(ROOT, 'site')
    return tuple(sorted(
        name for name in os.listdir(site)
        if os.path.exists(os.path.join(site, name, 'guide', 'index.html'))))


# **The one condition on the code** — paper 113, the owner's licensing word of
# 24 October 2026: Apache 2.0 for anybody, companies included, with nobody to
# ask, and one condition — that a product built on this code says where the
# code came from.
#
# The site says that where it names the licence: the three home pages and the
# license page. What binds the page to the fact is **the NOTICE file itself**:
# §4(d) binds a redistributor to carry *our NOTICE's* attribution, so the
# attribution the pages quote has to be the one the file holds. The copyright
# line is read out of `NOTICE` and required in every keyed element — the day
# the owner changes the company, the year or the number, these pages red
# instead of quietly quoting a line that no longer exists.
#
# `scripts/gates.sh`'s own `G71` holds the other end: that the file is the
# owner's text byte for byte and that it travels inside every artefact. This
# one is about the sentence a visitor reads.
THE_ONE_CONDITION = ('the-one-condition-on-the-code', {
    'en': ('\u00a74(d)', 'does not mean advertising'),
    'de': ('\u00a74(d)', 'nicht gemeint ist Werbung'),
    'ar': ('\u00a74(d)', '\u0648\u0644\u064a\u0633 \u0627\u0644\u0645\u0642\u0635\u0648\u062f\u064e \u0627\u0644\u0625\u0639\u0644\u0627\u0646\u0627\u062a'),
})


def the_one_condition():
    """One licensing sentence, in every language, quoting the file that binds it."""
    key, halves = THE_ONE_CONDITION
    bad = 0
    notice = os.path.join(ROOT, 'NOTICE')
    if not os.path.exists(notice):
        say('FAIL', 'there is no NOTICE in the tree, and four pages tell a visitor that it is '
                    'what the one condition is carried by')
        return 1
    lines = open(notice, encoding='utf-8').read().split('\n')
    # The attribution itself, as the file holds it: «Copyright <year> <company>»
    # without the registration that follows it in brackets, because that is the
    # part a product's own notices are asked to carry.
    whose = next((l.split(' (')[0].strip() for l in lines if l.startswith('Copyright ')), '')
    if not whose:
        say('FAIL', 'NOTICE carries no «Copyright …» line, so there is nothing for the pages to '
                    'quote')
        return 1
    where = ['site/%s/index.html' % lang for lang in ('en', 'de', 'ar')]
    where.append('site/license/index.html')
    for rel in where:
        if not os.path.exists(os.path.join(ROOT, rel)):
            say('FAIL', '%s is not in the tree, and the licence is named on all four' % rel)
            bad = 1
            continue
        page = served(read(rel))
        held = re.findall(r'data-fact="%s"[^>]*>(.*?)</p>' % re.escape(key), page, re.S)
        if len(held) != 1:
            say('FAIL', '%s marks \u00ab%s\u00bb %d time(s) \u2014 every page that names the licence '
                        'carries the condition once, or a reader of one is told what a reader '
                        'of another is not' % (rel, key, len(held)))
            bad = 1
            continue
        inside = held[0]
        if whose not in inside:
            say('FAIL', '%s quotes an attribution that is not NOTICE\u2019s own \u00ab%s\u00bb \u2014 '
                        '\u00a74(d) binds what the file says and not what a page says it says'
                % (rel, whose))
            bad = 1
        if 'NOTICE' not in inside:
            say('FAIL', '%s states the condition and never names the file that carries it' % rel)
            bad = 1
        lang = rel.split('/')[1] if rel.startswith('site/') else 'en'
        for words in halves.get(lang if lang in halves else 'en', ()):
            if words not in inside:
                say('FAIL', '%s says the one condition and not \u00ab%s\u00bb \u2014 the clause it '
                            'rests on and the limit the owner accepted are both part of it'
                    % (rel, words))
                bad = 1
    if not bad:
        say('PASS', 'the one condition on the code stands on all four pages that name the '
                    'licence, each quoting NOTICE\u2019s own \u00ab%s\u00bb and naming the clause '
                    'that binds it' % whose)
    return bad


# **And what the two columns are** — the guide's own §h-columns paragraph, in
# this table because it is the same claim seen from the other end.
#
# It used to say «What an AI would receive stands beside the original, word for
# word, before anything is sent», and paper 110 made that wider than the tree:
# what an AI receives at a **later** question is that column *and* the exchange
# before it. The page says what the two columns **are** now — the request
# itself, not a preview of it, standing beside the original — and points at the
# section that says what travels, instead of answering it a second time in
# words that would drift from it.
#
# So the needles are the two halves of that division: the app's own sentence
# for what the column is, and the pointer that keeps «what travels» in exactly
# one place on this page.
THE_TWO_COLUMNS = ('what-the-two-columns-are', {
    'en': ('not a preview of it', '#h-ask'),
    'de': ('keine Vorschau davon', '#h-ask'),
    'ar': ('not a preview of it', '#h-ask'),
})


def what_an_in_app_chat_sends(tree_only):
    """The owner's condition of publishing: the places, bound, in every language."""
    key = THE_CHAT_SENDS
    bad = 0
    langs = the_language_trees()
    marked, provisional = 0, 0
    for lang in langs:
        for place in THE_CHAT_SENDS_PLACES:
            rel = 'site/%s/%s' % (lang, place)
            if not os.path.exists(os.path.join(ROOT, rel)):
                say('FAIL', '%s is not in the tree, and the three places this fact stands in '
                            'are the same three in every language' % rel)
                bad = 1
                continue
            page = served(read(rel))
            held = re.findall(
                r'<(?:p|li)([^>]*\bdata-fact="%s"[^>]*)>(.*?)</(?:p|li)>' % re.escape(key),
                page, re.S)
            if len(held) != 1:
                say('FAIL', '%s marks «%s» %d time(s) — every one of the three places carries '
                            'it once, in every language, or a reader of one page is told '
                            'something a reader of another is not' % (rel, key, len(held)))
                bad = 1
                continue
            marked += 1
            attrs, inside = held[0]
            waiting = 'provisional' in attrs
            provisional += 1 if waiting else 0
            if waiting:
                continue
            if not THE_CHAT_SENDS_WORDS:
                say('FAIL', '%s states what an in-app chat sends and nothing binds it to a '
                            'claim — the words were written and the gate was not told which '
                            'measurement they come from' % rel)
                bad = 1
                continue
            for words in THE_CHAT_SENDS_WORDS.get(lang, ()):
                if words not in inside:
                    say('FAIL', '%s says what a chat sends and not «%s» — a language that '
                                'drops a half of it promises a cost the program does not have'
                        % (rel, words))
                    bad = 1
            year = re.search(r'\b(?:19|20)\d\d\b', inside)
            if year:
                say('FAIL', '%s dates what we are building next («%s»), and an intent with a '
                            'date on it is a promise' % (rel, year.group(0)))
                bad = 1

    # **The claim's own end of the binding** — see `C_13_BEFORE`/`C_13_AFTER`
    # above for why there are three answers here and not two.
    limit = ''
    for block in read('docs/CLAIMS.md').split('\n## '):
        if block.startswith('C-13'):
            for line in block.split('\n'):
                if line.startswith('**The limit:**'):
                    limit = line
    if not limit:
        say('FAIL', 'docs/CLAIMS.md has no C-13 limit line, and the site\u2019s sentence about '
                    'what a chat sends is a reading of it')
        return 1
    after = bool(C_13_AFTER) and all(words in limit for words in C_13_AFTER)
    before = C_13_BEFORE in limit
    if not after and not before:
        # The register has moved and says neither line: either 110 reworded what
        # it already wrote, or somebody edited C-13 without reading the pages.
        # This is the state the other two exist to make impossible to pass.
        missing = [w for w in C_13_AFTER if w not in limit]
        say('FAIL', 'C-13\u2019s limit says neither what this tree measured nor what paper 110 '
                    'measures \u2014 it is missing %s \u2014 so nothing says what the site\u2019s '
                    'nine sentences are a reading of'
            % (', '.join('\u00ab%s\u00bb' % w for w in missing) or 'both lines'))
        return 1

    if provisional and provisional != marked:
        say('FAIL', '%d of %d places carry the words and the rest carry a marker: a page that '
                    'says what a chat sends beside one that does not is the state this marker '
                    'exists to prevent' % (marked - provisional, marked))
        bad = 1
    # **The columns paragraph, in the same pass** — one key per language, once,
    # and both halves of the division it keeps.
    col_key, col_halves = THE_TWO_COLUMNS
    for lang in langs:
        rel = 'site/%s/guide/index.html' % lang
        if not os.path.exists(os.path.join(ROOT, rel)):
            continue
        page = served(read(rel))
        held = re.findall(r'data-fact="%s"[^>]*>(.*?)</p>' % re.escape(col_key), page, re.S)
        if len(held) != 1:
            say('FAIL', '%s marks «%s» %d time(s) — the columns say what they are once on '
                        'each page, or a language is describing a screen the others are not'
                % (rel, col_key, len(held)))
            bad = 1
            continue
        for words in col_halves.get(lang, ()):
            if words not in held[0]:
                say('FAIL', '%s says what the two columns are and not «%s» — the column is the '
                            'request itself, and what travels beyond it belongs to the one '
                            'section that says so' % (rel, words))
                bad = 1
    if not bad:
        say('PASS', 'the two columns say what they are on %d pages, each quoting the app\u2019s own '
                    'sentence for the right-hand one and leaving what travels to the section '
                    'that measures it' % len(langs))

    if provisional and THE_CHAT_SENDS_WORDS:
        say('FAIL', 'the words are bound in the gate and %d place(s) still carry a marker — '
                    'the binding and the pages were filled in two different rounds' % provisional)
        bad = 1
    if bad:
        return bad
    if not provisional:
        if after:
            say('PASS', 'what an in-app chat sends stands in %d places — %s × %s — each bound '
                        'to C-13\u2019s own measured words and dating nothing'
                % (marked, ', '.join(langs), ', '.join(THE_CHAT_SENDS_PLACES)))
            return 0
        # The pages are 110's and this tree's register is the line before it.
        said = ('what an in-app chat sends stands in %d places (%s × %s) and states what paper '
                '110 measures, while this tree\u2019s C-13 is still the line before it and %s'
                % (marked, ', '.join(langs), ', '.join(THE_CHAT_SENDS_PLACES),
                   'the binding in C_13_AFTER is ready for the tip where both are in'
                   if C_13_AFTER else
                   'the words of the binding are owed: C-13 is being written a third time, '
                   'for the owner\u2019s ruling on what «Copy the chat» carries'))
        if tree_only:
            say('PASS', said)
            return 0
        say('FAIL', said + ' \u2014 a site may not go live saying what the tree it ships with '
                           'has not got')
        return 1
    # The state, in tree mode; the refusal, in a publishing run. The owner's
    # condition is not a thing a deploy may walk past.
    said = ('the place for what an in-app chat sends is built in %d of %d places (%s) and '
            'every one of them is still a marker: the words come from C-13 after paper 110 '
            'changes what a later question carries' % (provisional, marked, ', '.join(langs)))
    if tree_only:
        say('PASS', said)
        return 0
    say('FAIL', said + ' — the owner made this sentence a condition of publishing, so this '
                       'site is not ready until the words are on the pages')
    return 1


def the_interface():
    import importlib.util
    import json

    bad = 0
    l10n = pathlib.Path(ROOT, 'apps/flutter_app/lib/l10n')
    en = json.loads((l10n / 'app_en.arb').read_text(encoding='utf-8'))
    keys = [k for k in en if not k.startswith('@') and isinstance(en[k], str)]
    speaks = {}
    for arb in sorted(l10n.glob('app_*.arb')):
        code = arb.stem.replace('app_', '')
        if code == 'en':
            continue
        other = json.loads(arb.read_text(encoding='utf-8'))
        differ = sum(1 for k in keys if k in other and other[k] != en[k])
        if differ * 2 > len(keys):
            speaks[code] = differ
    if sorted(speaks) != sorted(TRANSLATED):
        say('FAIL', 'the lists that are really translated are %s, and the site is written for %s'
            % (sorted(speaks) or ['none'], sorted(TRANSLATED)))
        bad = 1

    spec = importlib.util.spec_from_file_location(
        'one_list', pathlib.Path(ROOT, 'scripts/check_the_one_list.py'))
    one = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(one)
    owed, owed_files = sum(one.OWED.values()), len(one.OWED)

    for lang in ('en', 'de', 'ar'):
        page = read('site', lang, 'index.html')
        for cls, want, what in (('owed', owed, 'sentences still owed'),
                                ('owed-files', owed_files, 'screens they are in')):
            found = re.findall(r'<span class="%s">([0-9]+)</span>' % cls, page)
            if not found:
                say('FAIL', 'site/%s/index.html states no «%s», so the %s is on no page a guard reads'
                    % (lang, cls, what))
                bad = 1
            elif any(int(x) != want for x in found):
                say('FAIL', 'site/%s/index.html says %s where the one list owes %d (%s)'
                    % (lang, ' and '.join(found), want, what))
                bad = 1
        for word in SPEAKS[lang]:
            if word not in page:
                say('FAIL', 'site/%s/index.html does not name «%s» among the languages the interface speaks'
                    % (lang, word))
                bad = 1
        for word in NOT_SPOKEN[lang]:
            if word in page:
                say('FAIL', 'site/%s/index.html names «%s», and that list is still the English source'
                    % (lang, word))
                bad = 1
    bad |= a_narrowed_sentence('site/%s/index.html', ('en', 'de', 'ar'))
    if not bad:
        say('PASS', 'the interface speaks what the lists really hold (%s), the three pages name the '
                    'services this tree really speaks to, and they owe the one list\u2019s own numbers: '
                    '%d sentences in %d screens'
            % (', '.join('%s %d values' % (c, n) for c, n in sorted(speaks.items())), owed, owed_files))
    return bad


# **The guide page** — paper 100, rule 83, 22 October 2026.
#
# One text in one place: the page lives here and the application carries a
# single line that opens it. A gate cannot read a page of prose for sense, so it
# holds the two things that can be known for certain and that would go wrong
# silently:
#
#   1. **every control the page names exists in the application.** The page
#      teaches a stranger where to press, quoting the program's own sentences —
#      «Original — local only», «Undo protection», «Save as PDF». A quoted
#      control that has been renamed or removed is a page teaching somebody
#      about a program that does not exist, and no visitor can tell. The keys
#      are read from a comment block rather than from the prose, because the
#      prose is translated three ways and the key is not: one block answers for
#      three pages.
#   2. **the address is one spelling.** The site's own «How it works» button and
#      the application's one address literal must be the same path, down to the
#      closing slash the pages call canonical. A link in two places is a link
#      one of the two places has already got wrong — the same defect this file
#      exists for, one floor down.
#
# And the pictures: the four are the open half of the item, so this does not ask
# for them. What it does ask is that no `<img>` on a guide page points at a file
# that is not in the tree, which is what turns the day they arrive from a hope
# into a measurement.
THE_GUIDE_SPEAKS = ('en', 'de', 'ar')
HOST = 'https://z-privacy.com'


def the_guide():
    import json

    bad = 0
    sets = {}
    shots = {}
    en_list = json.loads(read('apps/flutter_app/lib/l10n/app_en.arb'))
    for lang in THE_GUIDE_SPEAKS:
        rel = 'site/%s/guide/index.html' % lang
        if not os.path.exists(os.path.join(ROOT, rel)):
            say('FAIL', 'there is no %s, and the first page offers it' % rel)
            bad = 1
            continue
        page = read(rel)
        keys = re.findall(r'one-list-key:\s*([A-Za-z0-9_]+)', page)
        if not keys:
            say('FAIL', '%s names no control by its key, so nothing on it is '
                        'checked against the application' % rel)
            bad = 1
            continue
        doubled = sorted({k for k in keys if keys.count(k) > 1})
        if doubled:
            say('FAIL', '%s names %s twice, so the sets below are counted wrong'
                % (rel, ', '.join(doubled)))
            bad = 1
        for key in sorted(set(keys)):
            if key not in en_list:
                say('FAIL', '%s teaches the control «%s», and the application\u2019s '
                            'one list has no such sentence' % (rel, key))
                bad = 1
        sets[lang] = set(keys)
        # **The four pictures, and the state each of them is in.**
        #
        # They are named on all three pages whether they have been taken or
        # not, and a comment is not served — so the rule is about the pairing
        # rather than about either half alone:
        #
        #   * a file an `<img>` asks for and that is not in the tree is a
        #     broken image for every visitor;
        #   * a file that **is** in the tree and is only named inside a comment
        #     is a picture somebody took and nobody shows, which is how the
        #     open half of this item would quietly stay open.
        #
        # So the day the pictures arrive, uncommenting the block is not
        # optional — this says so.
        drawn = {src for src in re.findall(r'<img[^>]+src="([^"]+)"', served(page))
                 if 'assets/guide/' in src}
        named = set(re.findall(r'(\.\./\.\./assets/guide/[0-9A-Za-z._-]+)', page))
        shots[lang] = {os.path.basename(x) for x in named}
        for src in sorted(named):
            there = os.path.exists(
                os.path.normpath(os.path.join(ROOT, 'site', lang, 'guide', src)))
            if src in drawn and not there:
                say('FAIL', '%s draws %s, and there is no such file' % (rel, src))
                bad = 1
            if there and src not in drawn:
                say('FAIL', '%s has %s in the tree and does not show it — the picture '
                            'was taken and the page still hides it in a comment'
                    % (rel, src))
                bad = 1
    if len(sets) == len(THE_GUIDE_SPEAKS) and len(set(map(frozenset, sets.values()))) != 1:
        for lang in THE_GUIDE_SPEAKS[1:]:
            short = sets[THE_GUIDE_SPEAKS[0]] - sets[lang]
            extra = sets[lang] - sets[THE_GUIDE_SPEAKS[0]]
            if short or extra:
                say('FAIL', 'site/%s/guide/ names a different set of controls than the '
                            'English page: missing %s, extra %s'
                    % (lang, sorted(short) or 'none', sorted(extra) or 'none'))
        bad = 1

    # The same four pictures asked for by all three, taken or not.
    if len(shots) == len(THE_GUIDE_SPEAKS):
        if len(set(map(frozenset, shots.values()))) != 1:
            say('FAIL', 'the three guide pages do not name the same pictures: %s'
                % ' / '.join('%s %s' % (l, sorted(shots[l])) for l in THE_GUIDE_SPEAKS))
            bad = 1
        elif len(shots[THE_GUIDE_SPEAKS[0]]) != 4:
            say('FAIL', 'the guide names %d pictures and paper 100 asks for four'
                % len(shots[THE_GUIDE_SPEAKS[0]]))
            bad = 1

    # One spelling, read from both places that hold it.
    dart = read('apps/flutter_app/lib/core/the_system_browser.dart')
    # Read **loosely on purpose**, so that a changed host or a changed path is
    # compared and named rather than making the literal unfindable: a gate whose
    # only answer to a drift is «I cannot see it» has one branch that bites and
    # one that never can.
    literal = re.search(
        r"String theGuideAddress\(String code\) =>\s*'([^']*)\$\{[^}]*\}([^']*)'", dart)
    if not literal:
        say('FAIL', 'the application no longer builds the guide\u2019s address from one '
                    'literal, so there is no single spelling to compare')
        bad = 1
    speaks = re.search(r'const theGuideSpeaks = \{([^}]*)\}', dart)
    app_langs = tuple(sorted(re.findall(r"'([a-z]{2})'", speaks.group(1)))) if speaks else ()
    if app_langs != tuple(sorted(THE_GUIDE_SPEAKS)):
        say('FAIL', 'the application opens the guide in %s and the site serves it in %s'
            % (list(app_langs) or 'nothing', sorted(THE_GUIDE_SPEAKS)))
        bad = 1
    for lang in THE_GUIDE_SPEAKS:
        want = '/%s/guide/' % lang
        front = read('site/%s/index.html' % lang)
        if 'href="%s"' % want not in front:
            say('FAIL', 'site/%s/index.html does not send anybody to %s' % (lang, want))
            bad = 1
        if literal:
            app = literal.group(1) + lang + literal.group(2)
            if app != HOST + want:
                say('FAIL', 'the application opens «%s» for %s, and the site\u2019s own '
                            'address for that page is «%s»' % (app, lang, HOST + want))
                bad = 1
    bad |= a_narrowed_sentence('site/%s/guide/index.html', THE_GUIDE_SPEAKS)
    if not bad:
        # Counted once over the four files and not once per language: the
        # three pages ask for the same four, from one folder.
        every = set().union(*shots.values())
        waiting = sum(1 for shot in every
                      if not os.path.exists(os.path.join(
                          ROOT, 'site', 'assets', 'guide', shot)))
        say('PASS', 'the guide is one text in one place: %d controls named by key on three '
                    'pages, every one of them a sentence the application has, one spelling '
                    'of the address in the app and on the site, the write sentence carrying its '
                    'measured boundary on all three, and %d of %d pictures still to be taken'
            % (len(sets[THE_GUIDE_SPEAKS[0]]), waiting, len(every)))
    return bad


# **The download section** — paper 103, rules 81 and 81-أ, 22 October 2026.
#
# This is the one page of the site where a visitor is asked to run something,
# so it is the one page where a wrong sentence costs more than a correction.
# Three things can be known for certain about it, and all three go wrong
# silently:
#
#   1. **the fingerprint is the file's.** It is printed so that a stranger can
#      tell our installer from somebody else's, and nothing but the arithmetic
#      can say whether it still is: so the guard hashes the real file in the
#      deploy tree and compares. A page printing yesterday's fingerprint beside
#      today's file teaches a careful person to distrust the one honest check
#      they have.
#   2. **the names are names the build really writes.** `package_linux.sh` and
#      `zprivacy.iss` decide what the two files are called; the pages say it a
#      second time. A renamed output is a 404 on publishing day, and a 404 is
#      what a person sees after reading a paragraph about why the fingerprint
#      matters.
#   3. **every honest sentence is served in all three languages.** The
#      SmartScreen paragraph is the product of a measurement on the owner's own
#      machine, and a translation that quietly drops it leaves one language
#      promising nothing unusual will happen. The sentences are therefore
#      marked on the element that carries them — `data-fact="…"` — and the sets
#      are compared, which is the guide's trick one floor down: the key is not
#      translated, the prose is.
#
# And the **state** of the section, which is the fourth thing and the reason
# this cannot be left to an eye. Until the published build's own files and
# fingerprints land, every number on the pages is marked «(final hashes on
# publishing day)». While one of those markers stands, a publishing run is red:
# a half-filled download section may not go live, and the only way to make it
# green is to put the real files in the deploy tree and the real fingerprints
# on the pages.
THE_DOWNLOAD_SPEAKS = ('en', 'de', 'ar')

# The two files, and the other place each name is written down: the script that
# writes it. Checked in that direction on purpose — the build is the fact and
# the page is the claim.
THE_ARTEFACTS = {
    'zprivacy-v1-linux-x86_64.tar.gz': (
        'scripts/package_linux.sh', r'^NAME="([^"]+)"', '.tar.gz'),
    'zprivacy-v1-windows-x86_64-setup.exe': (
        'packaging/windows/zprivacy.iss', r'^OutputBaseFilename=(\S+)', '.exe'),
}

# Where a deploy serves them from, and therefore where the guard looks for
# them: `https://z-privacy.com/download/<file>`, rule 81's «from the site
# itself». Nothing in that folder is committed — `site/download/.gitignore`
# says why — so on an ordinary round there is nothing to hash, and the markers
# are what keeps that state from being mistaken for a finished page.
THE_DEPLOY_TREE = 'site/download'

# Every sentence the section must carry, with the reason it is one of them.
# A name is added here when the paper adds a fact, and the three pages then go
# red until all three say it.
THE_HONEST_SENTENCES = (
    ('the-linux-bundle', 'what the Linux archive is, and that nothing is installed'),
    ('verify-it-on-linux', 'the one line that checks the fingerprint, on Linux'),
    ('the-windows-installer', 'per user, in the person’s own folder, two clicks'),
    ('verify-it-on-windows', 'the one line that checks the fingerprint, on Windows'),
    ('windows-will-warn-you', 'the blue page, because nothing has signed the installer'),
    ('more-info-then-run-anyway', 'the way through it: two clicks, measured'),
    ('no-administrator-is-asked', 'PrivilegesRequired=lowest, and measured as such'),
    ('the-warning-comes-once', 'Windows takes the mark off the file after «Run anyway»'),
    ('untick-launch-to-start-it-yourself',
     'the installer’s last page starts the app with the box already ticked'),
    ('the-fingerprint-is-how-you-know',
     'with no signature, the fingerprint is the only thing that says the file is ours'),
    ('the-signed-version-follows', 'the MSIX and a signed installer wait for a real certificate — rule 81-أ'),
    ('the-claims-review-report', 'the outside model’s report belongs beside the download'),
)

# The owner's approved beta line, in the three languages it is approved in. It
# says the build is not released yet, which was true of a site that offered
# nothing to download and stops being true the moment this section carries the
# published build's own fingerprints. The guard does not change his sentence —
# it refuses the **pair**, and says so, because the day those two statements
# are served together is the day one of them is a lie.
NOT_RELEASED = {
    'en': 'not yet released',
    'de': 'noch nicht veröffentlicht',
    'ar': 'لم تُطلَق بعد',
}


def served(page):
    """The markup a browser gets: a comment is not served, and the guide's
    pictures taught that a guard reading one is a guard reading a draft."""
    return re.sub(r'<!--.*?-->', '', page, flags=re.S)


def a_commit_this_repository_holds(sha):
    """The terms page's rule, over the build line: a page naming a commit that
    was rebased away sends a reader to nothing.

    It answers None when git itself cannot be asked — a tree without history is
    not a page telling a lie, and a gate that cannot tell those two apart is a
    gate that goes red for the wrong cause."""
    import subprocess
    try:
        subprocess.check_output(['git', '-C', ROOT, 'rev-parse', 'HEAD'],
                                stderr=subprocess.DEVNULL)
    except Exception:
        return None
    return subprocess.call(['git', '-C', ROOT, 'cat-file', '-e', sha + '^{commit}'],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL) == 0


def the_download(tree_only):
    import hashlib

    bad = 0
    facts, shas, builds, markers = {}, {}, {}, {}
    no_history = False
    wanted = {name for name, _ in THE_HONEST_SENTENCES}

    # The names, against the scripts that write the files.
    for artefact, (where, pattern, suffix) in sorted(THE_ARTEFACTS.items()):
        src = read(where)
        found = re.search(pattern, src, re.M)
        if not found:
            say('FAIL', '%s no longer says what it names its output, so «%s» is '
                        'a name nothing in this tree stands behind' % (where, artefact))
            bad = 1
        elif found.group(1) + suffix != artefact:
            say('FAIL', '%s writes «%s» and the download pages offer «%s»'
                % (where, found.group(1) + suffix, artefact))
            bad = 1

    for lang in THE_DOWNLOAD_SPEAKS:
        rel = 'site/%s/download/index.html' % lang
        if not os.path.exists(os.path.join(ROOT, rel)):
            say('FAIL', 'there is no %s, and rule 81 says the download comes from '
                        'the site itself in three languages' % rel)
            bad = 1
            continue
        page = served(read(rel))

        offered = set(re.findall(r'href="/download/([^"]+)"', page))
        for artefact in sorted(set(THE_ARTEFACTS) - offered):
            say('FAIL', '%s does not offer %s' % (rel, artefact))
            bad = 1
        for extra in sorted(offered - set(THE_ARTEFACTS)):
            say('FAIL', '%s offers %s, which is not one of the two files this '
                        'release carries' % (rel, extra))
            bad = 1

        printed = {}
        for name, value in re.findall(r'data-of="([^"]+)"[^>]*>([^<]*)<', page):
            value = value.strip()
            if not re.fullmatch(r'[0-9a-f]{64}', value):
                say('FAIL', '%s prints «%s» as the fingerprint of %s, and a sha256 is '
                            '64 hexadecimal characters' % (rel, value[:20], name))
                bad = 1
                continue
            printed[name] = value
        for artefact in sorted(offered & set(THE_ARTEFACTS)):
            if artefact not in printed:
                say('FAIL', '%s offers %s and prints no fingerprint for it'
                    % (rel, artefact))
                bad = 1
        shas[lang] = printed

        # **Which build is this?** — the question a person who has the file
        # cannot answer from its name, and the one the old gate in `gates.sh`
        # has asked of a download page since the first one existed. The commit
        # is printed beside the fingerprint, checked against this repository's
        # own history, and it is what lets a reader match the page against the
        # `BUILD-INFO.txt` inside the archive.
        #
        # The two files may name two commits while they are stand-ins — this
        # machine builds no `.exe` — and the published pair comes from one
        # green run. So what is held here is that each name is a real commit
        # and that the three languages print the same one.
        from_commit = {}
        for name, value in re.findall(r'data-built-from="([^"]+)"[^>]*>([^<]*)<', page):
            value = value.strip()
            if not re.fullmatch(r'[0-9a-f]{7,40}', value):
                say('FAIL', '%s says %s was built from «%s», and that is not a '
                            'commit' % (rel, name, value[:20]))
                bad = 1
                continue
            held = a_commit_this_repository_holds(value)
            if held is None:
                no_history = True
            elif not held:
                say('FAIL', '%s says %s was built from %s, and this repository has no '
                            'such commit' % (rel, name, value))
                bad = 1
            from_commit[name] = value
        for artefact in sorted(offered & set(THE_ARTEFACTS)):
            if artefact not in from_commit:
                say('FAIL', '%s offers %s and does not say which build it is'
                    % (rel, artefact))
                bad = 1
        builds[lang] = from_commit

        said = {}
        for tag, key, inner in re.findall(
                r'<(\w+)[^>]*data-fact="([^"]+)"[^>]*>(.*?)</\1>', page, re.S):
            said[key] = re.sub(r'<[^>]+>', '', inner).strip()
        for key in sorted(wanted - set(said)):
            say('FAIL', '%s says nothing for «%s» — %s'
                % (rel, key, dict(THE_HONEST_SENTENCES)[key]))
            bad = 1
        for key in sorted(set(said) - wanted):
            say('FAIL', '%s carries the sentence «%s», which this section does not '
                        'know about: a fact the other two languages do not say'
                % (rel, key))
            bad = 1
        for key, text in sorted(said.items()):
            if len(text) < 40:
                say('FAIL', '%s marks «%s» on %d characters, which is not a sentence '
                            'anybody can read' % (rel, key, len(text)))
                bad = 1
        facts[lang] = set(said)
        markers[lang] = len(re.findall(r'class="[^"]*\bprovisional\b[^"]*"', page))

        # **Every address this page sends a reader to answers.** The section
        # holds a slot for the outside model's report, and the day somebody
        # drops a link into that line it must point at something: a dead link
        # on the one page that asks a reader to run a program is worse than an
        # empty slot, which at least says what it is. Nothing else on this site
        # checks a root-relative href — the network loop asks about absolute
        # ones, and the privacy and terms pages about the files they name in a
        # code span — so the pages that print fingerprints get it here.
        #
        # The two artefacts are left out: they are not in the tree until
        # publishing day, which is the markers' business and measured above.
        for href in sorted(set(re.findall(r'href="(/[^"#]*)"', page))):
            if href.startswith('/download/'):
                continue
            target = os.path.join(ROOT, 'site', href.strip('/'))
            there = (os.path.isfile(os.path.join(target, 'index.html'))
                     if href.endswith('/') else os.path.isfile(target))
            if not there:
                say('FAIL', '%s sends a reader to %s, and there is no such page in '
                            'the tree' % (rel, href))
                bad = 1

        front = read('site/%s/index.html' % lang)
        if 'href="/%s/download/"' % lang not in front:
            say('FAIL', 'site/%s/index.html does not send anybody to /%s/download/'
                % (lang, lang))
            bad = 1

    # One language may not be shorter than another, and one may not print a
    # different fingerprint for the same file: a reader who checks the German
    # page is owed what a reader of the English page is owed.
    if len(facts) == len(THE_DOWNLOAD_SPEAKS):
        for lang in THE_DOWNLOAD_SPEAKS[1:]:
            short = facts[THE_DOWNLOAD_SPEAKS[0]] - facts[lang]
            extra = facts[lang] - facts[THE_DOWNLOAD_SPEAKS[0]]
            if short or extra:
                say('FAIL', 'site/%s/download/ says a different set of things than the '
                            'English page: missing %s, extra %s'
                    % (lang, sorted(short) or 'none', sorted(extra) or 'none'))
                bad = 1
        for artefact in sorted(THE_ARTEFACTS):
            spellings = {shas[l].get(artefact) for l in THE_DOWNLOAD_SPEAKS}
            if len(spellings) != 1:
                say('FAIL', 'the three pages print %d different fingerprints for %s'
                    % (len(spellings), artefact))
                bad = 1
            named = {builds[l].get(artefact) for l in THE_DOWNLOAD_SPEAKS}
            if len(named) != 1:
                say('FAIL', 'the three pages name %d different builds for %s: %s'
                    % (len(named), artefact,
                       ', '.join(sorted(x or 'nothing' for x in named))))
                bad = 1
        if len(set(markers.values())) != 1:
            say('FAIL', 'the three pages carry %s provisional markers: a language whose '
                        'numbers are marked and one whose are not'
                % ' / '.join('%s %d' % (l, markers[l]) for l in THE_DOWNLOAD_SPEAKS))
            bad = 1

    # **The arithmetic.** Every file that is in the deploy tree is hashed and
    # compared, in every mode: a file that is there is a file a visitor can
    # download, and a wrong number beside it is wrong today and not on
    # publishing day.
    here, verified = {}, 0
    for artefact in sorted(THE_ARTEFACTS):
        path = os.path.join(ROOT, THE_DEPLOY_TREE, artefact)
        if not os.path.exists(path):
            continue
        digest = hashlib.sha256()
        with open(path, 'rb') as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b''):
                digest.update(chunk)
        here[artefact] = digest.hexdigest()
        claimed = {shas[l].get(artefact) for l in shas}
        if claimed != {here[artefact]}:
            say('FAIL', '%s/%s hashes to %s, and the pages print %s'
                % (THE_DEPLOY_TREE, artefact, here[artefact],
                   ' and '.join(sorted(x or 'nothing' for x in claimed))))
            bad = 1
        else:
            verified += 1

    standing = sum(markers.values())
    # **The publishing bar.** A round on a workstation is not a publishing run:
    # the files are built by two jobs on two platforms and land in the deploy
    # tree by hand, so `--tree-only` reports the state and does not fail on it.
    # Without it, this script is being asked whether the site can go live, and
    # the answer is no while any of it is provisional.
    if not tree_only:
        if standing:
            say('FAIL', '%d «(final hashes on publishing day)» markers still stand, so '
                        'this section is not the published build’s: put the final '
                        'files in %s/ and their fingerprints on the three pages, then '
                        'take the markers out' % (standing, THE_DEPLOY_TREE))
            bad = 1
        for artefact in sorted(THE_ARTEFACTS):
            if artefact not in here:
                say('FAIL', 'the pages offer %s and %s/ does not hold it, so the link '
                            'is a 404 and the fingerprint beside it is about nothing'
                    % (artefact, THE_DEPLOY_TREE))
                bad = 1

    # The pair the site may not serve at once. It is not about the mode: the
    # moment the markers are gone, these pages claim to be the published
    # build's, and the first screen still saying the build is not released is
    # one of the two sentences being false. His word, not a guard's — but it
    # cannot be forgotten this way.
    if not standing and len(facts) == len(THE_DOWNLOAD_SPEAKS):
        for lang in THE_DOWNLOAD_SPEAKS:
            for rel in ('site/%s/index.html' % lang, 'site/index.html'):
                line = re.search(r'<p class="beta"[^>]*>(.*?)</p>', read(rel), re.S)
                if line and NOT_RELEASED[lang] in line.group(1):
                    say('FAIL', '%s still says the build is «%s» while /%s/download/ '
                                'offers the published build: one of the two sentences '
                                'needs the owner’s word before this deploys'
                        % (rel, NOT_RELEASED[lang], lang))
                    bad = 1

    if no_history:
        say('PASS', 'the builds the pages name were not checked against the history, '
                    'because git cannot be asked in this tree')
    if not bad:
        say('PASS', 'the download is one section in three languages: %d files named by '
                    'the scripts that build them and by the commit they came from, %d '
                    'honest sentences on each page, %d of %d fingerprints measured '
                    'against the file in %s/, and %d markers still saying the numbers '
                    'are a development build’s'
            % (len(THE_ARTEFACTS), len(wanted), verified, len(THE_ARTEFACTS),
               THE_DEPLOY_TREE, standing))
    return bad


def main(tree_only=False):
    lits = dart_strings()
    if len(lits) < 200:
        say('FAIL', 'only %d strings were read out of the app, so nothing was really compared' % len(lits))
        return 1
    bad = (crates() | fonts() | glossary(lits) | path(lits) | the_interface()
           | the_guide() | what_an_in_app_chat_sends(tree_only)
           | the_one_condition() | the_download(tree_only))
    print()
    print('every number on the site has a deed behind it' if not bad
          else 'A NUMBER ON THE SITE HAS NO DEED BEHIND IT')
    return bad


if __name__ == '__main__':
    # `--tree-only` is handed down by `check_site.sh`, and means the same thing
    # here as it does there: everything but what only the hand that publishes
    # can answer. The two artefacts are built by two jobs on two platforms and
    # land in the deploy tree by hand, so their absence is a state on a
    # workstation and a refusal on a publishing run.
    sys.exit(main('--tree-only' in sys.argv[1:]))
