# Design note: patch-id as rebase evidence

| Option | For | Against |
|---|---|---|
| A. patch-id recorded as evidence at the existing amend/rebase rule | Mechanical, small, keeps judgment | One more field |
| B. patch-id match decides `behavioral: no` (pstack shipping) | Fully mechanical | Misses base changes that alter dependencies or story paths |

**Choice:** A.

**Sacrifices:** classification still needs judgment when the base moved.
