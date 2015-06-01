---
title: FCoE capable NICs
layout: default
design_doc: true
revision: 2
status: proposed
design_review: 120
---

It has been possible to identify the NICs of a Host which can support FCoE.
This property can be listed in PIF object under capabilities field with key `FCoE`.

Introduction
------------

* FCoE supported on a NIC is a hardware property. With the help of dcbtool, we can identify which NIC support FCoE.
* The new field capabilites will be `(string -> string) map` in PIF object. For FCoE capability in PIF capabilties will have field set to `"FCoE" -> "Unsupported"`.
* `Supported` string will state NIC supports FCoE. `Unsupported` string will state NIC does not supports FCoE.
* Capabilties `(key, value)` field will be ReadOnly, This field cannot be modified by user.

PIF Object
-------

New field:
* Field `PIF.capabilties` will be type `(string -> string) map`.
* Default value of PIF capabilties will have field set to `"FCoE" -> "Unsupported"`.

Xapi Changes
------

* Set the field capabilities `FCoE` key to `Unsupported` or `Supported` depending on output of xcp-networkd call `is_fcoe_supported`.
* Field capabilities `FCoE` can be set during `introduce_internal` when the PIF is created.
* Field capabilties `FCoE` can be updated during `refresh_all` during PIF scan.
* The above field will be set everytime when xapi-restart.

XCP-Networkd Changes
------

New function:
* Boolean `bool is_fcoe_supported (string)`
  Argument: the device_name for the PIF.
* This function returns `true` or `false` depending on dcbtool output for the device provided.

Defaults, Installation and Upgrade
------------------------
* Any newly introduced PIF will have its capabilties field set to `"FCoE" -> "Unsupported"` until xcp-networkd call `is_fcoe_supported` states FCoE is supported on the NIC.
* It includes PIFs obtained after a fresh install of Xenserver, as well as PIFs created using `PIF.introduce` then `PIF.scan`.
* During an upgrade Xapi Restart will call `refresh_all` which then populate the capabilties field set to `"FCoE"` -> `"Unsupported"`


Command Line Interface
----------------------

* The `PIF_metrics.fcoe_supported` field is exposed through `xe pif-list` and `xe pif-param-list` as usual.

----------------------------------------------------------------------------------------------------------------------------

Configure FCoE on Xapi Startup
--------------------

Introduction
--------------------

We need to setup certain configuration on NICs of a Host for enabling FCoE traffic.

Xcp-Networkd
-------------------

New Function: 
* unit start_fcoe_service (string)
Argument: the device_name for the PIF. 
* This function will setup fcoe service on intel and broadcom NICs. Only if "network mode = bridge". [We are not clear for OVS] 

Steps:
1) run "ebtables -t broute -A BROUTING -p 0x8914 -j DROP"
2) service start lldp
3) If NIC is FCoE capable and not blacklisted [checked via `is_fcoe_supported` and `is_fcoe_dev_blacklisted`]:
	A) Then: If broadcom NICs: Then "make lldp adminStatus=disabled using lldptool"
	B) cp /etc/fcoe/cfg-ethx /etc/fcoe/cfg-eth<?> ethname
	C) service fcoe start

Pending Work
------------------
* Where to call this function `start_fcoe_service`

