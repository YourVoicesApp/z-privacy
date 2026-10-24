# 108 — What Windows showed the glass: the session's name, the file's name, the way back on top, and a way to write to us

**Source:** the owner, 24 October 2026, from what his own Windows evenings showed him; «نعم» the same morning. Publishing is postponed for this round and paper 107. Builder: **e2**. Branch off `c0326af`. **Do not touch `docs/CLAIMS.md`**: it is ed's in this round (107). Send the lines you need through the lead.

Five items. Each one names the owner's own words, and each gets a pin that is red on `c0326af`.

## 1 · The session's name on the main screen

Owner: «عند الضغط على الجلسة يجب أن يظهر اسم الجلسة على الشاشة الرئيسة». When a person presses a session, its name stands on the main screen, where the work is, not only in the Sessions room. It stays true as the open session changes (a new birth, an open from the list, a rename). Read it from the core's open session, the one source. Never from a remembered string (the seam lesson: a guard cannot tell two sources apart when they agree, so write the case where they differ). Nothing open means no name is drawn, and no placeholder pretending to be one.

## 2 · Saving a PDF asks for the document's name, and the file carries both

Owner: «نجعل اسم الجلسة داخل باسم الوثيقة. والحفظ يحتاج إلى كتابة اسم للوثيقة من قبل المستخدم». The PDF press asks the person for a document name first. The file name is built from **the session's name and the typed name** together. Today it is `<session>-protected-<date>.pdf`, so two vaults' files of one date collide, which is exactly the trap Windows' first read-back fell into: the same name in `Documents\ZPrivacy` from another vault. Keep the date if it still helps the person tell versions apart; your call, named. An empty name refuses the press with a sentence, never a silent default. A name holding a path separator or a character the platform's file system refuses is handled on both platforms (`a_path_is_compared_in_one_spelling`), with a pin for each.

**One sentence the dialog must carry, because this is a privacy product:** the file's name is **not** protected. It leaves with the file exactly as typed. Say it short, beside the field, e.g. «The file name stays as you type it. Don't put real names in it.» (081 is why the person's own document name never went into the PDF. This is the person's choice made visible, not a reversal.)

## 3 · The z-pdf door moves to the top of the screen

Owner: «زر جلب وثيقة Z-PDF نجعله خياراً منفصلاً في أعلى الشاشة؛ الآن مكانه مخفي». This **amends rule 70's placing** (17 Oct: «نجعل الإعدادات تحتوي على إدخال z-pdf»). Say so in the comment where it moves, with both dates. The press goes onto the top bar as its own option. The vault gate and `_readBack()` (shell.dart) travel unchanged: a locked vault opens the vault, never a sentence. Decide whether the Settings entry stays as a second way in or goes. One press in two places is two things to keep true. Name the choice. «A new element in the tree breaks every `.first`»: run the whole Dart suite, not the file.

## 4 · A restored z-pdf can be saved as a PDF

Owner: «نجعل وثيقة z-pdf يمكننا حفظها بعد فك التشفير… أعتقد فقط يكفي خيار حفظها في الذاكرة كوثيقة pdf». The reading (`TheReading`, `widgets/the_way_back.dart`) gains one press, **save as PDF**. It writes the restored text, with the values put back, to a file the person chooses through the system save dialog. **Saving only. Printing is out by the owner's word.**

Rules:
- It is the person's own document with their own values. It is **not** a z-pdf: no answer page, no token footer, no «protected» stamp. Nothing in it may claim protection. Tokens that stayed tokens (unresolved names) stay exactly as they are in the restored pieces, never invented.
- Pass `ReturnedDocument.restored` through as it is. A screen does not re-derive the restoration.
- **This is a new file the app writes with real values in the clear.** Paper 104 made «the files this app writes» true sentences (C-06, said in two places, incl. key `yourNamesLiveInOneVaultFile`'s room). Find every sentence that enumerates what the app writes. Say in your report what each must become. Glass/arb lines you change yourself, and CLAIMS.md lines go to the lead for ed.
- Pin: a fixture z-pdf read back through the test vault, saved, and the saved file read back through a real reader (`pdf_byte_search_cannot_see_its_own_text`) holds the restored value and no token for it.

## 5 · The contact address in Settings

Owner: «نضع إيميل الفيدباك في التطبيق في الإعدادات… ونجعل zprivacy@mono-peak.com هو إيميل التواصل». **Narrowed by the owner the same morning, and this narrowing governs:** «لا نحتاج إلى أي نافذة؛ نجعل بريد الفيدباك مستطيل نص قابل للنسخ، ونشرح: انسخ الإيميل وأرسل من إيميلك مباشرةً… لا نافذة ولا أي شيء».

So Settings gains **one copyable text box** holding `zprivacy@mono-peak.com`, and one sentence beside it: copy the address and write to us from your own email. Add «describe the problem, don't send your documents» if it fits in the same sentence. **No `mailto:` press, no form, no window, no network door.** The app sends nothing and opens nothing. C-03 («no Z Privacy server») and its gates stand untouched. Copying is selectable text or a copy press that puts the address on the clipboard, your call. If it is a press, it is the one clipboard write this item makes, and it carries the address alone. The site is **not** touched for this item, because the address already stands there.

## The one list

Every new sentence goes into `app_en.arb` with `app_de.arb` and `app_sv.arb` beside it. Swedish is written, not reviewed (106's debt grows by these keys, and `check_the_one_list.py` counts them). Keep your keys in one block apart from 107's so the two merge cleanly.

## Measurement

e2: `bash scripts/gates.sh` green, the five red-first pins named, the site gates green in tree mode (the download placeholder still lawfully red until publishing day), and the list of every «files this app writes» sentence with what it must become. The lead merges 107 and 108, measures and writes `MEASURED_ON_LINUX.txt`. The owner runs Windows on the merged tip. Then publishing day.
