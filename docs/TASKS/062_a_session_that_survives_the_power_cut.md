# 062 · A session that survives the power cut

**The owner's design, 8 Oct 2026.** Not built, and not for tomorrow.
**Raised by him, in his own words:**

> «أنا أعمل على جلسة ولدي مجموعة أعمال وانقطع التيار الكهربائي هل أعيد كل شيء
> من البداية… أحياناً الذكاء الصناعي يحتاج إلى أكثر من جلسة حتى يفهم الموضوع.»

---

## What exists today, measured

```
z_core/src/session.rs:384     sessions: BTreeMap<u32, Session>
z_core/src/vault/model.rs     no session anywhere in the vault's bytes
model.rs:120                  "Unlike a session dismissal, this is knowledge
                               and therefore lives in the [vault]"
```

A session is **a number in memory**, and it dies when the process does. That
comment proves it is a decision, not an oversight: a session was defined as *not
knowledge*, so it was deliberately left out of the vault.

## The owner's design

* An **internal number** — session 1, 2, 3 — and a **name** the person gives.
* The **conversation is kept in it**.
* The session has **its own key**, and **that key is kept in the vault**.
* Entry is the vault passphrase we already have.

Three reasons, and the third is the one that changes the priority:
completing a conversation with the model · finding an old protection ·
**a model often needs more than one session to understand a subject.**

**The design is right.** What follows is what it still needs.

---

## 0 · The name: the first three words — of the question, not the document

The owner's rule is the first three words. **Of which text** is the one thing it
does not say, and the answer matters: the document's name is already shown beside
the row, and **two sessions on one document are told apart only by what was
asked.** So the question's first three words, and the document's name beside it:

```
3 · «أين المشكلة المحاسبية»     EN-3_overtime_ledger.txt    today 18:41
2 · «هل هناك أسماء باقية»       Brief_Weber.txt             yesterday
```

The **number is the identity** and never changes; the **name is a handle** and may
be changed at any time. That is already the rule for a profile id, `p-<slug>-<n>`,
whose comment reads: *the person never typed it*.

And where a session is **created** is not settled: the owner offered settings, but
settings do not exist inside a document (061 §5), so a session could not be begun
while working. One of those two has to move.

## A · The vault holds the keys. The sessions are their own files.

His sentence already says it — *«فك الكود الخاص بها يحفظ في الخزنة»* — and it is
the correct reading, for a reason worth writing down.

`vault.zv` is encoded and **re-sealed whole** on every change
(`format::encode` → `reseal_body`). Put conversations inside that body and every
save rewrites every byte a person owns, and the file grows without a ceiling.

So: **one sealed file per session**, and the vault keeps only the number, the
name and the 32-byte key. Deleting a session is then destroying 32 bytes, not
rewriting a vault — the same move `change_passphrase` already makes.

And the key takes **its own purpose string**, as `crypto.rs:76` requires of every
new purpose. `Purpose::Profile` is already reserved there as the owner's
"future-profile key"; a session purpose sits beside it. A leak of the decoded
vault body is then still not a leak of a conversation — **true only once the
session key is itself sealed inside the body under a fourth purpose,
`z-privacy/vault/1/session-key`, the provider-credential pattern of 021. The
builder caught this sentence running ahead of its mechanism; 064 carries the
fourth purpose for it.**

## B · Today's loss is smaller than it looks, and the difference is measurable

A token is **derived, never stored** (046/U): the tail is MAC(key, "value",
nfc(value)) and the namespace is MAC(key, "namespace", profile ‖ document-text).

So after a power cut the map is not necessarily gone: reopen **the same document**
with the **same values still in the vault** and the same tokens should be derived
again. What is lost for certain is the **conversation**, and any token whose value
was never learned into the vault.

**This is a property, not an opinion, and it has not been measured.** It decides
how bad today's loss is, and it is one test: protect a document, note a token,
close the app, reopen the same document, and compare. If the token is identical,
every document already sent out stays restorable. If it is not, they do not — and
then 062 is a debt, not a feature.

## C · A restored session whose document moved must refuse, not guess

The namespace is derived from the document's text. Edit the document and the
namespace changes, so new tokens will not match the old ones.

A session therefore records which document it belongs to, and **says so when the
document no longer matches**. A restored session that silently derives different
tokens for the same people is worse than one that refuses — it is the family of
*a guard green for the wrong reason*, wearing the product's face.

## D · The lock must not become the power cut again

The vault auto-locks. If the session key only lives in memory while unlocked,
then an auto-lock loses what a power cut loses, and the whole task is undone by a
timer. The sealed session file must survive the lock; only its key is forgotten,
and the next unlock brings it back.

## E · And the trade the owner must name

**A saved session is the most sensitive object this product will ever hold** —
heavier than the name list, because it ties one document's tokens to particular
people, with the conversation beside them. Today it dies with the power, and that
is a privacy property as much as a defect.

Persisting it buys continuity with a durable secret. That is his call, and it is
the same shape as 059: the user chooses their own risk, and we state the price.

---

## F · Settled by the owner, 8 Oct — and my question was the wrong one

I asked whether every session is saved or only a named one. He had already
answered it, and the answer is better than the question: **a name is not asked
for a session, it is asked when there is no session.**

```
working with no session  →  press Copy, or export a PDF  →  asked once, the session is born
entering an old session  →  nothing is asked
```

~~A session is therefore **never created by a button**. It is born of the act that
makes it necessary — text leaving the machine — and that dissolves the problem
of where a «New session» control would live (061 §5): nowhere, because there is
no such control.~~

**Struck 9 Oct, and the mistake was this paper's, not his.** The owner's own
assignment of the workshop had already named the control, in the same breath as
the panel: «نجعل داخل الإعدادات إنشاء جلسة جديدة، البنك، وقائمة بأسماء الجلسات
السابقة». The sentence above was the lead's over-extension from the exit-birth
design, written on a night when the exit was the only door in the program. Both
doors exist and they produce **the same birth**: the panel's «جلسة جديدة» asks
the name in place and opens a fresh session on purpose; the exit still asks when
no session is open, as the net under whoever never pressed the button. The
deliberate road and the inevitable road meet at the same vault write, so the
promise still attaches at the boundary either way.

And the button is older than this paper: 022's own title reads «M7.1: القشرة
(Home · جلسة جديدة · Workspace)» — the owner had named that room at the shell's
birth, and `new_session.dart` is its corpse, orphaned by 041-G and now removed.
The panel's button is a resurrection, not an invention. (The programmer seat
found the title; the design seat found the corpse.)

### What is kept follows where the conversation happens

* **Inside the app** (a key is connected) — the conversation whole.
* **Outside the app** (he copies into a browser) — **the question, which is what
  was copied, and the answer, which is what came back.** That pair is the least
  that restores, and we do not pretend to hold what we never saw.

### Deleting is easy, and it carries a warning

His words: any protected document or message **cannot be unprotected after its
session is deleted**.

That is the right wording, and it is stronger than the mechanism strictly
requires — deliberately. A token is derived, not stored, so a value **still
taught to the vault** may be re-derived from the same document. But **a value
protected once and never learned dies with the session**, and a promise of
partial recovery is worse than none. So the warning says the hard thing.

**And that is exactly the property §B says is unmeasured.** The same test settles
both: it tells us how much the warning overstates, and whether 062 is a feature
or a debt.

Nothing here is built. The freeze stands, and this is a new feature.
