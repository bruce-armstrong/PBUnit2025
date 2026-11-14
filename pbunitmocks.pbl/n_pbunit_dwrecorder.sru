//objectcomments Records what a DataWindow or DataStore sends to the database, and skips it or supplies canned rows; spies forward their database events to it
forward
global type n_pbunit_dwrecorder from nonvisualobject
end type
end forward

global type n_pbunit_dwrecorder from nonvisualobject
end type
global n_pbunit_dwrecorder n_pbunit_dwrecorder

type variables
Public:
// Modes
constant integer SKIP = 1			// record each statement and don't send it (the default)
constant integer PASSTHROUGH = 0	// record each statement and send it

Protected:
integer	ii_mode = 1
string	is_canned
boolean	ib_cannedasretrieved = True
long		il_retrieves, il_updates
string	is_types[], is_sql[]
long		il_rows[]
string	is_dberrors[]
end variables

forward prototypes
public function integer of_setmode (integer ai_mode)
public function integer of_getmode ()
public subroutine of_setcannedrows (string as_rows)
public subroutine of_setcannedrows (string as_rows, boolean ab_asretrieved)
public subroutine of_reset ()
public function long of_onretrievestart ()
public function long of_onsqlpreview (sqlpreviewtype ae_type, string as_sql, long al_row)
public subroutine of_onretrieveend (powerobject apo_target)
public function long of_onupdatestart ()
public function long of_ondberror (long al_code, string as_text)
public function long of_getstatementcount ()
public function long of_getstatementcount (string as_type)
public function string of_getstatement (long al_index)
public function string of_getstatementtype (long al_index)
public function long of_getstatementrow (long al_index)
public function long of_findstatement (string as_type, string as_contains)
public function long of_getretrievecount ()
public function long of_getupdatecount ()
public function long of_getdberrorcount ()
public function string of_getdberror (long al_index)
end prototypes

public function integer of_setmode (integer ai_mode);// SKIP (the default) or PASSTHROUGH. Returns 1, or -1 for another value.
If ai_mode <> SKIP And ai_mode <> PASSTHROUGH Then Return -1
ii_mode = ai_mode
Return 1
end function

public function integer of_getmode ();Return ii_mode
end function

public subroutine of_setcannedrows (string as_rows);of_SetCannedRows(as_rows, True)
end subroutine

public subroutine of_setcannedrows (string as_rows, boolean ab_asretrieved);// Rows a skipped retrieve returns: text in ImportString's format (tab-separated columns,
// one row per line, in the DataWindow's column order). Retrieve then returns their count.
// ab_asretrieved True (the default): the rows are NotModified, as retrieved rows are;
// False: they are left NewModified, as ImportString leaves them. "" removes canned rows.
is_canned = as_rows
ib_cannedasretrieved = ab_asretrieved
end subroutine

public subroutine of_reset ();// Forgets what was recorded (not the mode or canned rows).
string	ls_none[]
long		ll_none[]

il_retrieves = 0
il_updates = 0
is_types = ls_none
is_sql = ls_none
il_rows = ll_none
is_dberrors = ls_none
end subroutine

public function long of_onretrievestart ();// From the spy's retrievestart event.
il_retrieves++
Return 0
end function

public function long of_onsqlpreview (sqlpreviewtype ae_type, string as_sql, long al_row);// From the spy's sqlpreview event: records the statement; returns 2 (skip it) in SKIP mode.
long		ll_i
string	ls_type

Choose Case ae_type
	Case PreviewSelect!
		ls_type = "SELECT"
	Case PreviewInsert!
		ls_type = "INSERT"
	Case PreviewUpdate!
		ls_type = "UPDATE"
	Case PreviewDelete!
		ls_type = "DELETE"
	Case Else
		ls_type = "OTHER"
End Choose

ll_i = UpperBound(is_sql) + 1
is_types[ll_i] = ls_type
is_sql[ll_i] = Trim(as_sql)
il_rows[ll_i] = al_row

If ii_mode = SKIP Then Return 2
Return 0
end function

public subroutine of_onretrieveend (powerobject apo_target);// From the spy's retrieveend event: loads the canned rows into a skipped retrieve.
If ii_mode <> SKIP Or is_canned = "" Then Return
apo_target.Dynamic ImportString(is_canned)
If ib_cannedasretrieved Then apo_target.Dynamic ResetUpdate()
end subroutine

public function long of_onupdatestart ();// From the spy's updatestart event.
il_updates++
Return 0
end function

public function long of_ondberror (long al_code, string as_text);// From the spy's dberror event: records the error and suppresses PowerBuilder's message box.
// Note: with the error suppressed, Update() can return 1 although nothing was written;
// check of_GetDbErrorCount().
is_dberrors[UpperBound(is_dberrors) + 1] = String(al_code) + ": " + as_text
Return 1
end function

public function long of_getstatementcount ();Return UpperBound(is_sql)
end function

public function long of_getstatementcount (string as_type);// Statements of one type: "SELECT", "INSERT", "UPDATE" or "DELETE".
long	ll_i, ll_count

For ll_i = 1 To UpperBound(is_types)
	If Upper(is_types[ll_i]) = Upper(as_type) Then ll_count++
Next
Return ll_count
end function

public function string of_getstatement (long al_index);// The SQL of statement al_index (1 is the first), with the values PowerBuilder put in it.
If al_index < 1 Or al_index > UpperBound(is_sql) Then Return ""
Return is_sql[al_index]
end function

public function string of_getstatementtype (long al_index);If al_index < 1 Or al_index > UpperBound(is_types) Then Return ""
Return is_types[al_index]
end function

public function long of_getstatementrow (long al_index);// The row the statement was for (0 for a SELECT); for a DELETE, the row in the delete buffer.
If al_index < 1 Or al_index > UpperBound(il_rows) Then Return 0
Return il_rows[al_index]
end function

public function long of_findstatement (string as_type, string as_contains);// The first statement of type as_type ("" for any) whose SQL contains as_contains
// (ignoring case), or 0.
long	ll_i

For ll_i = 1 To UpperBound(is_sql)
	If as_type <> "" And Upper(is_types[ll_i]) <> Upper(as_type) Then Continue
	If Pos(Upper(is_sql[ll_i]), Upper(as_contains)) > 0 Then Return ll_i
Next
Return 0
end function

public function long of_getretrievecount ();// Retrieves started, whether or not they reached the database.
Return il_retrieves
end function

public function long of_getupdatecount ();// Updates started.
Return il_updates
end function

public function long of_getdberrorcount ();Return UpperBound(is_dberrors)
end function

public function string of_getdberror (long al_index);If al_index < 1 Or al_index > UpperBound(is_dberrors) Then Return ""
Return is_dberrors[al_index]
end function

on n_pbunit_dwrecorder.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_dwrecorder.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
