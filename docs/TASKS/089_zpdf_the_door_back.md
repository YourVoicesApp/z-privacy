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

## Amended 15 Oct, evening: the block rule (the owner said «نعم»)

The first draft below this line put the kept values in the conversation's file and let un-protection delete them. **That draft is withdrawn.** The owner's rule replaces it, word for word in `~/محرر النصوص.md` §٨ rules 49–54:

- «كل كلمة يأخذ رمزاً… هي بلوك غير قابل للحذف من خزنة المستخدم… أي كلمة حصلت على كود هي بلوك. والبلوك قيمة ثابتة لا تمسح، يمكن أن تُعفى من العمل ولكن لا تختفي.»
- «منذ هذه اللحظة متى قُرئت هذه الكلمة داخل التطبيق في مكان، حتى لو بعد سنة، يجب أن تأخذ كود.»
- «المفترض أن z-pdf هو عملية إعادة الأسماء والنصوص إلى التطبيق.»
- «نبقي خيارات الإعفاء من البلوك كما هي.»

Rule 5 (the «z-pdf» entry) is **built and merged** (`9f264b4`). What remains is the storage under it.

## The rules

1. **Every word that takes a token becomes a block in the person's vault.**
   - This covers all three roads: what the scanner protects at Auto, a suggestion the person confirmed, and a hand selection. Identifiers are included: customer numbers and phone numbers are what the vault is for. 083 rule 19 («identifiers are never stored») falls.
   - Blocks live in `vault.zv`'s body. They do not live in the conversation's file and are never written in the clear.
   - **The block keeps every token it was given** (token → value). The door back is then a lookup, not a search across every conversation key. If you find a simpler shape that answers rules 2–4, propose it before building it.
2. **A block is never deleted.**
   - Un-protecting does not remove it. Forgetting a conversation does not remove it. No path in the core may delete a block, and a guard proves it by enumerating every writer of the block table.
3. **A block's word takes a token wherever the app reads it, in any conversation, a year later.**
   - It is applied on import as **protected**, not offered as a suggestion, because the person already answered. `Source::Vault` is already exempt from the one-word law (085), so a hand-made block of two words stays one token.
   - This is the «Markus» case, and it now reaches across conversations. The cross-conversation question of the first draft is answered: yes.
   - In the conversation that made the block, the token is the one it was given (today's derivation from the conversation key and the value, 046/U, so `__Z_F610_CUSTOM_41AC03BD__` stays itself). In another conversation, use that conversation's own derivation and record the new token on the same block.
4. **z-pdf returns every token to its name from the blocks.**
   - After the bench is gone, after a restart, from any conversation.
   - A locked vault is a standing door (079 rule 8): the sentence says to unlock it.
   - A token no block knows stays a token and is named, with why: «from another machine» or «made before this round».
5. **«Leave it» is not stored.** A word left in the clear makes no block (the company name).
6. **The un-protect options stay as they are today: «Here» and «In this conversation»** (rule 12 in `~/محرر النصوص.md`).
   - «In this conversation» exempts the block from work in that conversation and is remembered with the block. It does not delete it.
   - «Here» uncovers one place, and it is remembered with the saved document (rule 9).
7. **The sentence goes.** «This conversation's own names are kept only while it is open» is deleted, and so is any copy of «nothing is kept» on the glass. Find every one; do not stop at the first.
8. **`vault/format.rs` names session format 1; it is 4.** Correct the table in the same round (ed's note).
9. **The saved document** (owner, 15 Oct late evening, `~/محرر النصوص.md` rule 54). «Our element is the block, not the document.»
   - **Blocks and every change on them are saved the moment they happen.** Documents are not saved: their owner has them, unencrypted, on his own disk.
   - **The one exception: what is in the preview screen and has not left it.** Entering the preview gives it a number in the conversation and saves it with its decisions (the «Here»s, the «Leave it»s), sealed under the conversation's key like the questions today. A power cut finds it as it was left.
     - A file pulled from the computer is `doc1`, `doc2`…; a text written with the AI and moved to the preview is `chat1`, `chat2`….
     - A conversation holds more than one.
   - **Leaving by a door (send, copy, pull, PDF) takes it out of the conversation:** its saved copy is deleted, and its number is retired and never used again. Its blocks stay in the vault.
   - **Going back from the preview does not take it out.** No bubble and no question (the owner removed both: «عمل إضافي لا يفيد بأي شيء»).
   - **The saved documents are listed under the conversation's name in the conversations list**, as conversations are listed today, each with «Rename». A press opens it in the preview as it was left.
   - Why, in the owner's words: another document may complete the first, and the person needs to see them together to decide what to edit and what to leave.

## Acceptance — the owner's own files

- **Yesterday's file comes back once its words are blocks again.** `~/نصوص التجربة/تجربة الأكواد - رد ألماني.pdf` carries `__Z_F610_PERSON_343AD503__` (Feldmann alone; «Markus» is `CUSTOM_41AC03BD`) and `__Z_F610_IBAN_874FECB2__`. Those values were never kept, so the order on the glass is:
  1. Open «ألماني 1.txt» in the conversation «ألماني» and protect it as usual.
  2. Close the app and open it again.
  3. Choose «z-pdf» and pick the PDF and then the `.txt`.
  4. Feldmann and the IBAN must both come back. If a token's derivation does not reproduce the old token, the report says so with the measurement; it is not papered over.
- **«Markus» on the second day:** open «ألماني 1.txt» again after a restart. «Markus» stands protected without a press.
- **Across conversations:** open «ألماني 2.txt» in a new conversation. Every word that is a block stands protected there.
- **A fresh z-pdf of «ألماني 1»**, saved and opened through «z-pdf» after a restart, brings back every name.

## Guards (pin today's wrong answer first)

- **Flip `a_taught_value_comes_back_after_the_bench_is_gone`:** every name comes back after the bench is gone, with nothing taught.
- **Restart:** close every bench, drop the core's state, open the vault again, and every name still comes back.
- **A block is never deleted:** un-protect «in this conversation», forget the conversation; the block is still there and the z-pdf still reads back. Enumerate every writer of the block table.
- **«Leave it» makes no block.**
- **«In this conversation» exempts in that conversation only:** a new conversation protects the same word.
- **Across conversations:** a block made in one conversation is protected on import in another.
- **A returning document through «z-pdf»** is not scanned and not protected (G34 stands). The number of tokens is the same before and after.
- **The saved document (rule 9):** a document in the preview survives a restart with every decision; a second document in the same conversation gets the next number; leaving by each of the four doors deletes its copy and retires its number (a new document never takes `doc1` again); going back keeps it; «Rename» changes the name and not the number; `chatN` for a chat text moved to the preview.
- **The measurement for the report:** the blocks, **by count, never by value**, before and after, and the size of `vault.zv` before and after.

## Seat and base

- **ed**, on **`eedc041`** (pushed). Branch locally; nothing pushed, no remote branch.
- Your ground: `vault/`, `ops/mod.rs` (`remember_in_vault`), `conversation.rs`, `ops/conversation`, `returning.rs`, `session_state.dart` and the glass sentences. e2 is resting; nobody else is in the scanner.
- The independent attacker sees this at «ready»: «nothing is kept» becomes «every protected word is kept, sealed, for ever».

## Not in this round

- «Review before send»: delete it, or show both texts (the owner's answer is pending).
