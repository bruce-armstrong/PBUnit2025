//objectcomments Transaction object whose embedded and dynamic SQL is recorded by inv_recorder, and blocked in its BLOCKWRITES and BLOCKALL modes
forward
global type n_pbunit_spytr from transaction
end type
end forward

global type n_pbunit_spytr from transaction
end type
global n_pbunit_spytr n_pbunit_spytr

type variables
Public:
n_pbunit_trrecorder	inv_recorder
end variables

event constructor;inv_recorder = Create n_pbunit_trrecorder
end event

event destructor;If IsValid(inv_recorder) Then Destroy inv_recorder
end event

event sqlpreview;Return inv_recorder.of_OnSqlPreview(sqlfunc, sqlsyntax)
end event

event dberror;inv_recorder.of_OnDbError(This.SQLDBCode, This.SQLErrText)
end event

on n_pbunit_spytr.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_spytr.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
