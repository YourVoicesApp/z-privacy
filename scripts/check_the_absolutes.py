#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Every absolute on the FAQ, and the evidence that covers it.

The owner, 26 October 2026, after reading all 25 answers: «a consistency test
of the promises across the answers». An answer that says **always**, **never**,
**nothing leaves** or anything of that shape is making a claim about *every*
case, and a test that measured one request, one door or one build does not
cover every case. Where the two do not match, the sentence has to be qualified
— and the one thing that must never happen is an absolute arriving in the text
without anybody noticing it is one.

**How it works, and why it is a register rather than a cleverer scan.** The
script finds absolute words mechanically and then refuses any it has not been
told about. Every hit must appear in `REGISTER` with one of two verdicts:

  * **a proof** — the claim (`C-NN`), test or gate that covers the absolute as
    stated, or
  * **`QUALIFIED`** — the sentence carries its own limit in the same breath, so
    the absolute is bounded by the words around it.

Nothing is allowed through for being obviously fine. «No account», «only the
protected version», «every door» each had to be looked at once and written
down, and the cost of that is a line in a table; the thing it buys is that a
**new** absolute cannot enter the file quietly. It also reds when a registered
phrase disappears, so a sentence cannot be softened while this file goes on
claiming it was checked.

It reads `docs/faq-review.md` today and the published FAQ pages when they
exist: the same absolutes have to survive translation, and a translator who
drops a qualifier is exactly the accident this guards against.

**What passing means, and what it does not** — the owner, 27 October 2026,
adopting this as a publishing gate. It is an **editorial** gate. Green means
every absolute on the page has been found and classified, and that no new one
arrived unnoticed. It does **not** mean the evidence named beside each one is
sufficient, and it is not a security certificate: whether `C-11` really covers
the sentence that cites it is the job of the tests and of the engineering
review, and this script cannot and does not ask it. A register that was
mistaken for a proof would be worse than no register, so the distinction is
written here rather than left to be inferred from a green line.

  python3 scripts/check_the_absolutes.py        # the exit status is the verdict
"""
import io
import pathlib
import re
import sys

QUALIFIED = 'QUALIFIED'


def ident(n, phrase, seen=None):
    """A stable name for one absolute, **derived from its own words**.

    Not a number in a column: an id taken from the English phrase changes the
    moment the phrase changes, so a sentence that is reworded loses its
    mirrors in the other languages and the check reds. That coupling is the
    point — a qualifier quietly softened in English must not go on being
    reported as translated faithfully.
    """
    words = re.findall(r'[a-z0-9]+', phrase.lower())
    skip = {'the', 'a', 'an', 'of', 'to', 'in', 'it', 'is', 'and', 'that',
            'this', 'for', 'on', 'no', 'not', 'so'}
    base = 'q%d-%s' % (n, '-'.join([w for w in words if w not in skip][:3]))
    if seen is None:
        return base
    name, k = base, 1
    while name in seen:
        k += 1
        name = '%s-%d' % (base, k)
    seen.add(name)
    return name

# The absolute is not about Z Privacy's behaviour at all — it is about the law,
# about somebody else's product, or about the world — so no test of ours could
# cover it and none is claimed. It still has to be written down, because the
# reason an absolute is safe is exactly the thing a later reader will want.
NOT_OURS = 'NOT_OURS'

# The shapes that claim every case. Deliberately short: this is the owner's
# list — «always», «never», «nothing leaves» and their equivalents — and not
# every strong word in English. A longer list would drown the register and
# teach the next reader to skim it.
ABSOLUTE = re.compile(
    r'\b(always|never|nothing|nobody|no one|none|neither|impossible|cannot|can’t|'
    r'guarantees?|guaranteed|ensures?|entirely|completely|wholly|'
    r'every|everything|all of|any means|any other|any kind|no other|only|at all)\b',
    re.I)

# question -> ((phrase as it appears, verdict), ...)
# The phrase is matched case-insensitively and must be a substring of that
# question's answer. One line per absolute, and it is meant to be read.
REGISTER = {
    2: (("the only reliable source is the provider's own current terms", NOT_OURS),
        ("Z Privacy changes neither",
         "docs/THE_PROVIDERS.md — Z alters, evades and comments on no "
         "provider's terms, and takes no position on them")),
    3: (("only your machine can reverse it",
         "C-06 — the mapping is the vault, and the written file holds none of "
         "the names it was taught (the_vault_file_says_nothing.rs); and the "
         "next sentence says what this does NOT mean"),),
    4: (("none of them substitutes for another", NOT_OURS),
        ("asks whether the model needs a given value at all", NOT_OURS)),
    5: (("only where the person can no longer be identified", NOT_OURS),
        ("a standard that takes account of what others might reasonably do, "
         "and not only of what you would do", NOT_OURS),
        ("with every name removed can still be about one identifiable person",
         QUALIFIED)),
    6: (("everything else stays in the text exactly as you approved it",
         "z_core/tests/round_trip.rs:59 asserts the safe payload equals the "
         "original sentence with only the chosen values swapped, character for "
         "character"),),
    7: (("allow an external model to see a matter at all", NOT_OURS),),
    8: (("whether to process it with an external model at all", NOT_OURS),),
    9: (("a PDF carries every page", NOT_OURS),),
    10: (("a local model needs no key at all",
          "C-17 — truthfulness_regressions.rs::lie_a_keyless_login_claims_a_key "
          "measures the keyless local login with the vault open"),
         ("accepted only for a **literal** loopback IP address, never for a "
          "name like \u00ablocalhost\u00bb, so a hosts file cannot be what decides "
          "that plaintext is safe",
          "is_loopback_url in z_core/src/providers/http.rs, measured by "
          "plain_http_is_refused_unless_the_host_is_a_literal_loopback_address"),
         ("it says nothing about what other programs on your computer do",
          QUALIFIED)),
    11: (("nothing leaves while a suggestion is unanswered",
          "C-11 (nothing_leaves_while_a_word_waits.rs); the refusal is one "
          "function that gate G28 reads, asked of every door gate G36 counts "
          "from the source"),),
    12: (("not a proof that no other program or path exists", QUALIFIED),),
    13: (("every token that chat has carried turns back into its name",
          "C-13 — the_chat_remembers.rs, "
          "the_copy_is_the_current_point_and_still_brings_home_a_name_from_the_first_turn"),),
    14: (("the interface cannot open a socket at all, and no Z Privacy address "
          "appears anywhere in it \u2014 so the only address this program is "
          "built to speak to",
          "C-03 — one HTTP client (G1), the interface cannot open a socket "
          "(G5), one reader behind the gateway (G16), and no Z Privacy address "
          "in the tree. Shape checks over the source, which is what \u00abis "
          "built to\u00bb says; C-04 stays unproven for the running case"),
         ("a settings file that never holds your work",
          "z_core/tests/zcfg_leak.rs searches the one unencrypted file for the "
          "names it was taught"),
         ("nothing is written to the system's temporary directory",
          QUALIFIED),
         ("no log file is written at all",
          "governed by the sentence's own lead-in, «By that same reading of "
          "the source»: the core carries no println!, no eprintln! and no "
          "logging crate outside its tests")),
    15: (("a passphrase that never leaves the machine",
          "C-06 and gate G8 — no function in the whole contract returns a key "
          "or a passphrase"),
         ("finds none", "z_core/tests/the_vault_file_says_nothing.rs"),
         ("only as strong as the passphrase you choose", QUALIFIED),
         ("refuses to write if it cannot be",
          "z_core/src/secure_file.rs and its own tests")),
    16: (("The vault cannot be opened", "C-06 and gate G8"),
         ("no recovery mechanism of any kind",
          "C-06 — the passphrase is never stored; gate G8, no function in "
          "the whole contract returns a key or a passphrase"),
         ("and nothing on our side could recover the vault without the "
          "passphrase",
          "C-06 — the passphrase is never stored; gate G8"),
         ("Nobody holds a copy of this", "the shipped sentence, key "
          "thereIsNoWayBack; the claim behind it is C-06"),
         ("the passphrase never leaves this device", "C-06, gate G8"),
         # The same absolute twice: once in our words and once inside the
         # shipped sentence the answer quotes. Both are registered, because
         # a quotation is still a thing this page says.
         ("and nothing on our side could recover the vault without it",
          "the shipped sentence, key thereIsNoWayBack; C-06 and gate G8")),
    17: (("a service that answers neither shape is not reached by this build",
          "C-17 — the_model_gateway.rs; five of the six go out through "
          "chat/completions and Anthropic has its own path"),
         ("a model on your own computer needs no key at all",
          "C-17 — the same keyless login as Q10"),
         ("Every connection is made at an address you can change",
          "C-17 — the_bundle_of_six.rs; every base address comes from the "
          "person's own login"),),
    18: (("who agreed to nothing with your provider", NOT_OURS),),
    19: (("every value you have taught it is matched wherever it appears",
          QUALIFIED),
         ("All of that depends on two things upstream of any rule", QUALIFIED),
         ("nothing leaves while a suggestion is unanswered",
          "C-11; gate G28 asks it of every door gate G36 finds"),
         ("is asked of every door that takes text out of the app",
          "gate G36 counts the doors from what the functions do, not from a "
          "list — which is why the count has moved twice")),
    21: (("nothing to subscribe to",
          "an absence, stated as one: no price, no billing code and no "
          "purchase path anywhere in the tree"),
         ("on your own computer costs nothing at all",
          "C-17 — a local model reports connected with no credential "
          "(truthfulness_regressions.rs::lie_a_keyless_login_claims_a_key)")),
    22: (("ask nobody", NOT_OURS),),
    23: (("lists every claim with the same four lines each",
          "gate G56 refuses a section missing one of its four lines"),
         ("the interface cannot open a socket",
          "gate G5 — and this very sentence is explaining what a shape check "
          "is, so the reader is told its kind as they read it"),
         ("that every door obeys a law", "gates G28 and G36")),
    24: (("nothing has signed this installer",
          "site/en/download/index.html, data-fact=windows-will-warn-you; the "
          "Windows job deletes an unsigned package rather than hand it over "
          "(C-14), and the installer carries no signature by construction"),
         ("it says nothing about who published the file", QUALIFIED)),
    25: (("nothing is collected on this site",
          "scripts/check_site.sh refuses a handler, a cookie, a counter or any "
          "script but a declared data block, and there is no form on any page"),),
}


# ===================================================================
# The other two languages: a MIRROR check, not a second register.
#
# **Why it is shaped differently from the English one, said plainly.** German
# needs `kein` and `jede` for ordinary negation and quantification where
# English says «not» and «each», so a register of every one of them would be
# a page of grammar nobody reads — and a register that trains its reader to
# skim is worse than none. What matters in a translation is not that every
# absolute is classified again; it is that **the English absolute, with its
# qualifier, is still there**. So each English id names the words that carry
# it in the German and in the Arabic, and the check asks two questions:
#
#   1. is every English absolute still carried in each language? A translator
#      who tightens «only as strong as the passphrase you choose» for flow
#      breaks the match and this reds.
#   2. does a language introduce a **strong** absolute of its own that no
#      English id accounts for? That is the other direction of the same
#      fault, and the narrow vocabulary below is what it looks for.
#
# **What it does not do**, for the same reason the English one says so: it
# sees words, not meanings. Whether the German sentence *means* what the
# English one means is a judgement; for Arabic the owner is the reader.

MIRROR_DE = {
 'q2-only-reliable-source': "die einzig verlässliche Quelle sind daher die aktuellen Bedingungen des Anbieters selbst",
 'q3-only-your-machine': "also kann nur Ihr Rechner sie umkehren",
 'q4-none-them-substitutes': "Drei getrennte Dinge, und keines ersetzt ein anderes",
 'q5-only-where-person': "Als anonym gelten Daten nur dort, wo die Person mit Mitteln, die nach allgemeinem Ermessen wahrscheinlich genutzt werden, nicht mehr identifiziert werden kann",
 'q5-standard-takes-account': "ein Maßstab, der berücksichtigt, was andere vernünftigerweise tun könnten, und nicht nur, was Sie selbst tun würden",
 'q5-with-every-name': u"Und ein Text, aus dem jeder Name entfernt wurde, kann immer noch von einer identifizierbaren Person handeln — ein Arztbrief über eine einzige Patientin ist das übliche Beispiel.",
 'q6-everything-else-stays': u"Ersetzt wird, was Z Privacy erkannt hat oder was Sie markiert haben; alles andere bleibt genau so im Text, wie Sie ihn freigegeben haben — deshalb gibt es den Schritt der Durchsicht, und deshalb wird er Ihnen gezeigt, bevor etwas gesendet wird.",
 'q9-pdf-carries-every': u"Bemerkenswert ist, dass ein PDF jede Seite mitnimmt, auch die, zu denen Sie keine Hilfe brauchten.",
 'q10-accepted-only-literal': "Einfaches `http` wird nur für eine **buchstäbliche** Loopback-IP-Adresse angenommen, nie für einen Namen wie «localhost»",
 'q10-says-nothing-about': "über das, was andere Programme auf Ihrem Rechner tun, sagt sie nichts",
 'q11-nothing-leaves-while': "nichts geht hinaus, solange ein Vorschlag unbeantwortet ist",
 'q12-proof-other-program': "kein Beweis, dass kein anderes Programm und kein anderer Weg existiert",
 'q13-every-token-chat': u"Innerhalb der Anwendung wird die Antwort wiederhergestellt, während sie eintrifft; haben Sie die Frage selbst zu einem Modell getragen, holt «Eine Antwort hinzufügen» den Text zurück, und jedes Kennzeichen, das dieser Verlauf getragen hat, wird wieder zu seinem Namen.",
 'q14-interface-cannot-open': "die Oberfläche kann überhaupt keinen Socket öffnen, und nirgends in ihm steht eine Z-Privacy-Adresse — die einzige Adresse also, für die dieses Programm gebaut ist",
 'q14-settings-file-never': u"Auf Ihrem eigenen Rechner schreibt es, **in diesem Build und aus seinem Quelltext gelesen, nicht an einer laufenden Installation beobachtet**, einen bekannten Satz von Dateien und keine anderen: den verschlüsselten Tresor, eine verschlüsselte Datei je Sitzung, eine Sperre daneben und eine Einstellungsdatei, die niemals Ihre Arbeit enthält — dazu die zwei Dokumente, die Sie ausdrücklich verlangen, eine geschützte Kopie und ein wiederhergestelltes einfaches PDF.",
 'q14-nothing-written-system': "in das temporäre Verzeichnis des Systems wird nichts geschrieben",
 'q15-passphrase-never-leaves': "einer Passphrase, die das Gerät nie verlässt",
 'q15-finds-none': "und findet keinen",
 'q15-only-as-strong': "Die Verschlüsselung ist nur so stark wie die Passphrase, die Sie wählen",
 'q15-refuses-write-if': "der Kern weigert sich zu schreiben, wenn das nicht möglich ist",
 'q16-vault-cannot-be': "Der Tresor lässt sich nicht öffnen",
 'q16-nothing-our-side': "nichts auf unserer Seite könnte den Tresor ohne die Passphrase wiederherstellen",
 'q16-nobody-holds-copy': "Niemand hat eine Kopie davon",
 'q16-passphrase-never-leaves': "die Passphrase verlässt dieses Gerät nie",
 'q16-nothing-our-side-2': u"Niemand hat eine Kopie davon, und es gibt kein Zurücksetzen — die Passphrase verlässt dieses Gerät nie, und auf unserer Seite könnte nichts den Tresor ohne sie wiederherstellen.»",
 'q17-every-connection-made': u"Jede Verbindung wird an einer Adresse hergestellt, die Sie ändern können, und ein Modell auf Ihrem eigenen Rechner braucht überhaupt keinen Schlüssel.",
 'q18-who-agreed-nothing': "die mit Ihrem Anbieter nichts vereinbart haben",
 'q19-every-value-you': u"Die Regeln für IBAN und BIC sind an kein Sprachpaket gebunden, hängen also nicht davon ab, in welcher Sprache ein Dokument ist; die Sprachsätze fügen E-Mail-Adressen, Telefonnummern, Steuer- und Sozialversicherungsnummern, Kunden-, Vertrags- und Personalnummern, Geburtsdaten, Personen, Firmen und Adressen hinzu — und jeder Wert, den Sie ihm beigebracht haben, wird überall dort erkannt, wo er vorkommt.",
 'q19-all-depends-two': u"All das hängt von zwei Dingen ab, die jeder Regel vorausgehen: dass der Text so bei der Prüfung ankam, wie er auf der Seite zu lesen ist, und dass der Wert in einer Form geschrieben ist, die die Regeln beschreiben.",
 'q19-nothing-leaves-while': "«nichts geht hinaus, solange ein Vorschlag unbeantwortet ist»",
 'q19-asked-every-door': u"Was sie nicht sicher einordnen kann, wird zu einem Vorschlag, der auf Ihr Wort wartet, und das Gesetz «nichts geht hinaus, solange ein Vorschlag unbeantwortet ist» wird an jeder Tür gestellt, die Text aus der Anwendung trägt: an ein Modell senden, den geschützten Text kopieren, den Verlauf kopieren und ein geschütztes PDF speichern.",
 'q21-nothing-subscribe': "nichts zu abonnieren",
 'q21-your-own-computer': "ein Modell, das auf Ihrem eigenen Rechner läuft, kostet überhaupt nichts",
 'q22-ask-nobody': "und fragen Sie niemanden",
 'q23-lists-every-claim': u"`docs/CLAIMS.md` führt jede Aussage mit denselben vier Zeilen auf: den Satz, den wir tatsächlich zeigen, was er **nicht** abdeckt, den Test oder die Prüfung, die ihn belegt, und den Befehl, den Sie selbst ausführen.",
 'q23-interface-cannot-open': "dass die Oberfläche keinen Socket öffnen kann",
 'q23-every-door-obeys': "dass jede Tür einem Gesetz folgt",
 'q24-nothing-has-signed': u"Unter Windows zeigt der erste Start eine blaue Seite «Der Computer wurde durch Windows geschützt», weil dieses Installationsprogramm von nichts signiert ist: Diese Seite bedeutet, dass Windows keine Grundlage hat, die Datei als vertrauenswürdig zu behandeln, und nicht, dass es sie geprüft und für sicher oder unsicher befunden hätte.",
 'q24-says-nothing-about': "Über den Herausgeber der Datei sagt er nichts",
 'q25-nothing-collected-site': "auf dieser Website wird nichts erhoben",
 'q2-z-privacy-changes': u"Z Privacy ändert an beidem nichts; es ändert, was in dem Text steht, den Sie senden.",
 'q4-asks-whether-model': u"c) fragt, ob das Modell einen bestimmten Wert überhaupt braucht — das ist die Frage, bei der ein Werkzeug wie Z Privacy hilft.",
 'q7-allow-external-model': u"Z Privacy entscheidet nicht, ob Ihr Berufsrecht es überhaupt erlaubt, dass ein fremdes Modell ein Mandat sieht — diese Beurteilung ist Ihre und sie unterscheidet sich je nach Rechtsordnung.",
 'q8-whether-process-with': u"9, und Personaldaten bringen eigene Pflichten mit; ob sie überhaupt mit einem fremden Modell verarbeitet werden, entscheidet der Verantwortliche und nicht ein Werkzeug.",
 'q10-local-model-needs': u"Z Privacy spricht mit jedem Server, der eine OpenAI-kompatible Anfrage beantwortet, auch mit einem auf Ihrem eigenen Rechner — llama.cpp, Ollama, LM Studio —, und ein lokales Modell braucht überhaupt keinen Schlüssel.",
 'q14-log-file-written': u"Nach derselben Lesung des Quelltextes: Eine Datei, die geschrieben wird, besteht kurz unter einem zweiten Namen neben der fertigen, im selben Ordner, und wird an ihren Platz umbenannt; in das temporäre Verzeichnis des Systems wird nichts geschrieben, und eine Protokolldatei wird überhaupt nicht geschrieben.",
 'q16-recovery-mechanism-any': u"Dieser Build hat keinerlei Wiederherstellungsmechanismus: kein Zurücksetzen, keine Hinterlegung, keinen zweiten Schlüssel und keine irgendwo aufbewahrte Kopie, und nichts auf unserer Seite könnte den Tresor ohne die Passphrase wiederherstellen.",
 'q17-service-answers-neither': u"Fünf der sechs gehen über dieselbe Anfrageform `chat/completions` hinaus, und Anthropic hat eine eigene; ein Dienst, der keine der beiden Formen beantwortet, wird von diesem Build nicht erreicht, so offen das Adressfeld auch ist.",
 'q17-model-your-own': u"Jede Verbindung wird an einer Adresse hergestellt, die Sie ändern können, und ein Modell auf Ihrem eigenen Rechner braucht überhaupt keinen Schlüssel.",
}

MIRROR_AR = {
 'q2-only-reliable-source': u"فالمصدرُ الموثوقُ الوحيد هو شروطُ المزوّد نفسِه السارية",
 'q3-only-your-machine': u"فلا يستطيع عكسَه إلّا جهازُك",
 'q4-none-them-substitutes': u"ولا يُغني واحدٌ منها عن الآخر",
 'q5-only-where-person': u"ولا تُعدّ البياناتُ مجهولةَ الهويّة — وهذا هو إخفاءُ الهويّة (Anonymisation) — إلّا حيث لم يعد يمكن التعرّفُ على الشخص بوسائلَ يُرجَّح في المعتاد أن تُستعمل — وهو معيارٌ يأخذ في الحسبان ما قد يفعله غيرُك على نحوٍ معقول، لا ما تفعله أنت وحدك — وعندها لا تسري عليها اللائحة (الحيثيّة ٢٦).",
 'q5-standard-takes-account': u"وهو معيارٌ يأخذ في الحسبان ما قد يفعله غيرُك على نحوٍ معقول، لا ما تفعله أنت وحدك",
 'q5-with-every-name': u"ونصٌّ أُزيل منه كلُّ اسمٍ قد يظلّ عن شخصٍ يمكن التعرّفُ عليه — ورسالةُ عيادةٍ عن مريضةٍ واحدة هي المثالُ المعتاد.",
 'q6-everything-else-stays': u"والمستبدَلُ هو ما كشفه Z Privacy أو ما وسمتَه أنت؛ وكلُّ ما عدا ذلك يبقى في النصّ كما أقررتَه تماماً — ولهذا توجد خطوةُ المراجعة، ولهذا تُعرَض عليك قبل أن يُرسَل شيء.",
 'q9-pdf-carries-every': u"والجديرُ بالملاحظة أنّ ملفَّ PDF يحمل كلَّ صفحةٍ فيه، ومنها الصفحاتُ التي لم تكن تريد فيها مساعدة.",
 'q10-accepted-only-literal': u"ولا يُقبل `http` العاديّ إلّا لعنوان loopback **حرفيّ**، ولا يُقبل لاسمٍ مثل «localhost»",
 'q10-says-nothing-about': u"ولا يقول شيئاً عمّا تفعله البرامجُ الأخرى على جهازك",
 'q11-nothing-leaves-while': u"ولا يغادر شيءٌ ما دام اقتراحٌ بلا جواب",
 'q12-proof-other-program': u"لا برهانٌ على أنّه لا يوجد برنامجٌ آخرُ ولا طريقٌ آخر",
 'q13-every-token-chat': u"داخل التطبيق يُستعاد الجوابُ وهو يصل؛ وإن حملتَ السؤالَ إلى نموذجٍ بنفسك فإنّ «أضِف جواباً» تُعيد النصَّ، وكلُّ رمزٍ حمله ذلك الحوار يعود إلى اسمه.",
 'q14-interface-cannot-open': u"لا حساب في Z Privacy، ولا خادم لZ Privacy، ولا تحليلات: الشيفرةُ تحمل عميلَ شبكةٍ واحداً وطريقَ إرسالٍ واحداً، والواجهةُ لا تستطيع فتح مقبسٍ أصلاً، ولا يظهر في الشيفرة أيُّ عنوانٍ لZ Privacy — فالعنوانُ الوحيد الذي بُني هذا البرنامج ليتحدّث إليه هو المزوّد الذي أعددتَه، ببيان الاعتماد الذي أعطيتَه.",
 'q14-settings-file-never': u"وعلى جهازك أنت، **في هذا البناء، ومقروءاً من شيفرته لا مُراقَباً على تثبيتٍ يعمل**، يكتب مجموعةً معروفةً من الملفّات ولا يكتب غيرها: الخزنةَ المشفّرة، وملفّاً مشفّراً لكلّ جلسة، وقفلاً بجانبها، وملفَّ إعداداتٍ لا يحمل عملَك أبداً — ومعها الوثيقتان اللتان تطلبهما باسمهما: نسخةٌ محميّة، وملفُّ PDF عاديٌّ مُستعاد.",
 'q14-nothing-written-system': u"ولا يُكتب شيءٌ في المجلّد المؤقّت للنظام",
 'q15-passphrase-never-leaves': u"بعبارة مرورٍ لا تغادر الجهاز أبداً",
 'q15-finds-none': u"فلا يجد منها شيئاً",
 'q15-only-as-strong': u"والتشفيرُ ليس أقوى من عبارة المرور التي تختارها، والخزنةُ المفتوحة يقرؤها كلُّ ما يعمل باسمك على ذلك الجهاز: نحن نحمي ملفّاً ساكناً، لا جهازاً اختُرق أصلاً.",
 'q15-refuses-write-if': u"ويرفض القلبُ الكتابةَ إن لم يستطع ذلك",
 'q16-vault-cannot-be': u"لا تُفتَح الخزنة",
 'q16-nothing-our-side': u"ولا شيءَ في جهتنا يستطيع استرجاع الخزنة بغير عبارة المرور",
 'q16-nobody-holds-copy': u"لا أحد يحمل نسخةً من هذه، ولا توجد إعادةُ ضبط — فعبارةُ المرور لا تغادر هذا الجهاز، ولا شيء في جهتنا يستطيع استرجاع الخزنة بدونها.»",
 'q16-passphrase-never-leaves': u"لا أحد يحمل نسخةً من هذه، ولا توجد إعادةُ ضبط — فعبارةُ المرور لا تغادر هذا الجهاز، ولا شيء في جهتنا يستطيع استرجاع الخزنة بدونها.»",
 'q16-nothing-our-side-2': u"ولا شيء في جهتنا يستطيع استرجاع الخزنة بدونها",
 'q17-every-connection-made': u"وكلُّ اتّصالٍ يُجرى عند عنوانٍ تستطيع تغييره، والنموذجُ على جهازك لا يحتاج مفتاحاً أصلاً.",
 'q18-who-agreed-nothing': u"ولم يتّفقوا مع مزوّدك على شيء",
 'q19-every-value-you': u"وقاعدتا IBAN وBIC غيرُ مربوطتين بحزمة لغة، فلا تتوقّفان على لغة الوثيقة؛ وتضيف حزمُ اللغات عناوينَ البريد وأرقامَ الهواتف والأرقامَ الضريبيّة وأرقامَ التأمين الاجتماعيّ وأرقامَ العملاء والعقود والموظّفين وتواريخَ الميلاد والأشخاصَ والشركاتِ والعناوين — وكلُّ قيمةٍ علَّمتَها إيّاه تُطابَق حيثما وردت.",
 'q19-all-depends-two': u"وكلُّ ذلك يتوقّف على أمرين سابقين لأيّ قاعدة: أن يكون النصُّ قد وصل إلى الفحص كما يُقرأ على الصفحة، وأن تكون القيمةُ مكتوبةً بصورةٍ تصفها القواعد.",
 'q19-nothing-leaves-while': u"«لا يغادر شيءٌ ما دام اقتراحٌ بلا جواب»",
 'q19-asked-every-door': u"وما لا يتيقّن منه يصير اقتراحاً ينتظر كلمتَك، وقانونُ «لا يغادر شيءٌ ما دام اقتراحٌ بلا جواب» يُسأل عند كلّ بابٍ يُخرج النصَّ من التطبيق: الإرسالُ إلى نموذج، ونسخُ النصّ المحميّ، ونسخُ الحوار، وحفظُ ملفّ PDF محميّ.",
 'q21-nothing-subscribe': u"ولا شيءَ يُشترَك فيه",
 'q21-your-own-computer': u"والنموذجُ الذي يعمل على جهازك لا يكلّف شيئاً البتّة",
 'q22-ask-nobody': u"ولا تستأذن أحداً",
 'q23-lists-every-claim': u"يُحصي `docs/CLAIMS.md` كلَّ ادّعاءٍ بالأسطر الأربعة نفسِها: الجملةُ التي نعرضها فعلاً، وما **لا** يغطّيه، والاختبارُ أو البوّابةُ التي تثبته، والأمرُ الذي تشغّله بنفسك.",
 'q23-interface-cannot-open': u"وأنّ الواجهة لا تستطيع فتح مقبس",
 'q23-every-door-obeys': u"وأنّ كلّ بابٍ يخضع لقانون",
 'q24-nothing-has-signed': u"وعلى ويندوز يعرض أوّلُ تشغيلٍ صفحةً زرقاء — <span dir=\"ltr\">«Windows protected your PC»</span> —، لأنّ هذا المثبِّت لم يوقّعه شيء: ومعنى تلك الصفحة أنّ ويندوز لا يملك أساساً ليعدّ الملفّ موثوقاً، لا أنّه فحصه فوجده سليماً أو غيرَ سليم.",
 'q24-says-nothing-about': u"ولا تقول شيئاً عمّن نشر الملفّ",
 'q25-nothing-collected-site': u"ولا يُجمَع شيءٌ في هذا الموقع",
 'q2-z-privacy-changes': u"وZ Privacy لا يغيّر واحداً منهما؛ ما يغيّره هو ما في النصّ الذي ترسله.",
 'q4-asks-whether-model': u"**تقليلُ البيانات** (المادّة ٥/١/ج) يسأل: هل يحتاج النموذجُ هذه القيمةَ أصلاً؟ وهذا هو السؤالُ الذي تُعين فيه أداةٌ مثل Z Privacy.",
 'q7-allow-external-model': u"وZ Privacy لا يقرّر هل تسمح قواعدُ مهنتك أصلاً بأن يرى نموذجٌ خارجيٌّ قضيّةً — فذلك تقديرُك أنت ويختلف باختلاف الولاية القضائيّة.",
 'q8-whether-process-with': u"والبياناتُ الصحّيّة فئةٌ خاصّةٌ بالمادّة ٩، ولبيانات الموظّفين التزاماتُها؛ وقرارُ معالجتها بنموذجٍ خارجيٍّ أصلاً هو لمسؤول المعالجة لا لأداة.",
 'q10-local-model-needs': u"يتحدّث Z Privacy إلى أيّ خادمٍ يجيب طلباً متوافقاً مع OpenAI، ومنها خادمٌ على جهازك أنت — llama.cpp أو Ollama أو LM Studio — والنموذجُ المحلّيّ لا يحتاج مفتاحاً أصلاً.",
 'q14-log-file-written': u"وبالقراءة نفسِها للشيفرة: الملفُّ وهو يُكتَب يوجد لحظةً باسمٍ ثانٍ بجانب الملفّ التامّ، في المجلّد نفسِه، ثمّ يُعاد تسميتُه في موضعه؛ ولا يُكتب شيءٌ في المجلّد المؤقّت للنظام، ولا يُكتب ملفُّ سجلٍّ البتّة.",
 'q16-recovery-mechanism-any': u"وهذا البناءُ ليس فيه أيُّ آليّة استرجاع: لا إعادةَ ضبط، ولا إيداعَ لدى أحد، ولا مفتاحَ ثانياً، ولا نسخةً محفوظةً في أيّ مكان، ولا شيءَ في جهتنا يستطيع استرجاع الخزنة بغير عبارة المرور.",
 'q17-service-answers-neither': u"وخمسةٌ من الستّة تخرج بصيغة الطلب نفسِها `chat/completions`، ولAnthropic صيغتُها؛ فالخدمةُ التي لا تجيب إحدى الصيغتين لا يصل إليها هذا البناء مهما كان حقلُ العنوان مفتوحاً.",
 'q17-model-your-own': u"وكلُّ اتّصالٍ يُجرى عند عنوانٍ تستطيع تغييره، والنموذجُ على جهازك لا يحتاج مفتاحاً أصلاً.",
}


def answers(path):
    """Each question's proposed answer text, by number."""
    text = io.open(path, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'^## Q(\d+) · .*?\n\n\*\*Answer\.\*\* (.*?)\n',
                         text, re.S | re.M):
        out[int(m.group(1))] = m.group(2)
    return out


# The narrow vocabulary: words that claim EVERY case in their own language.
# Ordinary negation and quantification are deliberately absent — `kein`,
# `jede`, `nur` in German and «لا», «كلّ», «فقط» in Arabic do the work of
# «not» and «each», and a check that flagged them would flag the language
# rather than the claim.
STRONG = {
    'DE': re.compile(r'\b(immer|nie|niemals|nichts|niemand|keinerlei|unm\u00f6glich|'
                     r'garantiert|ausschlie\u00dflich|einzige[rsmn]?|vollst\u00e4ndig|'
                     r'v\u00f6llig)\b', re.I),
    'AR': re.compile(u'(\u062f\u0627\u0626\u0645\u0627\u064b|\u0623\u0628\u062f\u0627\u064b|\u0627\u0644\u0628\u062a\u0651\u0629|\u0644\u0627 \u0634\u064a\u0621|\u0644\u0627 \u0623\u062d\u062f|\u0645\u0633\u062a\u062d\u064a\u0644|\u064a\u0636\u0645\u0646|\u062a\u0636\u0645\u0646|'
                     u'\u0627\u0644\u0648\u062d\u064a\u062f|\u0627\u0644\u0648\u062d\u064a\u062f\u0629|\u062c\u0645\u064a\u0639|\u0642\u0637\u0639\u0627\u064b)'),
}

# A strong word in a translation that no English id accounts for, and why it
# is not a promise. Each one was looked at; none passes for being obvious.
EXTRA = {'DE': {}, 'AR': {}}

# (language, id) -> what is weaker, and who owns the debt. Printed as a
# NOTE on every run: the mirror is present, so the gate is green, and the
# gate being green is not the same as the sentence being as strong.
WEAKER = {
    ('AR', 'q16-passphrase-never-leaves'):
        "the English says «never leaves this device» and the shipped "
        "Arabic sentence says «\u0644\u0627 \u062a\u063a\u0627\u062f\u0631 \u0647\u0630\u0627 \u0627\u0644\u062c\u0647\u0627\u0632» with no «\u0623\u0628\u062f\u0627\u064b». "
        "The FAQ quotes the app and may not strengthen a quotation, so "
        "this is an APP-side meaning debt for after the pause — the "
        "lead's list, not this page's (key thereIsNoWayBack).",
}

DRAFT = pathlib.Path('docs/faq-translation-draft.md')


def translated(tag):
    """Each question's drafted answer in one language."""
    if not DRAFT.exists():
        return {}
    text = io.open(DRAFT, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'^## Q(\d+) \u00b7 .*?\n\n.*?\*\*%s[^*]*\.?\*\*\s*'
                         r'(?:<div[^>]*>\s*)?(.*?)(?:\n\n</div>|\n\n\*\*)' % tag,
                         text, re.S | re.M):
        out[int(m.group(1))] = m.group(2).strip()
    return out


def the_other_languages(ids):
    """Every English absolute still carried, and none invented. `ids` maps an
    English id to the question it belongs to."""
    bad = 0
    for tag, table in (('DE', MIRROR_DE), ('AR', MIRROR_AR)):
        drafted = translated(tag)
        if not drafted:
            print('  SKIP   %s: no translation draft in this tree' % tag)
            continue
        carried = {}
        for ident_, phrase in sorted(table.items()):
            n = ids.get(ident_)
            if n is None:
                print('  FAIL   %s names \u00ab%s\u00bb, which is no English absolute any '
                      'more \u2014 the English sentence moved and this mirror did not'
                      % (tag, ident_))
                bad = 1
                continue
            body = drafted.get(n, '')
            at = body.lower().find(phrase.lower())
            if at < 0:
                print('  FAIL   %s Q%-2d has lost \u00ab%s\u00bb \u2014 the words that carry it '
                      'are not in the %s answer' % (tag, n, ident_, tag))
                bad = 1
            else:
                carried.setdefault(n, []).append((at, at + len(phrase)))
        for n in sorted(drafted):
            for m in STRONG[tag].finditer(drafted[n]):
                inside = any(lo <= m.start() and m.end() <= hi
                             for lo, hi in carried.get(n, ()))
                if inside:
                    continue
                allowed = EXTRA[tag].get(n, ())
                if any(p.lower() in drafted[n].lower()
                       and drafted[n].lower().find(p.lower()) <= m.start()
                       and m.end() <= drafted[n].lower().find(p.lower()) + len(p)
                       for p, _ in allowed):
                    continue
                start = max(0, m.start() - 45)
                print('  FAIL   %s Q%-2d \u00ab%s\u00bb is an absolute the English does not '
                      'carry \u2014 \u2026%s\u2026'
                      % (tag, n, m.group(0),
                         drafted[n][start:m.end() + 45].replace('\n', ' ')))
                bad = 1
        if not bad:
            print('  PASS   %s carries all %d English absolutes and invents none'
                  % (tag, len(table)))
        for (lang, ident_), why in sorted(WEAKER.items()):
            if lang == tag:
                print('  NOTE   %s «%s» is carried but weaker — %s'
                      % (tag, ident_, why))
    return bad


def main():
    src = pathlib.Path('docs/faq-review.md')
    if not src.exists():
        print('  FAIL   %s is not here, so no absolute could be checked' % src)
        return 1
    found = answers(src)
    if not found:
        print('  FAIL   %s holds no answers in the shape this reads' % src)
        return 1

    bad = 0
    seen = {}
    for n in sorted(found):
        body = found[n]
        hits = []
        for m in ABSOLUTE.finditer(body):
            start = max(0, m.start() - 55)
            end = min(len(body), m.end() + 55)
            hits.append((m.group(0), body[start:end].replace('\n', ' '), m.start()))
        registered = REGISTER.get(n, ())
        # **A hit is bound to the entry whose phrase covers it, by position.**
        # The first version asked whether the phrase was anywhere in the answer
        # and held the same word, which let one entry answer for two different
        # absolutes — Q21's «nothing to subscribe to» swallowed «costs nothing
        # at all», and the second was then reported as having vanished. A
        # register that can be satisfied by the wrong line is not a register.
        spans = []
        for phrase, why in registered:
            at = body.lower().find(phrase.lower())
            if at >= 0:
                spans.append((at, at + len(phrase), phrase, why))
        for word, context, at in hits:
            verdict = None
            for lo, hi, phrase, why in spans:
                if lo <= at and at + len(word) <= hi:
                    verdict = (phrase, why)
                    break
            if verdict is None:
                print('  FAIL   Q%-2d «%s» is an absolute nothing in the register '
                      'covers — …%s…' % (n, word, context))
                bad = 1
            else:
                seen[(n, verdict[0])] = True
                mark = 'qualified in the sentence' if verdict[1] == QUALIFIED else verdict[1]
                print('  PASS   Q%-2d «%s» — %s' % (n, word, mark))

    for n, entries in sorted(REGISTER.items()):
        for phrase, _ in entries:
            if (n, phrase) not in seen:
                print('  FAIL   Q%-2d the register still claims «%s» was checked, '
                      'and no such absolute is in that answer any more' % (n, phrase))
                bad = 1

    ids = {}
    seen_ids = set()
    for n in sorted(REGISTER):
        for phrase, _ in REGISTER[n]:
            ids[ident(n, phrase, seen_ids)] = n
    print()
    bad |= the_other_languages(ids)

    total = sum(len(v) for v in REGISTER.values())
    print()
    print('%d absolutes registered across %d answers' % (total, len(REGISTER)))
    print('AN ABSOLUTE ON THE PAGE HAS NO EVIDENCE BEHIND IT' if bad
          else 'every absolute on the page is covered or qualified')
    return bad


if __name__ == '__main__':
    sys.exit(main())
