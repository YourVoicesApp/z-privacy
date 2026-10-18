# 092 — The sentences in one list: Flutter localization, English source, German and Swedish

**Owner, 18 October:** «نحن نعمل على فلوتر. الترجمة ليست أكبر مشكلة في مكتبات فلوتر. نحتاج الآن أن نعقد قوائم الجمل قائمة باللغة الإنكليزية، ثم نقوم بنسخها إلى اللغات الأخرى، ثم نقوم بتفعيل الترجمة داخل التطبيق.» Rule 61-أ: the German comes after the journey round, which is sealed at `a779ac2`. Rule 56-أ: the first screen shows Swedish only once the screens speak Swedish.
**Base:** lead line at `a779ac2` (567 · 0 · 0, rust 779, dart 397), installed and pushed.
**Builder:** e2 — glass only. Branch `fix/the-sentences-in-one-list` from `a779ac2`. No push. ed's round in flight (`fix/a-question-alone-leaves-by-every-door`) is core only; you will not meet.

## The measurement that opens this

613 distinct English literals on the glass (`lib/screens`, `lib/widgets`, `lib/core`), none behind a language layer. `settings.zcfg` already carries `ui_language=de|en` from the first screen, and the Language room exists — so the choice exists and nothing reads it for the sentences.

## Three steps, in the owner's order

**1. The list.** Flutter's own tooling: `flutter_localizations` + `intl`, `l10n.yaml` at the app root, `lib/l10n/app_en.arb` as the one English source. Every sentence the glass shows gets a key and a `@key` description that says where it stands and what it means (the descriptions are for the translator and for me). Plurals and the isolate marks (FSI…PDI around the person's own word, `theirOwnWord`) go through ICU placeholders, never string concatenation. `core/messages.dart`'s refusal sentences are part of the list; the core's own English (error `detail`) stays the core's and is quoted, as today.

Keep the keys as sentences name themselves in the house: `theKeyIsBehindTheLockedVault`, `theChatKeepsNothing` — a key is a name, not a number.

**2. The copies.** `app_de.arb` and `app_sv.arb` with every key. German: draft the translation yourself, key by key, and mark every one you are unsure of with a `@key` note; the lead reviews the German line by line before the merge, and the owner reads it on the glass. Swedish: a copy of the English for now, every value identical — so the file exists, the gate counts it, and the first screen does **not** yet offer Svenska (56-أ holds until the Swedish values differ from the English ones; write that as the gate's own sentence).

Vocabulary, fixed once and used everywhere — write it at the top of `app_de.arb` as `@@` comments: vault = Tresor; protected = geschützt; token = Platzhalter (never Token); session = Sitzung; the chat = der Chat; what leaves / what will leave = was das Gerät verlässt; restore = zurückholen; pack = Sprachpaket; block = Block; «Only the protected version is sent to AI through Z Privacy» = «Nur die geschützte Version wird über Z Privacy an die KI gesendet» (already on the first screen; keep it). Product names stay: Z Privacy, z-pdf, Grok, xAI.

**3. The switch.** `MaterialApp.localizationsDelegates` and `supportedLocales` from the generated class; the app's locale comes from `ui_language` (the first screen's choice and the Language room), not from the OS; a change in the room applies without restart. Text direction stays LTR (Arabic is stopped). Fonts: the German and Swedish letters (ä ö ü ß å) must render in the shipped font; measure one screen with each.

## Gates

- **G49**: no user-facing string literal in `lib/screens`, `lib/widgets`, `lib/core` outside the ARB — the shape of G41's allowed list, inverted: the allowed list is now the keys. Test ids, token grammar, file names and the core's quoted English are the named exceptions, each with its reason.
- **G50**: every key in `app_en.arb` exists in `app_de.arb` and `app_sv.arb`; the German has no value identical to the English except for a named list (product names, «OK», numbers); the Swedish is allowed to be identical and the gate says so and says why (56-أ).
- Every existing widget test keeps passing under `en`; one test per screen renders under `de` and finds its sentences by key, not by English text — `find.text` on an English sentence is now a gate failure by itself.
- `scripts/gates.sh` green from a plain debug build; the three numbers.

## Not this round

No sentence changes its meaning, no screen changes its shape, no new door. Swedish translation itself is the round after; Arabic stays stopped.
