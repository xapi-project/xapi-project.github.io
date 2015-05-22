---
title: FCoE capable NICs
layout: default
design_doc: true
revision: 1
status: confirmed
---

It has been possible to identify the NICs of a Host which can support FCoE.
This property can be listed in PIF object under PIF_metrics.

Introduction
------------

* FCoE supported on a NIC is a hardware property. With the help of dcbtool, we can identify which NIC support FCoE.
* The new field `fcoe-supported` added to PIF_metrics will have a boolean value.
* `True` will state NIC supports FCoE. `False` will state NIC does not supports FCoE.
* `fcoe-supported` field will be ReadOnly, This field cannot be modified by user.

PIF_metrics
-------

New field:
* Field `PIF_metrics.fcoe_supported` of type `bool`.
* Default value will be false

Xapi Changes
------

* Set the field `fcoe_supported` to `true` or `false` depending on output of xcp-networkd call `is_fcoe_supported`.
* Field `fcoe_supported` can be set during `bring_pif_up` and `set_pif_metrics` call.
* Field `fcoe_supported` will be set everytime when xapi-restart.

XCP-Networkd Changes
------

New function:
* Boolean `bool is_fcoe_supported (string)`
  Argument: the device_name for the PIF.
* This function returns `true` or false depending on dcbtool output for the device provided.

Defaults, Installation and Upgrade
------------------------
* Any newly introduced PIF will have its `fcoe_supported` field as false until xcp-networkd call `is_fcoe_supported` sattes FCoE is supported on the NIC.
* It includes PIFs obtained after a fresh install of Xenserver, as well as PIFs created using `PIF.introduce` or `PIF.scan`.
* During an upgrade Xapi Restart will call `bring_pif_up` which then populate the `fcoe_supported` field.


Command Line Interface
----------------------

* The `PIF_metrics.fcoe_supported` field is exposed through `xe pif-list` and `xe pif-param-list` as usual.
