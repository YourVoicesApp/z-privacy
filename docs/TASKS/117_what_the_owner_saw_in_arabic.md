# 117 — What the owner saw in Arabic: seven points before Arabic is published

**Source:** the owner's look at the Arabic screenshots, 25 October 2026: «ننشر العربية ونصلح الأخطاء السبعة». Arabic (115 + 116) is merged on lead at `bd338bb` (653 · 0 · 0) and not yet published. This round fixes, and then Arabic ships in one build. The design choices below are the lead's, made so the work can move; the owner sees them in the screenshots before publishing. **ed** takes 1 and 5, **e2** takes 2, 3, 6 and 7. Each branches off `bd338bb`, and they assemble on e2's branch as before.

## 1 · «Session 1» in English on an Arabic screen (ed)

A session's name is **data**, written into the core at birth and spelled there («a name is data; data does not cross a language seam», G37). So existing names stay exactly as they are. **New sessions are named at birth in the interface language**: «جلسة 1», «Sitzung 1», «Session 1» for English and Swedish if the list says so. The core takes the word for «Session» from the language the session is born with (it already takes `born_with` there), so the stored name is one spelling in one language, and G37's seam stays closed. Pin: a session born in Arabic is stored as «جلسة N» and reads back the same after a language switch.

## 2 · Language buttons, one rule (e2)

Settings shows «German (DE)», «English (EN)», «Svenska (SV)», «العربية». **Every language is named in its own words, with its code:** «Deutsch (DE)», «English (EN)», «Svenska (SV)», «العربية (AR)», the same in every interface language. That is the convention a person scanning for their own language expects. Find where «German» comes from (the core's language table, as the old finder-rewrite lesson says) and fix it at the source, not on the glass.

## 3 · The guide link follows the interface (e2)

Settings → «طريقة استخدام Z Privacy» opens `/en/guide/` on an Arabic interface. It opens the guide in the interface language when the site has one (`/ar/guide/`, `/de/guide/`), and English otherwise (Swedish has no site tree). The machine string keeps its LTR order (`theMachinesOwnWord`).

## 4 · The phone number «4567890 0211»: no change, with the reason recorded

Latin digit groups separated by a space inside an Arabic sentence are displayed in reversed group order by the Unicode bidirectional algorithm. Every Arabic text renderer does the same, and the document's bytes are «0211 4567890». Changing it would mean changing how the person's own document reads, which a product rule forbids («protection may not change how a document reads»). **Nothing changes.** The reason is written here for the owner, and in the guide's Arabic section if e2 finds a natural place for one sentence.

## 5 · «فائق» in «فائق الاحترام» offered as a name (ed)

A library word that is also an ordinary word is offered, never protected alone, so the system is safe. But a fixed courtesy phrase should not ask at all. ar-2 skips a library hit **inside a small closed list of fixed phrases** («فائق الاحترام», «فائق التقدير», and the like). The list is named in the pack, measured on AR-1 (the waiting count drops by exactly the phrase hits), and never widened to «any word followed by a noun».

## 6 · The first screen grows a block per language (e2)

With four languages the first screen is ~1500 px and a person scrolls past four promise blocks to reach the language names. **The language names come first, in one row, and below them stands one promise block: the selected language's.** Choosing another language swaps the block. The promise is still said in every language, one at a time, in the language the person picked. Measure it at 1000 px tall: the language row and the whole block are visible without scrolling.

## 7 · «التِّرس» and «الخزنة» (e2)

The app and the owner's glossary table say «الخزنة». The Arabic guide uses «التِّرس» in one heading. **«الخزنة» everywhere**, one word for one thing. The guide's remark that its control names are not yet moved to Arabic goes too, now that they are.

## Measurement

Each item gets a red-first pin. The assembled branch runs `bash scripts/gates.sh` green and `check_site.sh --tree-only` green, and new Arabic screenshots go to the owner. Then the lead merges, builds Linux, the owner runs Windows, and Arabic is published (site, main, a new GitHub release).
