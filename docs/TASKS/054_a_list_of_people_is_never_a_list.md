# 054 · A list of people is never a list

The owner, 8 October, after finding the import himself:

> «وجدتُ خيار إضافة قوائم داخل اللغة، وهو كان موجوداً منذ اللحظة الأولى… تبقى
> البيئة هي اللغة، وإن كانت القوائم تحتوي على لغات أخرى فهذا ليس بالمشكلة
> الكبيرة.»

**He is right, and the code already says so in his words.** `name_review.dart`
asks three questions — which file, *«Which language are these names?»* («a list
is a language»), and how far it reaches — and the core refuses a list name that
is not a language with a sentence of its own. So **046/I is settled by the
owner's ruling and needs no new architecture.** What is left is one defect.

## What a list is worth — measured

English pack on the Swedish payroll file, with his own `FarukAB_people.csv`:

| | findings | of his 20 names, still in the clear |
|---|---|---|
| before the list | 42 | **7** |
| import | `added 21 · already 0 · refused 0` | |
| after the list | 60 | **0** |

**Seven leaking names became none, from one file he already had.** This is the
act he described from the first day, and it works today.

## The defect

```
import_user_names(his CSV, list "FarukAB", Always)  → Ok(added: 21)
user_lists()                                        → Ok([])

import_user_names(given/family, list "Svenska namn") → refused:
    «svenska namn» is not a language this build knows; a list is a language, one for each
user_lists()                                        → Ok([])
```

One function, one `list` parameter, **two fates**:

- a row typed `given` or `family` goes to `teach_name_into(…, list)` and the
  list is kept — and an unknown list name is **refused out loud**;
- a row typed `person` or `company` goes to `put_own_value(…)`, which takes no
  list at all, so the name the person chose is **accepted and thrown away in
  silence**.

A client book is people and companies. So **the only kind of list the owner will
ever import is the kind that never becomes a list.** The consequences are all
things he can see:

- it does not appear anywhere — `user_lists()` is empty after 21 names;
- it has no count, so «how many did that file teach me?» has no answer;
- `UserListRow.enabled` exists — *«Off means the scanner is not told about
  them»* — and **cannot be reached for the only list he has**. Import the wrong
  file and the way back is to delete twenty-one values by hand;
- and a year from now nothing in the vault says where those names came from.

This is the rule the project already keeps, broken inside one function:
**wherever two places can disagree about a fact, one of them is already wrong.**

## Do

1. **A person or a company joins the list it was given**, exactly as a given
   name does. `put_own_value` carries the list; `user_lists()` counts values as
   well as taught names.
2. **The same refusal on both paths.** An unknown list name is refused for
   person and company too — never accepted and dropped. The owner's ruling
   stands: a list is a language, and a list that holds other languages is not a
   problem.
3. **The panel shows every list**: its name, its count, its switch.
4. **Guards, and the third one must bite:**
   - after importing his CSV into `en`, `user_lists()` holds one row, `names:
     21`;
   - an unknown list name is refused for a `person` row with the same sentence
     it already gives a `given` row;
   - **switch the list off and the seven names come back into the clear; switch
     it on and they are protected again.** A switch that does not change what
     leaves is worse than no switch, and nothing tests it today.

## And one thing the owner should know

His CSV imported **21 rows from 21 lines** — the company row went in too, as a
company. Nothing was refused. The file he wrote for the film is already a
working client book.
