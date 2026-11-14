---
type: llm
weight: 2
focus:
  source: file
  path: tests/orderstests.pbl/n_cst_orderloader_tests.sru
---

The tests exercise n_cst_orderloader with a DataStore whose retrieves are counted and cancelled in its
retrievestart event (no database). of_Load and of_Reload return what DataStore.Retrieve returns, and a
retrieve cancelled in retrievestart returns -1. of_Load returns -1 without retrieving for a null, zero or
negative customer or an invalid DataStore; of_Reload returns -1 without retrieving when no customer has
been loaded.

PASS if the tests check all of: a valid customer causes exactly one retrieve; a null, zero or negative
customer returns -1 with no retrieve; of_Reload before any load returns -1 with no retrieve; of_Reload
after a load retrieves again. They also must not expect of_Load or of_Reload to return 0 or a row count
for a retrieve the probe cancelled (expecting -1 there, or not checking that return value, is fine).
FAIL if any of those checks is missing, if a test expects 0 or more from a cancelled retrieve, or if the
tests rely on a real database.
