# 055 · Three acts while the person is typing

The owner, 8 October, proposing `Alt+Z` to protect while typing, a «z» on a
selected person meaning *this section will be encrypted*, and words from the
dictionaries appearing as he types. He approved this order after the measurement
below.

## What is already here

| | today |
|---|---|
| keyboard shortcuts | **built** — `Alt+←` home, `Esc` closes the bubble (`workspace.dart:147`) |
| the dictionary lookup | **built end to end** — `search_vault` → `searchVault` → the vault screen's search box |
| when the typed question is scanned | on **«Add it to what will leave»** (`bench.setQuestion`), not while typing |

That last row is the contract to keep: a question is text, and text is scanned
in the one door (046/N). **Nothing below may replace it.**

## 1 · Suggestions from your own lists while typing — first, because it is cheap and safe

As the person types in the question box, offer the names this vault already
knows. It changes nothing about what leaves — the door still scans — and it
answers a real gap: today there is no way to know a name is in your list without
opening the vault screen.

**And one hard rule, or we build the leak ourselves.** A suggestion list puts
vault contents on a screen that may be shared, filmed, or standing in an office.
So:

- the row shows **the name, never the value**, and inserts the value;
- it never reaches past the **active profile** — a suggestion is a statement
  about who this client is;
- it obeys the idle lock like any other reveal: a locked vault suggests nothing;
- and it is off while a reveal is on screen.

**Guards:** a locked vault returns no suggestions · a value from another profile
never appears · the row's text is the name and the value is not in the widget
tree.

## 2 · `Alt+Z` — protect the word just finished

**Not** «start protecting as I type». Every rule this project has paid for is a
rule about an **edge**: a name ends where the name ends (046/C) · a number ends
where the column ends (046/M) · a selection may not cross a line (053). **A word
still being typed has no right edge yet.**

And it would protect *worse*. `Organisationsnummer: 559000-0000` is found
because of the label **before** it; a value protected at the moment of typing is
protected with no context at all. The door sees the sentence; the keystroke does
not.

So `Alt+Z` means: **the word I have just finished** — the edge is the space or
mark that was typed — and it is also **taught**, so it is protected in every
document after this one. That is what the owner means by «for the new names».

**Guards:** `Alt+Z` after a space protects the word before it, not the empty
space · pressed mid-word it refuses with a sentence rather than guessing · the
taught value appears in the vault with the profile it was taught under.

## 3 · Protect a chosen region whole — not a mode

The owner's «this section will be encrypted» is worth building, but as an **act
with an edge**, not a state. This app has refused modes everywhere: nothing folds
itself, and Z will not choose a column for you. **A mode you forget you are in
protects the wrong thing, or stops protecting and says nothing.**

So: select a region, press once, every value inside it is protected — the
sibling of the column reached by example (046/Q), applied to a block. One press,
a visible edge, no state to forget.

**Guards:** the region's own text is unchanged outside it, character for
character (the `the_token_stands_where_the_value_stood` property) · a region
that crosses a page boundary protects both halves · an empty region refuses.

## 4 · Never a live typing mode

Written down so it is not proposed again: protection while the keys are moving
has no edge, no context, and no way to show the person what it has decided. The
door stays the door.
