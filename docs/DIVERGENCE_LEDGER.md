# The Divergence Ledger — z_core ↔ zprivacy-lib

**Migration status.** z_core remains the production implementation until migration gates are satisfied, but it is no longer intended to remain a second independent privacy engine permanently. Changes touching scanner behavior, token semantics, restoration, or session security must be entered in the divergence ledger and reviewed for zprivacy-lib convergence. Nothing is copied automatically; app-specific behavior remains app-specific.

The ledger is held by the lead. One line per landed commit on z_core that touches the four areas above: the commit, the area, what changed in behaviour, and the library's answer — *converge*, *app-specific*, or *open*.

Library repository: `YourVoicesApp/zprivacy-lib`. Its parity corpus is pinned to `d882c5f`; a later z_core behaviour is measured against a new corpus snapshot, never by rewriting that one.

| z_core commit | area | behaviour change | library |
|---|---|---|---|
| `d882c5f` (existing) | scanner — German pack IBAN | The pack's IBAN rule swallows the word after the number: «…0130 00**, BIC**», «…3249 31** zu**»; the film shows «…7466 **on 2**». Measured 13 Oct on two invented letters. | **converge toward the library**: zprivacy-lib V1-G ends the span at the last digit group (GeneralRule). The app takes the fix in its detection round. |
| `d882c5f` (existing) | scanner — Person «meiner Person: Markus Weber» (Brief_Weber 1072–1084) | z_core: Auto. Library V1-G golden list: Suggest — contradicts the corpus reference counts (21/8). | **open**: the library must either reach Auto or carry the divergence named in its golden file; the corpus is not rewritten. |
