# 113 — The NOTICE names the maker: Apache 2.0 stays, and every product that carries Z says where it came from

**Source:** the owner's final word on licensing, 24 October 2026: «إمكانية استخدام الكود في الشركات والأفراد دون الرجوع إلى الشركة، ولكن يجب ذكر مصدر الكود والشركة المنتجة في تعريف منتجاتهم. هذا هو الشرط الوحيد». And «نعم» on the NOTICE text below. Builder: **e2**, in the site round before publishing, since it is a docs/site/packaging change and the site is his seat. Branch off the lead tip after the 107–112 merge.

## The ruling

- **The licence does not change.** Apache License 2.0 stays, for companies and individuals alike, with no permission asked of Faruk AB.
- **The one condition is attribution**, carried by the mechanism Apache 2.0 already has: a `NOTICE` file. Under §4(d), anyone who distributes a work containing ours must carry the NOTICE's attribution in a NOTICE file, in their documentation, or wherever their product displays third-party notices. The repository has no NOTICE today, so attribution is not yet binding. This paper makes it binding.
- **Honest limit, said to the owner and kept in the record:** NOTICE binds credit in a product's notices, documentation or «About / licences» screen. It does **not** bind a mention in advertising. The owner accepted this. A custom advertising clause was rejected because it would make the licence non-standard.

## The NOTICE, verbatim (the owner's «نعم»)

```
Z Privacy
Copyright 2026 Faruk AB (Sweden, org.nr 559473-3494)
https://z-privacy.com
Source: https://github.com/YourVoicesApp/z-privacy

This product includes software developed by Faruk AB.
```

## What moves

1. `NOTICE` at the repository root, with the text above byte for byte.
2. **Every artefact carries it beside LICENSE:** `scripts/package_linux.sh` (the archive) and the Windows packaging (the folder, the Inno installer, the MSIX layout). Check `.github/workflows/windows*.yml` and the packaging scripts for where LICENSE is copied, and copy NOTICE in the same place. A distribution that carries our code without our NOTICE breaks our own condition.
3. **The app's own «About / licences» place** shows the NOTICE text if it already lists licences. If it has no such place, name that in the report and add nothing.
4. **The site, en/de/ar:** «open source, Apache 2.0» stays, plus one sentence wherever the licence is named (the license page certainly, the home page if it names the licence). In substance: use it freely, commercially too, on one condition: credit Z Privacy by Faruk AB, as the NOTICE file asks. The license page links NOTICE beside LICENSE.
5. README.md's licence line (`© 2026 Faruk AB. Licensed under the Apache License 2.0.`) gains the same one sentence and a pointer to NOTICE.
6. LICENSE's appendix placeholder (`Copyright [yyyy] [name of copyright owner]`) is the template's own instructions and stays as Apache ships it. The copyright line lives in NOTICE and README.

## Pins

- A gate: NOTICE exists, equals the ruling's text byte for byte, and is inside every artefact the packaging builds (archive listing / folder listing). Red first: remove it from one artefact.
- The site sentence is in all three languages, and the license page links a NOTICE that exists (G59's own law, which already reds on a `<code>` path that does not exist).

## Measurement

`bash scripts/gates.sh` green, site gates in both modes (publishing still lawfully red only on the download markers), and a listing of each artefact showing NOTICE inside. The lead merges.
