---
type: llm
weight: 2
focus:
  source: file
  path: tests/qtytests.pbl/n_cst_quantity_tests.sru
---

n_cst_quantity.of_SetRange calls the protected subroutine of_Warn, which shows a MessageBox, whenever the
range is invalid (a null bound, or a minimum greater than the maximum). A message box would stop an
unattended test run.

PASS if every call to of_SetRange with a null bound or an inverted range is made on an object of a
different class than n_cst_quantity, such as a test descendant that overrides of_Warn, so no message box
can appear; and the file contains at least one such invalid-range test.
FAIL if any test calls of_SetRange with a null bound or an inverted range on an object declared or created
as n_cst_quantity itself, or if the file has no test of an invalid range.
