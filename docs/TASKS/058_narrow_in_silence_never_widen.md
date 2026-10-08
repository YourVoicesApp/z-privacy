# 058 · Narrow in silence, never widen

Found by the programmer while building a lever for 050/C, and worth more than
the fix he was building. Measured by me afterwards in `secure_file.rs`.

## What happens

`secure_dir` runs on **every** write path — `replace_atomically` calls it before
it writes — and ends with, unconditionally:

```rust
// G15-ok: narrowing the private folder that holds ZVLT and ZCFG.
std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700))
```

Two consequences, and they are not the same kind of thing.

**One, for us.** A read-only data folder is **not a lever for any test**: Z mends
the folder and writes anyway. Anyone reaching for `chmod 500` to make a write
fail gets a **false green**. The lever that does work is a leftover
`vault.zv.new` — which is also a state a person can really be in, because it is
what a write killed half-way leaves behind.

**Two, for the person.** From `0o755` this narrows, which is right and should
stay silent. From `0o500` it **widens**: Z gives itself back the write
permission the owner of the machine took away, and says nothing. The comment
calls the line «narrowing», and in the only case that matters it is the
opposite. A comment that misnames what its line does is the same family as a
seal that misnames its build (052).

For a product whose whole claim is that nothing happens to your data without
your word, *«the app re-granted itself a permission I had removed»* is a
sentence that loses a room.

## The rule

**Narrow in silence, never widen in silence.**

- mode is wider than `0o700` → tighten it, say nothing. This is a mend and it is
  the common case, a folder made by the default umask.
- mode is narrower than `0o700` → **do not touch it.** Refuse the write, and
  name the true cause: *«the folder that holds your vault has no write
  permission, so nothing can be saved there. Z Privacy will not change
  permissions you set.»*

The second half is the whole point. Z already refuses rather than choosing for
the person when a press lands between two columns; a folder the person locked is
the same question with higher stakes.

## Do

1. Read the mode before setting it. Widen never; tighten silently; refuse with
   the true cause when the folder is tighter than `0o700`.
2. Fix the comment to say what the line does.
3. **Guards:**
   - a folder at `0o755` is silently brought to `0o700` and the write succeeds;
   - a folder at `0o500` is **left at `0o500`** and the write is refused by a
     sentence naming permissions — not by the generic «that place cannot be
     used safely»;
   - and the one that would have caught this: after any refused write, the
     folder's mode is **unchanged from what the test set it to**.
4. Write the `vault.zv.new` lever down where the next person will look for it —
   a leftover temp file is the honest way to make a write fail.
