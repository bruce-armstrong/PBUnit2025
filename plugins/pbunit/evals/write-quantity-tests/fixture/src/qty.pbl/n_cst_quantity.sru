//objectcomments Keeps a quantity within a configurable range
forward
global type n_cst_quantity from nonvisualobject
end type
end forward

global type n_cst_quantity from nonvisualobject
end type
global n_cst_quantity n_cst_quantity

type variables
Protected:
long	il_min = 0
long	il_max = 100
end variables

forward prototypes
public function integer of_setrange (long al_min, long al_max)
public function long of_clamp (long al_value)
public function long of_getmin ()
public function long of_getmax ()
protected subroutine of_warn (string as_text)
end prototypes

public function integer of_setrange (long al_min, long al_max);// Sets the allowed range.  Returns 1, or -1 (after warning the user) for a
// missing or inverted range, which leaves the range unchanged.
If IsNull(al_min) Or IsNull(al_max) Then
	of_Warn("The range needs a minimum and a maximum.")
	Return -1
End If
If al_min > al_max Then
	of_Warn("The minimum (" + String(al_min) + ") is greater than the maximum (" + String(al_max) + ").")
	Return -1
End If

il_min = al_min
il_max = al_max
Return 1
end function

public function long of_clamp (long al_value);// The value, moved into the range if it is outside it.  Null stays null.
If IsNull(al_value) Then Return al_value
If al_value < il_min Then Return il_min
If al_value > il_max Then Return il_max
Return al_value
end function

public function long of_getmin ();Return il_min
end function

public function long of_getmax ();Return il_max
end function

protected subroutine of_warn (string as_text);MessageBox("Quantity", as_text, Exclamation!)
end subroutine

on n_cst_quantity.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_cst_quantity.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
