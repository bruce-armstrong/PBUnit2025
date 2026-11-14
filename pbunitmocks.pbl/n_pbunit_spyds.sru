//objectcomments DataStore whose retrieves and updates are recorded by inv_recorder, and skipped unless it is in PASSTHROUGH mode
forward
global type n_pbunit_spyds from datastore
end type
end forward

global type n_pbunit_spyds from datastore
end type
global n_pbunit_spyds n_pbunit_spyds

type variables
Public:
n_pbunit_dwrecorder	inv_recorder
end variables

event constructor;inv_recorder = Create n_pbunit_dwrecorder
end event

event destructor;If IsValid(inv_recorder) Then Destroy inv_recorder
end event
event retrievestart;Return inv_recorder.of_OnRetrieveStart()
end event

event retrieveend;inv_recorder.of_OnRetrieveEnd(This)
end event

event sqlpreview;Return inv_recorder.of_OnSqlPreview(sqltype, sqlsyntax, row)
end event

event updatestart;Return inv_recorder.of_OnUpdateStart()
end event

event dberror;Return inv_recorder.of_OnDbError(sqldbcode, sqlerrtext)
end event
on n_pbunit_spyds.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_spyds.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
