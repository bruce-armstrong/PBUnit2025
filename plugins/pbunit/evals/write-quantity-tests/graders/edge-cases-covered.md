---
type: llm
focus:
  source: file
  path: tests/qtytests.pbl/n_cst_quantity_tests.sru
---

The class under test clamps values to a range (0 to 100 by default) with of_Clamp, and of_SetRange
returns 1 for a valid range and -1 for an invalid one, leaving the range unchanged.

PASS if the tests check all of: of_Clamp with a value below the minimum, above the maximum, and inside the
range; a successful of_SetRange; and of_SetRange returning -1 for an inverted range or a null bound.
FAIL if any of those is missing.
