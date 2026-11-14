//objectcomments Connects a transaction to a database for tests: a scratch Jet .mdb it creates, or the connection in the INI file named by PBUNIT_MOCKDB_INI
forward
global type n_pbunit_mockdb from nonvisualobject
end type
end forward

global type n_pbunit_mockdb from nonvisualobject
end type
global n_pbunit_mockdb n_pbunit_mockdb

type prototypes
FUNCTION boolean SQLConfigDataSourceW (ulong hwndParent, uint fRequest, string lpszDriver, ref blob lpszAttributes) LIBRARY "odbccp32.dll"
FUNCTION ulong GetTempPathW (ulong nBufferLength, ref string lpBuffer) LIBRARY "kernel32.dll"
FUNCTION ulong GetCurrentProcessId () LIBRARY "kernel32.dll"
end prototypes

type variables
Public:
// The Jet driver is part of Windows (32-bit only); the Access Database Engine (ACE) driver
// is a separate install and has 32-bit and 64-bit versions.
constant string JET_DRIVER = "Microsoft Access Driver (*.mdb)"
constant string ACE_DRIVER = "Microsoft Access Driver (*.mdb, *.accdb)"
// The environment variable naming an INI file whose [MockDB] section (or the section named by
// PBUNIT_MOCKDB_SECTION) holds a connection to use instead of a scratch database.
constant string ENV_INI = "PBUNIT_MOCKDB_INI"
constant string ENV_SECTION = "PBUNIT_MOCKDB_SECTION"

Protected:
string	is_file			// the scratch database this object created; deleted in the destructor
string	is_driver
string	is_description
string	is_error
end variables

forward prototypes
public function integer of_connect (transaction atr)
public function integer of_execute (transaction atr, string as_sql)
public function integer of_disconnect (transaction atr)
public function string of_geterror ()
public function string of_getdescription ()
public function boolean of_isscratch ()
public function string of_getfile ()
protected function integer of_createscratch ()
protected function integer of_connectfromini (transaction atr, string as_ini, string as_section)
protected function string of_getenv (string as_name)
end prototypes

public function integer of_connect (transaction atr);//////////////////////////////////////////////////////////////////////////////
//
//	Function:		of_Connect
//
//	Description:	Connects atr, with AutoCommit off, to the database named by
//					PBUNIT_MOCKDB_INI if that is set, and otherwise to a scratch
//					Jet database created in the temp folder (one per object, shared
//					by every transaction it connects). Call of_Disconnect in the
//					test's teardown: it rolls back, so each test starts clean.
//
//	Returns:		1, or -1 (of_GetError says why).
//
//////////////////////////////////////////////////////////////////////////////
string	ls_ini, ls_section

is_error = ""
If IsNull(atr) Or Not IsValid(atr) Then
	is_error = "The transaction object isn't valid."
	Return -1
End If

ls_ini = of_GetEnv(ENV_INI)
If ls_ini <> "" Then
	ls_section = of_GetEnv(ENV_SECTION)
	If ls_section = "" Then ls_section = "MockDB"
	Return of_ConnectFromIni(atr, ls_ini, ls_section)
End If

If is_file = "" Then
	If of_CreateScratch() <> 1 Then Return -1
End If

atr.DBMS = "ODBC"
atr.AutoCommit = False
atr.DBParm = "ConnectString='Driver={" + is_driver + "};Dbq=" + is_file + ";'"
CONNECT USING atr;
If atr.SQLCode <> 0 Then
	is_error = "Could not connect to the scratch database " + is_file + ": " + atr.SQLErrText
	Return -1
End If

is_description = "scratch database " + is_file + " (" + is_driver + ")"
Return 1
end function

public function integer of_execute (transaction atr, string as_sql);// Runs a SQL statement (for example CREATE TABLE or INSERT for the test's fixture).
// Returns 1, or -1 (of_GetError has the database's message).
is_error = ""
EXECUTE IMMEDIATE :as_sql USING atr;
If atr.SQLCode <> 0 Then
	is_error = as_sql + ": " + atr.SQLErrText
	Return -1
End If
Return 1
end function

public function integer of_disconnect (transaction atr);// Rolls back and disconnects atr, if it is connected. Returns 1, or 0 if it wasn't connected.
If IsNull(atr) Or Not IsValid(atr) Then Return 0
If atr.DBHandle() = 0 Then Return 0

ROLLBACK USING atr;
DISCONNECT USING atr;
Return 1
end function

public function string of_geterror ();Return is_error
end function

public function string of_getdescription ();// What of_Connect connected to, for messages.
Return is_description
end function

public function boolean of_isscratch ();// True when the connection is a scratch database this object created.
Return is_file <> ""
end function

public function string of_getfile ();// The scratch database file, or "" when the connection came from PBUNIT_MOCKDB_INI.
Return is_file
end function

protected function integer of_createscratch ();// Creates an empty .mdb in the temp folder with the ODBC setup API, with the Jet driver
// or, failing that (a 64-bit process), the Access Database Engine driver.
string		ls_temp, ls_file, ls_drivers[]
blob			lblb_attr
blob{4}		lblb_end
integer		li_d

ls_temp = Space(300)
If GetTempPathW(300, ls_temp) = 0 Then ls_temp = "C:\Windows\Temp\"
ls_temp = Trim(ls_temp)
If Right(ls_temp, 1) <> "\" Then ls_temp += "\"
ls_file = ls_temp + "pbunit_mockdb_" + String(GetCurrentProcessId()) + "_" + String(Today(), "yyyymmdd") + String(Now(), "hhmmssffffff") + ".mdb"

ls_drivers[1] = JET_DRIVER
ls_drivers[2] = ACE_DRIVER
For li_d = 1 To UpperBound(ls_drivers)
	lblb_attr = Blob('CREATE_DB="' + ls_file + '" General', EncodingUTF16LE!) + lblb_end
	If SQLConfigDataSourceW(0, 1, ls_drivers[li_d], lblb_attr) And FileExists(ls_file) Then
		is_file = ls_file
		is_driver = ls_drivers[li_d]
		Return 1
	End If
Next

is_error = "Could not create a scratch database: neither the Jet driver (part of 32-bit Windows) nor the " + &
	"Access Database Engine driver is available to this process. A 64-bit test exe needs the Microsoft Access " + &
	"Database Engine installed; or set " + ENV_INI + " to an INI file with another connection."
Return -1
end function

protected function integer of_connectfromini (transaction atr, string as_ini, string as_section);// Connects with the settings in [as_section] of as_ini: DBMS, DBParm, ServerName, Database,
// LogId, LogPass, UserId, DBPass, Lock (any that are set).
string	ls_value

If Not FileExists(as_ini) Then
	is_error = ENV_INI + " names " + as_ini + ", which doesn't exist."
	Return -1
End If
If ProfileString(as_ini, as_section, "DBMS", "") = "" Then
	is_error = "No DBMS in [" + as_section + "] of " + as_ini + "."
	Return -1
End If

atr.DBMS = ProfileString(as_ini, as_section, "DBMS", "")
ls_value = ProfileString(as_ini, as_section, "DBParm", "")
If ls_value <> "" Then atr.DBParm = ls_value
ls_value = ProfileString(as_ini, as_section, "ServerName", "")
If ls_value <> "" Then atr.ServerName = ls_value
ls_value = ProfileString(as_ini, as_section, "Database", "")
If ls_value <> "" Then atr.Database = ls_value
ls_value = ProfileString(as_ini, as_section, "LogId", "")
If ls_value <> "" Then atr.LogId = ls_value
ls_value = ProfileString(as_ini, as_section, "LogPass", "")
If ls_value <> "" Then atr.LogPass = ls_value
ls_value = ProfileString(as_ini, as_section, "UserId", "")
If ls_value <> "" Then atr.UserId = ls_value
ls_value = ProfileString(as_ini, as_section, "DBPass", "")
If ls_value <> "" Then atr.DBPass = ls_value
ls_value = ProfileString(as_ini, as_section, "Lock", "")
If ls_value <> "" Then atr.Lock = ls_value
atr.AutoCommit = False

CONNECT USING atr;
If atr.SQLCode <> 0 Then
	is_error = "Could not connect with [" + as_section + "] of " + as_ini + ": " + atr.SQLErrText
	Return -1
End If

is_description = "[" + as_section + "] of " + as_ini + " (" + atr.DBMS + ")"
Return 1
end function

protected function string of_getenv (string as_name);// The value of an environment variable, or "" if it isn't set.
ContextKeyword	lcx_keyword
string			ls_values[]

If GetContextService("Keyword", lcx_keyword) <> 1 Then Return ""
If lcx_keyword.GetContextKeywords(as_name, ls_values) < 1 Then Return ""
If IsNull(ls_values[1]) Then Return ""
Return Trim(ls_values[1])
end function

on n_pbunit_mockdb.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_mockdb.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

event destructor;// The scratch database can only be deleted once every transaction has disconnected.
If is_file <> "" Then
	If FileExists(is_file) Then FileDelete(is_file)
End If
end event
