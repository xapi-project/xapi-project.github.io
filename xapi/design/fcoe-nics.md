---
title: FCoE capable NICs
layout: default
design_doc: true
revision: 3
status: proposed
design_review: 120
---

It has been possible to identify the NICs of a Host which can support FCoE.
This property can be listed in PIF object under capabilities field.

Introduction
------------

* FCoE supported on a NIC is a hardware property. With the help of dcbtool, we can identify which NIC support FCoE.
* The new field capabilities will be `Set(String)` in PIF object. For FCoE capable NIC will have string "fcoe" in PIF capabilities field.
* `capabilities` field will be ReadOnly, This field cannot be modified by user.

PIF Object
-------

New field:
* Field `PIF.capabilities` will be type `Set(string)`.
* Default value in PIF capabilities will have empty string "".

Xapi Changes
------

New function:
* String `string get_fcoe_capability (string)`
* Argument: device_name for the PIF.
* This function calls method `capable` exposed by `fcoe_driver.py` as part of dom0.
* It returns string "fcoe" or "" depending on `capable` method output. 

Set and Update of capabilities field:
* Field capabilities "fcoe" can be set during `introduce_internal` on PIF scan.
* Field capabilities "fcoe" can be updated during `refresh_all` on xapi startup sequence.
* The above field will be set everytime when xapi-restart.

Defaults, Installation and Upgrade
------------------------
* Any newly introduced PIF will have its capabilities field set to empty string "" until `fcoe_driver` method `capable` states FCoE is supported on the NIC.
* It includes PIFs obtained after a fresh install of Xenserver, as well as PIFs created using `PIF.introduce` then `PIF.scan`.
* During an upgrade Xapi Restart will call `refresh_all` which then populate the capabilities field set to empty string "".


Command Line Interface
----------------------

* The `PIF.capabilities` field is exposed through `xe pif-list` and `xe pif-param-list` as usual.
