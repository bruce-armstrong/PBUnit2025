# Test doubles and fixtures

Patterns for testing code that has side effects, hidden state or visual parts. All of them come from a
working PBUnit suite (the PFC unit tests). Name helpers after the test library's prefix, for example
`n_pfctest_*`, `w_pfctest_*`, `u_pfctest_*`, and put them in the test library next to the tests.
Helper names must **not** end in `tests`, or the runner treats them as test classes.

## 1. Expose protected functions

A test descendant of the class under test adds public `...fortest` wrappers. Production code is unchanged.

```
public function integer of_loadsecurityfortest (string as_object);// Loads the settings for one object, as of_SetSecurity does before applying them.
Return of_LoadSecurity(as_object)
end function
```

The test creates the descendant instead of the original (`inv_security = Create n_pfctest_security`).
The same works for windows: a hidden `w_master` descendant can expose `of_GetOrigSize` and similar.

## 2. Record a side effect instead of performing it

Override the protected function that does the work (shows a window, starts a program, prints) and record
what it was asked to do:

```
type variables
Public:
string	is_appurl
integer	ii_appcount
end variables

protected function integer of_showinapp (string as_url);// Records the URL instead of opening the help window
is_appurl = as_url
ii_appcount++
Return 1
end function
```

The test then asserts `inv_help.is_appurl` and `inv_help.ii_appcount`. For an event, override it without
`call super::` so the ancestor's script doesn't run:

```
event pfc_print;// Overrides the printing: record it in the window's log
GetParent().Dynamic of_Log("print")
Return 1
end event
```

## 3. Fake an external service

When the code talks to a server through a protected function (here `of_Post`), the descendant plays the
server: it returns queued responses in order and records every request.

```
type variables
Public:
long		il_status[]
string	is_body[]
long		il_next
boolean	ib_unreachable
string	is_posts[]
end variables

public subroutine of_addresponse (long al_status, string as_body);il_status[UpperBound(il_status) + 1] = al_status
is_body[UpperBound(is_body) + 1] = as_body
end subroutine

protected function integer of_post (string as_url, string as_body, ref long al_status, ref string as_response);// The fake identity provider
is_posts[UpperBound(is_posts) + 1] = as_url + "?" + as_body
If ib_unreachable Or UpperBound(il_status) = 0 Then Return -1

If il_next < UpperBound(il_status) Then il_next++
al_status = il_status[il_next]
as_response = is_body[il_next]
Return 1
end function
```

The test queues the responses, calls the public function, then checks both the result and what was sent:

```
inv_oauth2.of_AddResponse(200, '{"access_token":"at-1","expires_in":3599}')
If Not assertEquals("signed in", 1, inv_oauth2.of_AuthorizationCode()) Then Return
assertEquals("access token", "at-1", inv_oauth2.of_GetAccessToken())
assertEquals("grant_type", "authorization_code", inv_oauth2.of_GetParameter(inv_oauth2.of_LastPost(), "grant_type"))
```

Override waits and timers the same way (record the requested delay and return at once) so tests stay fast.

## 4. DataWindow retrieves without a database

A `u_dw` descendant counts retrieve attempts and cancels them, and records database errors instead of
showing PFC's message box:

```
type variables
Public:
Long		il_retrievecount
Long		il_dberrorcount
String	is_lastdberror
end variables

event retrievestart;call super::retrievestart;// Count the attempt, then return 1 so the retrieval is not performed.
il_retrievecount ++
Return 1
end event

event dberror;// Overrides the PFC message box: record the error so a test can report it.
il_dberrorcount ++
is_lastdberror = String(sqldbcode) + " " + sqlerrtext
Return 1
end event
```

How `Retrieve()` behaves with this probe (measured with PowerBuilder 2025):

- The DataWindow object **must have a SQL source**. On an external DataWindow, `Retrieve()` returns -1
  without firing `retrievestart`, so the count stays 0. Use the production DataWindow object; don't make an
  external copy of it for the test.
- When `retrievestart` returns 1, `Retrieve()` returns **-1** and leaves the rows as they were. Code under
  test that passes on Retrieve's return value therefore returns -1 for a counted retrieve; don't expect a
  row count of 0.
- No database connection is needed, and `retrievestart` fires without a transaction object. Calling
  `SetTransObject(SQLCA)` (unconnected) does no harm; PFC's linkage tests do it on `u_dw`.

The same probe works as a DataStore descendant (`global type n_x_ds from datastore`, with the same
`retrievestart` script and `TriggerEvent( this, "constructor" )` create block of a nonvisual object) when
the code under test takes a DataStore.

This probe only tells you that a retrieve was attempted. To check the SQL and values that are retrieved or
written, to supply canned rows, or to watch embedded SQL, use `pbunitmocks.pbl` (pattern 10).

Load data with `InsertRow(0)` and `SetItem`, then call `ResetUpdate()` so the rows count as retrieved
(not new or modified).

## 5. Visual controls in a hidden window

Open a hidden host window in `setup`, create controls on it at run time, and close it in `teardown`
(closing the window destroys its controls):

```
type variables
Protected:
w_pfctest_host	iw_host
u_dw				idw_master
end variables

event setup;call super::setup;Open(iw_host)
iw_host.OpenUserObject(idw_master)
idw_master.DataObject = "d_pfctest_linkage_master"
end event

event teardown;call super::teardown;If IsValid(iw_host) Then Close(iw_host)
end event
```

`OpenUserObject(variable)` creates an object of the variable's declared type, so declare the variable as
the exact class you want (for example a probe descendant). Use a `w_master` descendant as the host when
the code under test expects a PFC window. Set `boolean visible = false` in the window source.

## 6. Posted events

Code that `Post`s an event finishes later. Let it run before asserting:

```
protected subroutine of_yield ();// Lets the posted events run
Integer	li_idx
For li_idx = 1 To 5
	Yield()
Next
end subroutine
```

## 7. Files, settings and other global state

- Create temporary files in `setup` with a name prefix specific to the tests (for example `pfct_`), and
  delete them in `teardown`, so a failed test doesn't leave files behind.
- Point settings at test files (for example an application manager's user INI file) in `setup`, and put
  the original settings back in `teardown`.
- Anything a test turns on globally (a theme, an application service, a registry value) is turned off
  or restored in `teardown`.

## 8. Tests that depend on the environment

- If an optional resource is missing (an installed theme, a font), skip the test quietly with a comment:
  `If Not FileExists(ls_theme) Then Return	// the theme isn't installed here`.
- If the test needs configuration that a developer must provide (a test database), fail with a message
  that starts `Not configured:` and says exactly what to set, for example
  `fail("Not configured: set PFC_SECURITY_INI to an INI file with the security database connection")`.
  Readers of the results can then tell setup gaps from real failures.

## 9. No seam to override

If the side effect is inline in a public function (a `MessageBox` call, `Run`, a file dialog), there is
nothing to override. Propose extracting it into a small protected function with the same behavior, so a
test descendant can override it as in pattern 2. Ask the user before changing production code.

## 10. Database access with pbunitmocks.pbl

If the test project lists `pbunitmocks.pbl` (in the framework folder, next to `pbunit.pbl`), use it for
anything that reads or writes the database. The framework README's "Testing database access" section has the
full API and an example; the essentials:

- `n_pbunit_mockdb.of_Connect(transaction)` connects to a scratch database it creates (AutoCommit off). Call
  `of_Disconnect` in `teardown` (it rolls back) and then destroy it (that deletes the file). PowerBuilder
  only generates SQL for a connected transaction, so the spies record nothing without this.
- `n_pbunit_spyds` / `u_pbunit_spydw`: `inv_recorder` records every retrieve and statement with its values and,
  by default, skips it. After `Update()`, check `of_GetStatementCount("UPDATE")` and
  `of_FindStatement("UPDATE", "amount = 99") > 0`; `of_SetCannedRows("1~t42~t10~r~n")` makes a retrieve
  return those rows (NotModified) and their count.
- `n_pbunit_spytr`: records embedded and dynamic SQL; `of_SetMode(BLOCKWRITES)` stops writes (SQLCode -1).
  Embedded `SELECT ... INTO` can't return made-up values: create its tables with `inv_db.of_Execute`.
- When the code needs its own class (`n_ds`, `u_dw`, `n_tr`), make a test descendant with an
  `n_pbunit_dwrecorder` (or `n_pbunit_trrecorder`) instance and forward `retrievestart`, `retrieveend`,
  `sqlpreview`, `updatestart` and `dberror` to its `of_On...` functions, as `n_pbunit_spyds` does. Don't call
  the ancestor's `dberror` if it shows a message box (PFC's `u_dw` does).
- If the class already scripts `sqlpreview`, extend it and keep its answer when it skips (2) or stops (1) a
  statement. PFC's `u_dw` skips the statement types an update leaves out, which the linkage service's
  two-pass update styles rely on; replacing its script would record, and break, those passes:

  ```
  event sqlpreview;call super::sqlpreview;If AncestorReturnValue = 1 Or AncestorReturnValue = 2 Then Return AncestorReturnValue
  Return inv_recorder.of_OnSqlPreview(sqltype, sqlsyntax, row)
  end event
  ```
- To check the order of statements across several DataWindows (a master and its details), let the spies
  share one recorder: destroy the second spy's recorder and assign the first one's
  (`Destroy idw_line.inv_recorder` then `idw_line.inv_recorder = idw_head.inv_recorder`; each spy's destructor
  checks `IsValid` first). Then build a short description of the sequence, for example
  `"DELETE pfct_line 3, DELETE pfct_head 3"` (type, table, key), and compare it with `assertEquals`: a
  failure shows the whole expected and actual order.
- Assert on fragments (`"amount = 99"`), not whole statements: the SQL is in the connected database's
  dialect. Check `of_GetDbErrorCount()` is 0: with the error suppressed, `Update()` returns 1 even when it
  failed.

A worked example in PFC (OpenSourcePFCLibraries/2025-Solution, `tests\pfctests.pbl`):
`n_cst_dwsrv_linkage_update_tests` saves a linked master and detail through the linkage service with each
update style and checks the statement order; `u_pfctest_spydw` is the `u_dw` spy, with the `sqlpreview` and
`dberror` handling above; `d_pfctest_head` and `d_pfctest_line` are the updatable DataWindows. Nothing reaches
a database: `n_pbunit_mockdb` connects PFC's `n_tr` to a scratch database and the spies skip every statement.
Its `TOPDOWN_BOTTOMUP` test was shown to fail by making the linkage service's delete pass run top-down.
