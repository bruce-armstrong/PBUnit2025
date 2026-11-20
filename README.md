# PBUnit 2025

A unit testing framework for PowerBuilder 2025 solution-format projects (`.pbsln` / `.pbproj`).

It is based on [PBUnit](https://sourceforge.net/projects/pbunit/), John Urberg's port of JUnit to PowerBuilder,
which is no longer maintained. Development started from a copy of Frank Mao's
[PowerUnit](https://sourceforge.net/projects/powerunit/) fork
(see his [quick start](https://maonet.wordpress.com/2008/02/05/pbunitpowerunit-quick-start/)), but the PowerUnit
additions have since been removed, so the core is PBUnit 3.0's code.
This version keeps the original `testcase` model and replaces the GUI runner with a command-line runner:

- more assertions: `assertEquals` for common types, `assertTrue`/`assertFalse`/`assertNull`, `assertRowCount`, `assertThrows`
- automatic test discovery: no list of test classes to maintain
- runtime errors in a test are reported as test errors instead of stopping the run
- text and JUnit XML results, and a process exit code that build scripts and CI servers can check
- a PowerShell script that builds the test project with PBAutoBuild and runs it

## Contents

| Path | What it is |
|---|---|
| `pbunit.pbl` | Core: `testcase`, `testsuite`, `testresult` and the assertions |
| `pbunitfunc.pbl` | `f_catchsystemerror`, for an application's `systemerror` event |
| `pbunitrunner.pbl` | `n_pbunit_runner` (command line, discovery, reports) and `n_pbunit_result` |
| `pbunitmocks.pbl` | Test doubles for database access: a scratch database, and recorders and spies for DataWindows, DataStores and transaction objects (optional) |
| `scripts/Invoke-PBUnit.ps1` | Builds a test project, runs it and prints the results |
| `selftest/` and `pbunit_selftest.pbproj` | The framework's own tests, and an example test application |
| `plugins/pbunit/` and `.claude-plugin/` | A Claude Code plugin with skills for writing, running and interpreting tests |

## Adding PBUnit to a project

1. Add this repository to your project, for example as a git submodule:

   ```
   git submodule add <url of this repository> tests/framework
   ```

2. Create a test project (`.pbproj`) whose entry library holds your test application and test cases.
   List the PBUnit libraries after it, followed by the libraries under test:

   ```xml
   <Libraries AppEntry="tests\mytests.pbl">
     <Library Path="tests\mytests.pbl"/>
     <Library Path="tests\framework\pbunitrunner.pbl"/>
     <Library Path="tests\framework\pbunit.pbl"/>
     <Library Path="tests\framework\pbunitfunc.pbl"/>
     <Library Path="src\myapp.pbl"/>
   </Libraries>
   ```

3. Create the test application. Copy `selftest/selftest.pbl/pbunit_selftest.sra` and adjust the globals your
   code expects (for example, a PFC application declares `sqlca` as `n_tr` and creates `gnv_app`). The `open`
   event only needs:

   ```
   n_pbunit_runner	lnv_runner
   Integer				li_exitcode

   lnv_runner = create n_pbunit_runner
   li_exitcode = lnv_runner.of_Run(CommandParm())
   lnv_runner.of_Exit(li_exitcode)
   ```

   `of_Exit` ends the process at once, so do any cleanup (such as destroying `gnv_app`) before calling it.

4. Ignore the generated registry, `n_pbunit_registry.sru` in the entry library, and the build output folder.

## Writing tests

A test case is a class that inherits from `testcase` and whose name ends in `tests`.
Each test is an event whose name starts with `test` and that takes no arguments.
Every test runs on a new instance of the class, with the `setup` and `teardown` events around it.

```
global type n_cst_string_tests from testcase
event test_trims_both_ends ( )
end type

event test_trims_both_ends();n_cst_string	lnv_string

assertEquals("abc", lnv_string.of_Trim("  abc  "))
end event
```

### Assertions

Each assertion returns `true` if it passed. Most have an overload that takes a message as the first argument,
which is prefixed to the failure text.

| Assertion | Failure text |
|---|---|
| `assertEquals(expected, actual)` for string, long, decimal, boolean, date, datetime | `expected <10> but was <20>` |
| `assertTrue(condition)`, `assertFalse(condition)` | `Expected true` / `Expected false` |
| `assertNull(value)`, `assertNotNull(value)` | `Value is not null` / `Value is null` |
| `assertIsValid(object)` | `Object is not valid` |
| `assertRowCount(datawindow or datastore, expected)` | `datastore row count: expected <2> but was <0>` |
| `assertThrows("event_name")` | `Expected event event_name to throw` |
| `assert(message, condition)`, `fail(message)` | the message |

Two null values are equal; a null and a non-null value are not.

`assertThrows` triggers an event on the test case and passes if it throws (including PowerBuilder runtime
errors). PowerScript has no closures, so put the code that should throw in its own event, and do not start
that event's name with `test` or it will also run as a test.

## Running tests

```
pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project mytests.pbproj
pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project mytests.pbproj -Filter "n_cst_string_tests.test_trim*"
pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project mytests.pbproj -Platform 64
```

The script:

1. finds the test classes in the project's libraries and writes `n_pbunit_registry.sru` into the entry library,
2. builds the project with `pbautobuild250.exe /pbc /d` and moves the PBDs next to the exe,
3. runs the exe and prints `results.txt`; `results.xml` is written beside it.

Options:

| Option | Meaning |
|---|---|
| `-Platform` | `32` (the default) or `64`: build a 32-bit or 64-bit exe (PBAutoBuild's `/x` option). The script checks the exe's machine type and stops if it doesn't match. Run the tests both ways if your code calls Windows functions (external functions), since pointer and handle sizes differ |
| `-OutDir` | Output folder; the default is `build\<project name>`, or `build\<project name>-x64` for a 64-bit build |
| `-Filter` | Tests to run, as for `/filter` below |
| `-TimeoutSeconds` | How long the run may take (the default is 300) |
| `-PBAutoBuild` | The path to `pbautobuild250.exe` |

The `CMP:` line of the project's `.srj` file doesn't choose the platform for a command-line build; `-Platform`
does.

| Exit code | Meaning |
|---|---|
| 0 | All tests passed |
| 1 | At least one test failed or had an error |
| 2 | Nothing ran or the run could not complete: build failure, no tests found, unknown argument, timeout |

The test exe can also be run directly, or from the PowerBuilder IDE with these arguments:

| Argument | Default |
|---|---|
| `/out:<file>` | `pbunit_results.txt` |
| `/junit:<file>` | `pbunit_results.xml` |
| `/filter:<list>` | all tests; a comma-separated list of `class` or `class.test` names, where a trailing `*` matches a prefix |

When running from the IDE, run the script once first so that `n_pbunit_registry` exists.

## Testing database access

`pbunitmocks.pbl` lets tests check what code does with the database without a test database to maintain.
Add it to the test project's libraries, after `pbunitfunc.pbl`.

PowerBuilder only generates SQL for a connected transaction, so the tests need a connection, but not a real
database: `n_pbunit_mockdb` creates an empty scratch database (a Jet `.mdb` in the temp folder) and connects
to it. Jet is part of 32-bit Windows, so 32-bit test runs need no install; a 64-bit run needs the Microsoft
Access Database Engine.

| Object | What it does |
|---|---|
| `n_pbunit_mockdb` | `of_Connect(transaction)` connects (AutoCommit off) to a scratch database it creates, or to the database in `PBUNIT_MOCKDB_INI`; `of_Execute` runs SQL (create a fixture's tables); `of_Disconnect` rolls back and disconnects. Destroying it deletes the scratch file |
| `n_pbunit_spyds`, `u_pbunit_spydw` | A DataStore and a DataWindow control whose `inv_recorder` (`n_pbunit_dwrecorder`) records every retrieve and every statement, with its values, and skips it (the default) or lets it through (`PASSTHROUGH`) |
| `n_pbunit_spytr` | A transaction object whose `inv_recorder` (`n_pbunit_trrecorder`) records embedded and dynamic SQL, and can stop writes (`BLOCKWRITES`) or everything (`BLOCKALL`) |

What a test can do with them:

- **Check what `Update()` would write.** With the recorder skipping (the default), `Update()` records each
  INSERT, UPDATE and DELETE with its values, sends nothing, returns 1 and resets the row status as a real
  update does. `of_FindStatement("UPDATE", "amount = 99")` finds one; `of_GetStatementCount("DELETE")` counts them.
- **Retrieve canned rows.** `of_SetCannedRows(rows)` (ImportString format): a retrieve skips its SELECT,
  loads these rows instead and returns their count. They are NotModified, like retrieved rows, unless you
  pass `False`.
- **Check that code retrieves, or doesn't.** `of_GetRetrieveCount()`, and the recorded SELECT has the argument values.
- **Watch or stop embedded SQL.** The transaction spy records each statement; a stopped one fails with SQLCode -1.
  Embedded `SELECT ... INTO` can't return made-up values: create the tables it reads with `of_Execute` instead.

```
event setup;call super::setup;inv_db = Create n_pbunit_mockdb
itr = Create transaction
If Not assertEquals("connect: " + inv_db.of_GetError(), 1, inv_db.of_Connect(itr)) Then Return
ids_orders = Create n_pbunit_spyds
ids_orders.DataObject = "d_orders"
ids_orders.SetTransObject(itr)
end event

event teardown;call super::teardown;If IsValid(ids_orders) Then Destroy ids_orders
inv_db.of_Disconnect(itr)
Destroy itr
Destroy inv_db
end event

event test_saves_changed_amount();// Saving a changed amount updates only that order.
ids_orders.inv_recorder.of_SetCannedRows("1~t42~t10~r~n2~t42~t20~r~n")
inv_orders.of_Load(ids_orders, 42)
inv_orders.of_SetAmount(1, 99)
assertEquals("save", 1, inv_orders.of_Save())
assertEquals("statements", 1, ids_orders.inv_recorder.of_GetStatementCount())
assertTrue("update", ids_orders.inv_recorder.of_FindStatement("UPDATE", "amount = 99") > 0)
end event
```

**Spying on your own classes.** Code under test often needs its own DataStore, DataWindow or transaction class
(PFC's `n_ds`, `u_dw` or `n_tr`). Make a test descendant of that class with an `n_pbunit_dwrecorder` (or
`n_pbunit_trrecorder`) and forward the events, as `n_pbunit_spyds` and `n_pbunit_spytr` do:

```
event retrievestart;Return inv_recorder.of_OnRetrieveStart()
event retrieveend;inv_recorder.of_OnRetrieveEnd(This)
event sqlpreview;Return inv_recorder.of_OnSqlPreview(sqltype, sqlsyntax, row)
event updatestart;Return inv_recorder.of_OnUpdateStart()
event dberror;Return inv_recorder.of_OnDbError(sqldbcode, sqlerrtext)
```

(each followed by `end event`; for a transaction, `sqlpreview` passes `sqlfunc, sqlsyntax`). If the class already
scripts one of these events, extend it with `call super::<event>` where its behavior is needed (PFC's `u_dw`
notifies its services in `retrievestart`), but not in `dberror` when the ancestor shows a message box (PFC's
does): a dialog stops the test run. In `sqlpreview`, extend the ancestor and return its answer when it skips
(2) or stops (1) a statement (`If AncestorReturnValue = 1 Or AncestorReturnValue = 2 Then Return
AncestorReturnValue`) before calling the recorder: PFC's `u_dw` skips the statement types an update leaves
out, which the linkage service's two-pass update styles rely on. PFC's `n_cst_dwsrv_linkage_update_tests`
and `u_pfctest_spydw` (in `tests\pfctests.pbl`) are a worked example.

**Using another database.** Set the environment variable `PBUNIT_MOCKDB_INI` to an INI file whose `[MockDB]`
section (or the section named by `PBUNIT_MOCKDB_SECTION`) has `DBMS` and any of `DBParm`, `ServerName`,
`Database`, `LogId`, `LogPass`, `UserId`, `DBPass` and `Lock`, copied from your application's connection
(for example SQL Server, or PostgreSQL through PowerBuilder's ADO.NET interface). Use it when tests run SQL
against real tables and the SQL must be in the production database's dialect. Such a database is shared by
every test and keeps whatever a test commits, so tests must create (or drop and recreate) what they need.

Things to know, all checked by `selftest/selftest.pbl/n_pbunit_mocks_tests.sru`:

- Without a connection, nothing is recorded: the retrieve or update fails with a database error before any
  SQL is generated. And a spy suppresses that error, so **`Update()` then returns 1 although nothing was
  written**; check `of_GetDbErrorCount()`.
- A skipped retrieve without canned rows returns 0 and clears the rows.
- Only the DataWindow's own recorder can skip its statements; a transaction spy sees them but can't stop them.
- The SQL is in the connected database's dialect (Jet's, by default): assert on table, column and value
  fragments, not on exact spacing.
## Using PBUnit with Claude Code

`plugins/pbunit` is a Claude Code plugin with skills for writing tests, running them, and interpreting the
results, and an MCP server whose tools let agents find, check, build and run tests and read their results
without a shell. Install it in Claude Code with:

```
/plugin marketplace add bruce-armstrong/PBUnit2025
/plugin install pbunit@pbunit2025
```

See [plugins/pbunit/README.md](plugins/pbunit/README.md) for what each skill does, and for the MCP server: its
tools, how Claude Code starts it, and how to add it to Claude Desktop, VS Code and other MCP clients.

## Things to know

- A test that opens a message box or modal window stops the run until the script's timeout. Configure the code
  under test to log instead of display, or replace the visual parts with test doubles.
- Test times are CPU time as reported by PowerBuilder's `CPU()`, in milliseconds.
- Windows Smart App Control blocks unsigned executables it has not seen before, which includes each newly built
  test exe. Sign the exe as part of the build, or run the tests on a machine where Smart App Control is off.
- `Invoke-PBUnit.ps1` needs PowerShell 7 (`pwsh`) and PowerBuilder 2025 (PBAutoBuild 25).

## License

PBUnit is licensed under the [Common Public License 1.0](LICENSE), and so is this modified version.
The `pbunit.pbl` and `pbunitfunc.pbl` libraries are PBUnit 3.0's code, unchanged except that `testcase` has been
extended with the assertions above. `pbunitrunner.pbl`, `pbunitmocks.pbl`, `scripts/`, `selftest/` and `plugins/` are new.
It contains no code from PowerUnit.

Modifications © 2026 Bruce Armstrong.
