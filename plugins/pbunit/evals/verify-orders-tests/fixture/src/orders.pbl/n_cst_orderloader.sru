//objectcomments Loads a customer's orders (d_orders) into a DataStore
forward
global type n_cst_orderloader from nonvisualobject
end type
end forward

global type n_cst_orderloader from nonvisualobject
end type
global n_cst_orderloader n_cst_orderloader

type variables
Protected:
long	il_customer	// the customer last loaded; 0 when there is none
end variables

forward prototypes
public function long of_load (datastore ads_orders, long al_customer)
public function long of_reload (datastore ads_orders)
public function long of_getcustomer ()
end prototypes

public function long of_load (datastore ads_orders, long al_customer);// Retrieves the customer's orders into ads_orders, which must use d_orders and a
// transaction.  Returns the number of rows, or -1 (without retrieving) when
// ads_orders isn't valid or the customer is null, zero or negative; a failed
// retrieve also returns -1.
If Not IsValid(ads_orders) Then Return -1
If IsNull(al_customer) Or al_customer <= 0 Then Return -1

il_customer = al_customer
Return ads_orders.Retrieve(al_customer)
end function

public function long of_reload (datastore ads_orders);// Retrieves the last customer's orders again.  Returns -1 (without retrieving)
// when no customer has been loaded or ads_orders isn't valid.
If Not IsValid(ads_orders) Then Return -1
If il_customer <= 0 Then Return -1

Return ads_orders.Retrieve(il_customer)
end function

public function long of_getcustomer ();Return il_customer
end function

on n_cst_orderloader.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_cst_orderloader.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
