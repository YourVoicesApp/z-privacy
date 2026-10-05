# 038-A · The line under the closing is a person only if it looks like one

**Status: WAITING — after Phase 4, first of the three measured debts (the owner's order, 5 Oct night).** · lead → the builder the owner names · branch `fix/the-line-under-the-closing` from `main`.

## Measured (`08b04aa`, `docs/THE_NUMBERS.md` §2)

The signature rule reads the line after a closing («Mit freundlichen Grüßen», «Med vänliga hälsningar», «وتفضلوا بقبول فائق الاحترام») as the signer's name. On our own contract fixture (DE-2, `Vertrag_Nordstern.txt`) that line is «Abteilung Vertragswesen», a department, and it is **protected as a Person**: the one false protection on the German corpus, found by measuring and by no test. On DE-1 the same rule is right («Markus Weber»), and it is the reason a bare signature is protected without a question.

## What to build

1. The line under the closing is a person when it **looks like one**: two or three words the active pack can vouch for on at least one side (dictionary given or family, a taught name, or a name the document already protected above), and none of its words is a role word, a department word (`Abteilung`, `avdelning`, `قسم`, `إدارة`) or a company form. Otherwise it is left alone — and measured, not guessed: write the test on DE-2 first (red: the department is protected; green: it is not, and Thomas Müller still is).
2. The same rule in the three packs, as data where the words differ (`roles`, a new `unit_words` list on the pack contract if needed), not as German code.
3. No other change to the Person rules; DE-1 stays 7/7 auto, DE-4 stays 18/1, SV-1's two auto people stay.

## Done means

DE-2 scans to `(auto, suggested) == (8, 1)` with Person auto 1; every other row of `docs/THE_NUMBERS.md` unchanged; gates and tests counted before/after.
