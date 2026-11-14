//objectcomments Hidden window that hosts visual controls created by the self-tests
forward
global type w_pbunit_host from window
end type
end forward

global type w_pbunit_host from window
integer width = 2400
integer height = 1400
boolean visible = false
boolean titlebar = true
string title = "PBUnit self-test host"
boolean controlmenu = true
long backcolor = 67108864
end type
global w_pbunit_host w_pbunit_host

on w_pbunit_host.create
end on

on w_pbunit_host.destroy
end on
