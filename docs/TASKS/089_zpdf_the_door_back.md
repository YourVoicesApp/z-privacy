# 089 · z-pdf, the door back — and a protection that is not forgotten

**Opened by the owner, 15 Oct 2026, after testing «ألماني 1» across two days.**

- «أعتقد أنني كنت واضحاً أن الحماية ستكون دائمة ولذلك قررنا أن ما لا نريده نفك الحماية عنه.»
- Of the returning z-pdf that brought nothing back: «التطبيق ما زال لا يستطيع معرفة منتجه.»
- «نحن قررنا إضافة خيار يدعى z-pdf يقوم بعكس العملية، يبحث عن الكود ليحوله إلى اسم كما تفعل عملية سحب إجابة الذكاء الصناعي من الذاكرة. نفس هذا الزر نحتاجه الآن.»

The button is 079 rule 3, decided on 13 Oct. The memory it needs is the owner's word of today. **They are one round**, because the button without the memory says the same thing the banner says today: «names stay as tokens».

## Today (measured by the lead at 65f0ce2)

- **079 rule 3 was never built.** No «z-pdf» entry exists in the app. Only rule 4 was built: the automatic banner and «Read it back» (`workspace.dart:1254`).
- **A bench's values die with the bench.**
  - Opening a file opens a new bench and disposes of the old one (`shell.dart`, `_bench?.dispose()`).
  - Disposing closes the session: «A closed session takes its tokens with it. Nothing is kept behind.» (`session_state.dart:1703`).
- **A conversation's file keeps turns, not values** (`conversation.rs`, Body v4).
- **A hand selection is `Scope::Conversation`.** `remember_in_vault` writes only for Profile and Always (`ops/mod.rs:1779`).
- **The owner's test on 15 Oct:**
  - «Markus» had to be protected again the next day, under the same token `__Z_F610_CUSTOM_41AC03BD__`.
  - The returning z-pdf said «11 names stay as tokens: this conversation's own names are kept only while it is open».
- **The trade is a guard today:** `a_taught_value_comes_back_after_the_bench_is_gone` asserts that a name nobody taught does **not** come back.

## The rules

1. **A conversation keeps every value protected in it.** This covers what the scanner protects, what a review answer protects and what a hand protects.
   - The values are sealed in the conversation's own file: Body v5, under the key that file already uses.
   - They are never written to `vault.zv` and never stored in the clear.
   - Identifiers are kept too. 083's rule 19 («never stored») is about the vault's word blocks, not this file, and the test file below carries an IBAN that has to come back.
2. **Un-protection is the only way out.**
   - «In this conversation» removes the value from the file.
   - «Here» uncovers one place and keeps the value.
   - Forgetting the conversation deletes the file, and the values go with it (`conversation::remove`). This needs a guard.
3. **Reading back uses what the conversation kept.**
   - A token whose namespace names a conversation of this vault is resolved from that conversation's kept values. Derive the tail and compare (the one-way door, 079).
   - This must hold after the bench is gone **and after the app is restarted.**
   - A locked vault is a standing door (079 rule 8).
4. **The same conversation, a new text: the kept values are already protected.**
   - This is the «Markus» case.
   - They are applied on import as protected, not offered as suggestions, because the person already answered.
   - 085's per-word law already split what the app read for itself. A hand selection stays as the person made it.
   - **Do not build the cross-conversation question.** Whether «permanent» reaches other conversations is put to the owner.
5. **The explicit door.** The + menu on the first screen gains «z-pdf».
   - It picks a file (PDF, Word, text) and opens it in **restore mode**: never scanned and never protected (079 rule 5, guarded).
   - It shows the document with the names back, and names every token that stayed a token.
   - One press opens it.
6. **The sentence goes.** «This conversation's own names are kept only while it is open» is deleted. The door says what came back, what did not, and why («from another machine», «the vault is locked»).

## Acceptance — the owner's own files

- **The files:** `~/نصوص التجربة/تجربة الأكواد - رد ألماني.pdf` and `.txt`. They hold a short German reply carrying two tokens of the owner's conversation «ألماني» (F610): Feldmann, and the IBAN.
  - Z's reader reads the PDF as written: 6 lines (lead probe).
- **The order on the glass:**
  1. Open «ألماني 1.txt» in the conversation «ألماني» and protect it as usual. That conversation's values were never kept, because they were made before this round.
  2. Close the app.
  3. Open it again.
  4. Choose «z-pdf» and pick each file.
  5. Feldmann and the IBAN must both come back.
- **A fresh z-pdf of «ألماني 1»**, saved and opened the same way after a restart, brings back every name: 11 of 11.

## Guards (pin today's wrong answer first)

- **Flip `a_taught_value_comes_back_after_the_bench_is_gone`:** every name of the conversation comes back after the bench is gone, with nothing taught.
- **The restart guard:** close every bench, drop the core's state, open the vault again, and every name still comes back.
- **Un-protect «in this conversation»:** the value's token stays a token on the way back and is named.
- **Un-protect «here»:** the value still comes back.
- **Forget the conversation:** the file is gone and nothing comes back.
- **A returning document through «z-pdf»** is not scanned and not protected. The number of tokens is the same before and after.
- **The «Markus» guard:** protect by hand, close the bench, import the same text in the same conversation, and that place stands protected under the same token.
- **The measurement for the report:** what the conversation file holds, **by count, never by value**, before and after.

## Seat and base

- **ed**, on **65f0ce2**.
- e2 is working in the scanner and in `inspect_selection` at the same time, so keep out of both. Your ground is `conversation.rs`, `ops/conversation`, `returning.rs`, `shell.dart` (the + menu) and `session_state.dart`.
- Nothing pushed, no remote branch.
- The independent attacker sees this at «ready»: it changes «nothing is kept» to «kept, sealed, per conversation».

## Not in this round

- The cross-conversation reach of a protection (the owner's answer is pending).
- «Review before send»: delete it, or show both texts (the owner's answer is pending).
- Z's reader gives every word of a z-pdf its own line (195 of 195 on «ألماني»). This is queued for e2.
