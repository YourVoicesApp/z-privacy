# 116 — Arabic: the screens read right to left, and the site stops denying it

**Source:** the owner, 25 October 2026 (see 115): Arabic means «إمكانية قراءة الشاشات بهذه اللغة». Builder: **e2**. Branch off `bfd79e6`, in parallel with 115 (ed, the words and the names). The site half waits for 115's merge.

## 1 · The screens, right to left

- When the interface language is Arabic, the whole app is drawn right to left: `Directionality` follows the locale. Measure what Flutter already mirrors on its own and what it does not. Hand-placed `left:`, `EdgeInsets.only(left…)`, `Alignment.centerLeft`, positioned overlays, the gutter and anything else written in physical directions are the usual places that stay on the wrong side. Prefer the directional forms (`start`/`end`, `EdgeInsetsDirectional`) over special cases.
- **What must NOT mirror:** the document itself follows its own text direction from the reading base (086), not the interface's. An English document in an Arabic interface still reads left to right, and the reverse. Tokens and code-like strings (`__Z_…__`, IBANs, file paths) stay left to right inside Arabic sentences, isolated per `a_name_in_a_sentence_needs_an_isolate` (FSI…PDI, never inside a filename).
- Until 115 lands there is no `app_ar.arb`. Measure the layout with `Directionality.rtl` forced in tests, and run the real Arabic words over it once 115 is merged.
- The owner looks at the screens himself before Arabic is published, and that look is part of this round's closing.

## 2 · The site, after 115 merges

- The three languages' pages say today that «Arabic is a reading pack and not a language of the interface». After 115 that sentence is false. Find every place it is said, and make it the truth: Arabic is a language of the interface, written and not yet reviewed (the same honesty as Swedish).
- The «languages the interface speaks» gate admits a language only while its list really differs from English. After 115 Arabic qualifies, so update what the gate expects. French stays the absent control (`NOT_SPOKEN`), as 106 chose.
- Swedish still has no site tree. Nothing here adds one.

## Pins

- RTL: one pin per screen class that was wrong on `bfd79e6`, red first (the overlay, the gutter, the bar), plus one proving an LTR document stays LTR in an RTL interface.
- Site: the old denial sentence is refused once Arabic is in the list, and its replacement stands in all three languages.

## Measurement

`bash scripts/gates.sh` green, site gates in both modes, screenshots of the main screens in Arabic for the owner's look. The lead merges after 115.
