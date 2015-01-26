---
title: Virtual Hardware Platform Version
layout: default
design_doc: true
revision: 1
status: proposed
---

Some VMs can only be run on hosts of sufficiently recent versions.

We want a clean way to ensure that xapi only tries to run a guest VM on a host that supports the "virtual hardware platform" required by the VM.

Suggested design:

* In the datamodel, VM has a new integer field "virt_hw_vn" which defaults to zero.
* In the datamodel, Host has a corresponding new integer-list field "virt_hw_vns" which defaults to the empty list.
* When a host boots it populates its own entry from a hardcoded value, currently a list containing a single element which is the number 1. (Alternatively this could come from a config file.)
  * If this new version-handling functionality is introduced in a hotfix, at some point the pool master will have the new functionality while at least one slave does not. An old slave-host that does not yet have software to handle this feature will not populate its DB entry, which will therefore remain as the empty list (maintained in the DB by the master).
* The existing test for whether a VM can run on (or migrate to) a host must include a check that the VM's virtual hardware platform version is zero or is in the host's list of supported versions.
* When a VM is made to start using a feature is available only in a certain virtual hardware platform version, xapi must set it the VM's virt_hw_vn to the minimum of that version-number and its current value.

For the version we could consider some type other than integer, but a strict ordering is needed.
