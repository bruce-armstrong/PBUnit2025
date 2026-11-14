//objectcomments Self-tests for pbunitmocks.pbl: the PowerBuilder behavior it relies on, measured with a scratch Jet database (32-bit)
forward
global type n_pbunit_mocks_tests from testcase
end type
end forward

global type n_pbunit_mocks_tests from testcase
event test_mockdb_creates_and_deletes_scratch ( )
event test_skipped_retrieve_is_recorded ( )
event test_canned_rows_as_retrieved ( )
event test_canned_rows_as_new ( )
event test_skipped_update_records_statements ( )
event test_passthrough_writes_and_rollback_restores ( )
event test_without_connection_nothing_is_recorded ( )
event test_transaction_observes_embedded_sql ( )
event test_transaction_blocks_writes ( )
event test_transaction_block_ignores_datawindow ( )
event test_spy_datawindow_control ( )
end type
global n_pbunit_mocks_tests n_pbunit_mocks_tests

type variables
Protected:
n_pbunit_mockdb	inv_db
transaction			itr
n_pbunit_spyds		ids
end variables

forward prototypes
protected subroutine of_change (datastore ads)
protected function boolean of_createtable (transaction atr)
end prototypes

event setup;call super::setup;inv_db = Create n_pbunit_mockdb
itr = Create transaction
If Not assertEquals("connect: " + inv_db.of_GetError(), 1, inv_db.of_Connect(itr)) Then Return
ids = Create n_pbunit_spyds
ids.DataObject = "d_pbunit_mock_orders"
ids.SetTransObject(itr)
end event

event teardown;call super::teardown;If IsValid(ids) Then Destroy ids
If IsValid(inv_db) Then inv_db.of_Disconnect(itr)
If IsValid(itr) Then Destroy itr
If IsValid(inv_db) Then Destroy inv_db
end event

protected subroutine of_change (datastore ads);// Two rows as if retrieved; then the first updated, the second deleted, and order 4 added.
long	ll_row

For ll_row = 1 To 2
	ads.InsertRow(0)
	ads.SetItem(ll_row, "order_id", ll_row)
	ads.SetItem(ll_row, "customer_id", 42)
	ads.SetItem(ll_row, "amount", 10)
Next
ads.ResetUpdate()
ads.SetItem(1, "amount", 99)
ads.DeleteRow(2)
ll_row = ads.InsertRow(0)
ads.SetItem(ll_row, "order_id", 4)
ads.SetItem(ll_row, "customer_id", 42)
ads.SetItem(ll_row, "amount", 5)
end subroutine

protected function boolean of_createtable (transaction atr);// The orders table, with rows 1 and 2 for customer 42 and row 3 for customer 7.
// It is dropped first: a scratch database is new for each test, but a database named by
// PBUNIT_MOCKDB_INI keeps a table that an earlier test committed.
string	ls_sql[]
integer	li_i, li_rc

inv_db.of_Execute(atr, "DROP TABLE orders")
ls_sql[1] = "CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER, amount CURRENCY)"
ls_sql[2] = "INSERT INTO orders VALUES (1, 42, 10)"
ls_sql[3] = "INSERT INTO orders VALUES (2, 42, 20)"
ls_sql[4] = "INSERT INTO orders VALUES (3, 7, 30)"
For li_i = 1 To UpperBound(ls_sql)
	li_rc = inv_db.of_Execute(atr, ls_sql[li_i])
	If Not assertEquals(inv_db.of_GetError(), 1, li_rc) Then Return False
Next
Return True
end function

event test_mockdb_creates_and_deletes_scratch();// The scratch database exists while connected and is deleted when the object is destroyed.
n_pbunit_mockdb	lnv_db
transaction			ltr
string				ls_file

lnv_db = Create n_pbunit_mockdb
ltr = Create transaction
If Not assertEquals("connect: " + lnv_db.of_GetError(), 1, lnv_db.of_Connect(ltr)) Then Return
If Not lnv_db.of_IsScratch() Then
	// PBUNIT_MOCKDB_INI points at another database: there is no scratch file to check
	lnv_db.of_Disconnect(ltr)
	Destroy ltr
	Destroy lnv_db
	Return
End If
ls_file = lnv_db.of_GetFile()
assertTrue("file exists: " + ls_file, FileExists(ls_file))
assertTrue("AutoCommit off", Not ltr.AutoCommit)
assertEquals("disconnect", 1, lnv_db.of_Disconnect(ltr))
assertEquals("disconnect again", 0, lnv_db.of_Disconnect(ltr))
Destroy ltr
Destroy lnv_db
assertFalse("file deleted", FileExists(ls_file))
end event

event test_skipped_retrieve_is_recorded();// SKIP mode: the SELECT is recorded with its argument values, not sent; Retrieve returns 0
// and clears the rows. No table is needed.
ids.InsertRow(0)
assertEquals("retrieve", 0, ids.Retrieve(42))
assertRowCount(ids, 0)
assertEquals("retrieves", 1, ids.inv_recorder.of_GetRetrieveCount())
assertEquals("statements", 1, ids.inv_recorder.of_GetStatementCount())
assertEquals("type", "SELECT", ids.inv_recorder.of_GetStatementType(1))
assertTrue("argument value: " + ids.inv_recorder.of_GetStatement(1), ids.inv_recorder.of_FindStatement("SELECT", "customer_id = 42") = 1)
assertEquals("db errors", 0, ids.inv_recorder.of_GetDbErrorCount())
end event

event test_canned_rows_as_retrieved();// Canned rows: Retrieve returns their count, and they are NotModified like retrieved rows.
ids.inv_recorder.of_SetCannedRows("7~t42~t70.5~r~n8~t42~t80~r~n")
assertEquals("retrieve", 2, ids.Retrieve(42))
assertRowCount(ids, 2)
assertEquals("order", 8, ids.GetItemNumber(2, "order_id"))
assertTrue("not modified", ids.GetItemStatus(1, 0, Primary!) = NotModified!)
assertEquals("modified count", 0, ids.ModifiedCount())
end event

event test_canned_rows_as_new();// Canned rows left as ImportString leaves them: NewModified.
ids.inv_recorder.of_SetCannedRows("7~t42~t70.5~r~n", False)
assertEquals("retrieve", 1, ids.Retrieve(42))
assertTrue("new modified", ids.GetItemStatus(1, 0, Primary!) = NewModified!)
end event

event test_skipped_update_records_statements();// SKIP mode: Update records the DELETE, UPDATE and INSERT with their values, sends nothing,
// returns 1 and resets the row status as a real update does. No table is needed.
of_Change(ids)
assertEquals("update", 1, ids.Update())
assertEquals("statements", 3, ids.inv_recorder.of_GetStatementCount())
assertEquals("deletes", 1, ids.inv_recorder.of_GetStatementCount("DELETE"))
assertTrue("delete: " + ids.inv_recorder.of_GetStatement(1), ids.inv_recorder.of_FindStatement("DELETE", "order_id = 2") > 0)
assertTrue("update", ids.inv_recorder.of_FindStatement("UPDATE", "amount = 99") > 0)
assertTrue("insert", ids.inv_recorder.of_FindStatement("INSERT", "4, 42, 5") > 0)
assertEquals("updates", 1, ids.inv_recorder.of_GetUpdateCount())
assertEquals("modified after", 0, ids.ModifiedCount())
assertEquals("deleted after", 0, ids.DeletedCount())
assertEquals("db errors", 0, ids.inv_recorder.of_GetDbErrorCount())
end event

event test_passthrough_writes_and_rollback_restores();// PASSTHROUGH mode writes to the scratch database; of_Disconnect rolls the rows back.
long	ll_count

If Not of_CreateTable(itr) Then Return
COMMIT USING itr;
ids.inv_recorder.of_SetMode(ids.inv_recorder.PASSTHROUGH)
assertEquals("retrieve", 2, ids.Retrieve(42))
ids.SetItem(1, "amount", 99)
assertEquals("update", 1, ids.Update())
SELECT count(*) INTO :ll_count FROM orders WHERE amount = 99 USING itr;
assertEquals("written", 1, ll_count)
ROLLBACK USING itr;
SELECT count(*) INTO :ll_count FROM orders WHERE amount = 99 USING itr;
assertEquals("rolled back", 0, ll_count)
end event

event test_without_connection_nothing_is_recorded();// Without a connection PowerBuilder stops before generating SQL: nothing is recorded, a
// database error is, and Update returns 1 (the error is suppressed) with the rows unchanged.
n_pbunit_spyds	lds

lds = Create n_pbunit_spyds
lds.DataObject = "d_pbunit_mock_orders"
assertEquals("retrieve", -1, lds.Retrieve(42))
of_Change(lds)
assertEquals("update", 1, lds.Update())
assertEquals("statements", 0, lds.inv_recorder.of_GetStatementCount())
assertEquals("db errors", 2, lds.inv_recorder.of_GetDbErrorCount())
assertEquals("still modified", 2, lds.ModifiedCount())
Destroy lds
end event

event test_transaction_observes_embedded_sql();// A transaction spy records embedded SQL, with its values, and sends it (OBSERVE).
n_pbunit_spytr	ltr
long				ll_count

ltr = Create n_pbunit_spytr
If Not assertEquals("connect: " + inv_db.of_GetError(), 1, inv_db.of_Connect(ltr)) Then Return
If of_CreateTable(ltr) Then
	SELECT count(*) INTO :ll_count FROM orders WHERE customer_id = 42 USING ltr;
	assertEquals("count", 2, ll_count)
	assertTrue("select recorded", ltr.inv_recorder.of_FindStatement("SELECT", "customer_id =42") > 0)
End If
inv_db.of_Disconnect(ltr)
Destroy ltr
end event

event test_transaction_blocks_writes();// BLOCKWRITES: an embedded UPDATE is stopped (SQLCode -1) and recorded; a SELECT still runs.
n_pbunit_spytr	ltr
long				ll_count

ltr = Create n_pbunit_spytr
If Not assertEquals("connect: " + inv_db.of_GetError(), 1, inv_db.of_Connect(ltr)) Then Return
If of_CreateTable(ltr) Then
	ltr.inv_recorder.of_SetMode(ltr.inv_recorder.BLOCKWRITES)
	UPDATE orders SET amount = 0 WHERE customer_id = 42 USING ltr;
	assertEquals("update stopped", -1, ltr.SQLCode)
	assertTrue("update recorded", ltr.inv_recorder.of_FindStatement("UPDATE", "amount =0") > 0)
	SELECT count(*) INTO :ll_count FROM orders WHERE amount = 0 USING ltr;
	assertEquals("select runs", 0, ltr.SQLCode)
	assertEquals("nothing changed", 0, ll_count)
End If
inv_db.of_Disconnect(ltr)
Destroy ltr
end event

event test_transaction_block_ignores_datawindow();// The transaction's SQLPreview can't stop a DataWindow's statements: with the DataStore in
// PASSTHROUGH, the update runs although the transaction spy is in BLOCKALL.
n_pbunit_spytr	ltr
long				ll_count

ltr = Create n_pbunit_spytr
If Not assertEquals("connect: " + inv_db.of_GetError(), 1, inv_db.of_Connect(ltr)) Then Return
If of_CreateTable(ltr) Then
	ids.SetTransObject(ltr)
	ids.inv_recorder.of_SetMode(ids.inv_recorder.PASSTHROUGH)
	ids.Retrieve(42)
	ids.SetItem(1, "amount", 99)
	ltr.inv_recorder.of_SetMode(ltr.inv_recorder.BLOCKALL)
	assertEquals("update", 1, ids.Update())
	assertTrue("transaction saw it", ltr.inv_recorder.of_FindStatement("UPDATE", "amount = 99") > 0)
	ltr.inv_recorder.of_SetMode(ltr.inv_recorder.OBSERVE)
	SELECT count(*) INTO :ll_count FROM orders WHERE amount = 99 USING ltr;
	assertEquals("written anyway", 1, ll_count)
End If
ids.SetTransObject(itr)
inv_db.of_Disconnect(ltr)
Destroy ltr
end event

event test_spy_datawindow_control();// The DataWindow control spy behaves like the DataStore spy.
w_pbunit_host		lw_host
u_pbunit_spydw		ldw
long					ll_row

Open(lw_host)
lw_host.OpenUserObject(ldw)
ldw.DataObject = "d_pbunit_mock_orders"
ldw.SetTransObject(itr)
For ll_row = 1 To 2
	ldw.InsertRow(0)
	ldw.SetItem(ll_row, "order_id", ll_row)
	ldw.SetItem(ll_row, "customer_id", 42)
	ldw.SetItem(ll_row, "amount", 10)
Next
ldw.ResetUpdate()
ldw.SetItem(1, "amount", 99)
assertEquals("update", 1, ldw.Update())
assertEquals("statements", 1, ldw.inv_recorder.of_GetStatementCount("UPDATE"))
ldw.inv_recorder.of_SetCannedRows("5~t9~t1~r~n")
assertEquals("canned retrieve", 1, ldw.Retrieve(9))
Close(lw_host)
end event

on n_pbunit_mocks_tests.create
call super::create
end on

on n_pbunit_mocks_tests.destroy
call super::destroy
end on
