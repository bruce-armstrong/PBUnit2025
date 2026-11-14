---
type: llm
weight: 2
focus:
  source: file
  path: tests/orderstests.pbl/n_cst_orderloader_tests.sru
---

The tests are for n_cst_orderloader and must run without a database. of_Load(ads_orders, al_customer)
returns -1 without retrieving when ads_orders isn't valid or the customer is null, zero or negative;
otherwise it remembers the customer and returns what ads_orders.Retrieve(al_customer) returns. of_Reload
returns -1 without retrieving when no customer has been loaded, and otherwise retrieves again for the
remembered customer. Without a database a retrieve never returns rows: it fails with -1 (no connection), or
returns -1 when a retrievestart event cancels it.

A test can detect whether a retrieve happened in any reliable way, for example by counting retrievestart
or dberror events in a DataStore descendant, or by putting a row in the DataStore first and checking
whether the retrieve cleared it. Judge only whether the tests prove the behavior, not which way they do it.

PASS if the tests prove all of:
- a valid customer makes of_Load retrieve (not only that the customer number is remembered);
- a null, zero or negative customer returns -1 without a retrieve;
- of_Reload before any load returns -1 without a retrieve;
- of_Reload after a load retrieves again;
and no test expects of_Load or of_Reload to return 0 or a row count from a retrieve that, in that test,
can only fail or be cancelled.
FAIL if any of those is not proven (for example, the tests only check of_GetCustomer after a valid load),
if a test expects 0 or more rows from a retrieve that can't succeed, or if the tests need a real database.
