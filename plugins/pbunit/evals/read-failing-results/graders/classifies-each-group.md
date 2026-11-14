---
type: llm
weight: 3
---

The run had 172 tests: 139 passed, and three groups did not:
1. 27 n_cst_security_groups_tests failures, all "Not configured: set PFC_SECURITY_INI to an INI file with
   the security database connection".
2. 1 n_cst_dwsrv_linkage_tests error: runtime error 40, mismatched ANY datatypes (string, double), inside
   pfc_n_cst_dwsrv_linkage.of_retrievedetails line 96, which is PFC code.
3. All 5 n_cst_sort_tests tests erroring with a null object reference in n_cst_sort_tests' own setup event,
   line 9.

PASS if the reply does all of:
- says group 1 is a missing setting (PFC_SECURITY_INI) for tests that need a security database, not
  something the user's change broke;
- treats group 2 as a likely real bug in the PFC linkage code (of_retrievedetails comparing values of
  different types) that needs investigating or fixing;
- locates group 3 in the sort test class's setup (its line 9), as a fixture or setup problem to look at
  first, rather than saying the sort service's own logic produced wrong results;
- does not recommend deleting, skipping or weakening tests to make the run pass.
FAIL if any of these is missing or wrong.
