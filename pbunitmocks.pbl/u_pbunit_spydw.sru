//objectcomments DataWindow control whose retrieves and updates are recorded by inv_recorder, and skipped unless it is in PASSTHROUGH mode; open it on a window with OpenUserObject
forward
global type u_pbunit_spydw from datawindow
end type
end forward

global type u_pbunit_spydw from datawindow
integer width = 1000
integer height = 400
end type
global u_pbunit_spydw u_pbunit_spydw

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
on u_pbunit_spydw.create
end on

on u_pbunit_spydw.destroy
end on
