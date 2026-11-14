//objectcomments Records the SQL a transaction object sends (embedded and dynamic SQL), and can block it; transaction spies forward their SQLPreview and DBError events to it
forward
global type n_pbunit_trrecorder from nonvisualobject
end type
end forward

global type n_pbunit_trrecorder from nonvisualobject
end type
global n_pbunit_trrecorder n_pbunit_trrecorder

type variables
Public:
// Modes
constant integer OBSERVE = 0		// record each statement and send it (the default)
constant integer BLOCKWRITES = 1	// send SELECTs; stop everything else (SQLCode -1)
constant integer BLOCKALL = 2		// stop every statement (SQLCode -1)

Protected:
integer	ii_mode = 0
string	is_types[], is_sql[]
string	is_dberrors[]
end variables

forward prototypes
public function integer of_setmode (integer ai_mode)
public function integer of_getmode ()
public subroutine of_reset ()
public function long of_onsqlpreview (sqlfunction ae_func, string as_sql)
public subroutine of_ondberror (long al_code, string as_text)
public function long of_getstatementcount ()
public function long of_getstatementcount (string as_type)
public function string of_getstatement (long al_index)
public function string of_getstatementtype (long al_index)
public function long of_findstatement (string as_type, string as_contains)
public function long of_getdberrorcount ()
public function string of_getdberror (long al_index)
end prototypes

public function integer of_setmode (integer ai_mode);// OBSERVE (the default), BLOCKWRITES or BLOCKALL. Returns 1, or -1 for another value.
// Blocking stops embedded and dynamic SQL only: a DataWindow's statements still run (stop
// those with the DataWindow's recorder in SKIP mode).
If ai_mode < OBSERVE Or ai_mode > BLOCKALL Then Return -1
ii_mode = ai_mode
Return 1
end function

public function integer of_getmode ();Return ii_mode
end function

public subroutine of_reset ();string	ls_none[]

is_types = ls_none
is_sql = ls_none
is_dberrors = ls_none
end subroutine

public function long of_onsqlpreview (sqlfunction ae_func, string as_sql);// From the transaction's SQLPreview event. It also sees a DataWindow's statements when the
// DataWindow's own sqlpreview lets them through. Returns 1 (stop) when the mode blocks it.
long		ll_i
string	ls_type

Choose Case ae_func
	Case SQLDBSelect!
		ls_type = "SELECT"
	Case SQLDBInsert!
		ls_type = "INSERT"
	Case SQLDBUpdate!
		ls_type = "UPDATE"
	Case SQLDBDelete!
		ls_type = "DELETE"
	Case SQLDBProcedure!, SQLDBRPC!
		ls_type = "PROCEDURE"
	Case Else
		ls_type = "OTHER"
End Choose

ll_i = UpperBound(is_sql) + 1
is_types[ll_i] = ls_type
is_sql[ll_i] = Trim(as_sql)

If ii_mode = BLOCKALL Then Return 1
If ii_mode = BLOCKWRITES And ls_type <> "SELECT" Then Return 1
Return 0
end function

public subroutine of_ondberror (long al_code, string as_text);// From the transaction's DBError event.
is_dberrors[UpperBound(is_dberrors) + 1] = String(al_code) + ": " + as_text
end subroutine

public function long of_getstatementcount ();Return UpperBound(is_sql)
end function

public function long of_getstatementcount (string as_type);// Statements of one type: "SELECT", "INSERT", "UPDATE", "DELETE", "PROCEDURE" or "OTHER".
long	ll_i, ll_count

For ll_i = 1 To UpperBound(is_types)
	If Upper(is_types[ll_i]) = Upper(as_type) Then ll_count++
Next
Return ll_count
end function

public function string of_getstatement (long al_index);If al_index < 1 Or al_index > UpperBound(is_sql) Then Return ""
Return is_sql[al_index]
end function

public function string of_getstatementtype (long al_index);If al_index < 1 Or al_index > UpperBound(is_types) Then Return ""
Return is_types[al_index]
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

public function long of_getdberrorcount ();Return UpperBound(is_dberrors)
end function

public function string of_getdberror (long al_index);If al_index < 1 Or al_index > UpperBound(is_dberrors) Then Return ""
Return is_dberrors[al_index]
end function

on n_pbunit_trrecorder.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_trrecorder.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
