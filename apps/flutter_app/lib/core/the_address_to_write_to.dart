// **The one address a person writes to** — the owner, 24 October 2026 (paper
// 108 item 5): «نضع إيميل الفيدباك في التطبيق في الإعدادات… ونجعل
// zprivacy@mono-peak.com هو إيميل التواصل».
//
// One constant in one file, because of what this round decided **not** to
// build. The first shape of this item was a press that handed `mailto:` to the
// operating system; the owner narrowed it the same day: the settings show the
// address in a box a person can copy, and **this application opens nothing and
// sends nothing**. So the address is not an argument to any door — it is a
// fact on the glass, and it lives here rather than in
// `core/the_system_browser.dart`, whose whole subject is the one place this
// program hands an address to the machine. A mailbox that is never handed to
// anything does not belong in that file, and putting it there would have made
// that file's own claim harder to read.
//
// It is not in the one list either. An address is not a sentence: the same
// characters in every language, nothing to translate, and `check_the_one_list`
// says so by name.
const theContactAddress = 'zprivacy@mono-peak.com';
