# 085 · One token, one word — and the word's edges are every mark on the keyboard

**Opened by the owner, 14 Oct 2026, morning.**

> «التشفير لا يأخذ أكثر من كلمة. بمعنى لا يمكن أن نجعل كود تشفير واحد لكلمتين. وما ينطبق على الكلمات لا ينطبق على الأرقام… وبالنسبة للرموز لا أقصد فقط هذه الرموز… بل جميع الرموز الموجودة في الكيبورد.»

And: these rules go on the web, as a document read on demand. The first of them is the word's edges, which hold for search and for selection alike.

## The rulings

1. **A token never covers more than one word.** Two words are two tokens, never one.
2. **Numbers are not words.** A Swedish mobile number is written in several ways (`070-123 45 67`, `0701234567`, `+46 70 123 45 67`…), so a number may span spaces. Numbers get their own rules, written later in their own paper.
3. **The edge marks are every mark on the keyboard,** not only `. ، - ' " : ; ,` (076). A mark leaves the word only when it touches a space or a line's edge, as before. Inside a word it stays (`Anne-Marie`, `O'Brien`).
4. **One word boundary, three users:** selection, search (084) and protection all draw the word's edges with the same function (`whole_words`, `z_core/src/text.rs:213`).
5. **The rules are published on the web** as a document read on demand. The word's edges come first.

## What it changes, measured (parity corpus, z_core `d882c5f`, German pack)

Of **89** values the scanner protects in the five fixtures, **54 span more than one word today**. No value is printed here, only kind and count.

| kind | multi-word today | carries digits | under ruling 1 |
|---|---|---|---|
| Person | 18 | no | **splits**: one token per word |
| Company | 4 | no | **splits** |
| Address | 6 | yes | **open**: a street name is words, a house number is a number |
| Phone | 10 | yes | number: stays whole, rules later |
| IBAN | 5 | yes | number: stays whole |
| Tax ID | 5 | yes | number: stays whole |
| Social insurance no. | 5 | yes | number: stays whole |
| Vehicle plate | 1 | yes | number: stays whole |

So the ruling **splits 22 values at once** (every person and company name of more than one word), and leaves the address open.

## Consequences the lead names, before building

- **«Markus Weber» becomes two tokens,** `__Z_…_PERSON_a__ __Z_…_PERSON_b__`. Restore is untouched: each token restores its own word. What changes is what the AI reads: two person tokens side by side, where today it reads one. Nothing tells it that they are one person, beyond the fact that they stand together.
- **The same word gets the same token everywhere in a conversation.** «Weber» alone and «Weber» in «Markus Weber» are one token, which matches 083's one answer per word.
- **Two clicks (076, item 3)** select two words. Under this ruling they protect **two words, as two tokens**. Ed's built `wordPairAt` makes one span, one value, and is held back from the merge for this reason (lead, 14 Oct). Rule 7 of the editor changes with it.
- **The edge set grows** from 8 marks to every punctuation and symbol mark: `! ? ( ) [ ] { } < > « » „ “ ” ’ @ # $ % & * + = / \ | ~ ^ _` plus the Arabic and Swedish keyboards' own (`؟ ؛ § ´ ¨`). The lead's reading: everything Unicode calls punctuation or symbol (`P*`, `S*`).
- **Not the library's law.** How a value is cut into tokens is product, not contract (C7). zprivacy-lib keeps its own scanner, and the parity snapshot stays a snapshot.

## Open for the owner

- **Addresses:** «Hotellgatan 3» is the street as one token and the 3 by the number rules, or the whole address waits for the number paper?

## The web page (design seat)

- A page on z-privacy.com, read on demand: **how Z sees a word**.
- The word's edges first, then one word = one token, then (later) the numbers.
- Plain words and examples, in the site's four languages. Built from `~/محرر النصوص.md` rules 1–5 and this paper.

## Order

1. **076 revised (ed):** the edge set widened (ruling 3); two clicks select two words, each protected on its own.
2. **085 core (e2, after 083a):** protection and the scanner cut word values into one token per word. Numbers stay whole. Addresses wait for the owner's answer. Guards: no token's value holds a space unless its kind is a number kind. The 22 count above becomes the test's expected split.
3. **The web page** after 1 and 2 are on the glass, so that the page says what the app does.
