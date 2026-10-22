# 103 — The download section: Inno alone, a measured SmartScreen sentence, and a gate that verifies instead of refusing

**Owner, 22 October (rule 81-أ, «نعم», and «دعنا ننهي z نهائياً»):** publishing day's download comes from z-privacy.com itself, and after the `78988fd` round's measurements it carries the **Inno installer alone** beside the Linux bundle — the MSIX waits for a real certificate and a vault that escapes package virtualisation (paper 101's answer). Builder: **e2** (site is the second seat's). Branch `feat/the-download-section` off the lead line after paper 102's merge.

## 1 · What the section carries, per language (de/en/ar)

- The **Linux bundle** (tar) and the **Windows Inno installer** (exe), each with its `sha256` printed beside it and a one-line «verify it» command (`sha256sum` / `certutil -hashfile … SHA256`).
- **The honest SmartScreen sentence, from measurement not hope:** the installer is unsigned; a browser download carries the mark of the web, so Windows shows the blue SmartScreen page; the way through is «More info» → «Run anyway» (the German and Arabic pages word it in their own language; the Swedish UI strings the owner measured — «Mer information», «Kör ändå» — belong to the report, not the page); it asks for no administrator. Beside it the fingerprint line: the sha256 on this page is how you know the file is ours.
- **One honest line for the MSIX's absence:** a signed store/MSIX version follows when a real certificate signs it; nothing else promised.
- **The outside-model claims review report** linked beside the downloads when it exists (it is the publishing gate, rule 94's family); the section's layout holds its slot from day one.
- No version numbers invented: the artefact names and hashes come from the final green run's `dist/` — placeholders carry a visible «(final hashes on publishing day)» marker and the gate stays RED until real values land, so a half-filled section can never deploy green.

## 2 · The gate turns around (rule 81's second half)

`check_site.sh` / `check_site_claims.py` today refuse download links. On this branch the gate **turns**: the three download pages exist, each names both artefacts, each hash on the page equals the sha256 of the real file in the deploy tree (the gate reads the files, not the prose), the SmartScreen sentence exists on all three languages keyed like the guide's keys, and the front page links the section. Pinned red four ways: a missing artefact, a wrong hash, a placeholder marker left in, a language page missing the sentence.

## 3 · Not in this round

MSIX on the site (rule 81-أ); the newsletter line (79 stands as built); any auto-update mechanism; download counters or analytics (none, ever — the privacy page's word holds).

## Measurement

e2: gates green including the turned site gate against a scratch deploy tree with the real 78988fd artefacts as stand-ins; the lead merges after paper 102's merge, swaps in the final run's artefacts and hashes by hand, runs the gate against the live tree, and the owner deploys with his two lines. The live check (`check_site.sh` + three 200s + a hash fetched from the live site equal to the local one) closes the paper.
