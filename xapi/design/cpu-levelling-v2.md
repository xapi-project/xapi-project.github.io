---
title: CPU feature levelling 2.0
layout: default
design_doc: true
status: proposed
revision: 2
revision_history:
- revision_number: 1
  description: Initial version
- revision_number: 2
  description: Add details about VM migration and import
---

Executive Summary
=================

The old XS 5.6-style Heterogeneous Pool feature that is based around hardware-level CPUID masking will be replaced by a safer and more flexible software-based levelling mechanism.

History
=======

- Original XS 5.6 design: http://xapi-project.github.io/xapi/design/heterogeneous-pools.html
- Changes made in XS 5.6 FP1 for the DR feature (added CPUID checks upon migration)
- XS 6.1: migration checks extended for cross-pool scenario

High-level Interfaces and Behaviour
===================================

XenAPI Changes
------

### Fields

* `host.cpu_info` is a field of type `(string -> string) map` that contains information about the CPUs in a host. It contains the following keys: `cpu_count`, `socket_count`, `vendor`, `speed`, `modelname`, `family`, `model`, `stepping`, `flags`, `features`, `features_after_reboot`, `physical_features` and `maskable`.
	* The following keys are specific to hardware-based CPU masking and will be removed: `features_after_reboot`, `physical_features` and `maskable`.
	* The `features` key will continue to hold the current CPU features that the host is able to use. In practise, these features will be available to Xen itself and dom0; guests may only see a subset. The current format is a string of four 32-bit words represented as four groups of 8 hexadecimal digits, separated by dashes. This will change to an arbitrary number of 32-bit words. Each bit at a particular position (starting from the left) still refers to a distinct CPU feature (`1`: feature is present; `0`: feature is absent), and feature strings may be compared between hosts.
	* The new key `features_pv` will be added, representing the subset of `features` that the host is able to offer to a PV guest.
	* The new key `features_hvm` will be added, representing the subset of `features` that the host is able to offer to an HVM guest.
* A new field `pool.cpu_info` of type `(string -> string) map` (read only) will be added. It will contain:
	* `vendor`: The common CPU vendor across all hosts in the pool.
	* `features_pv`: The intersection of `features_pv` across all hosts in the pool, representing the feature set that a PV guest will see when started on the pool.
	* `features_hvm`: The intersection of `features_hvm` across all hosts in the pool, representing the feature set that an HVM guest will see when started on the pool.
	* `cpu_count`: the total number of CPU cores in the pool.
	* `socket_count`: the total number of CPU sockets in the pool.
* The `pool.other_config:cpuid_feature_mask` override key will no longer have any effect on pool join or VM migration.
* The field `VM.last_boot_CPU_flags` will be updated to the new format (see `host.cpu_info:features`). It will still contain the feature set that the VM was started with as well as the vendor (under the `features` and `vendor` keys respectively).

### Messages

* `pool.join` currently requires that the CPU vendor and feature set (according to `host.cpu_info:vendor` and `host.cpu_info:features`) of the joining host are equal to those of the pool master. This requirement will be loosened:
	* The join will be allowed if `host.cpu_info:vendor` equals `pool.cpu_info:vendor`, and `host.cpu_info:features_pv` ⊇ `pool.cpu_info:features_pv`, and `host.cpu_info:features_hvm` ⊇ `pool.cpu_info:features_hvm`.
	* That means that xapi will additionally allow hosts that have a more extensive feature set than the pool (as long as the CPU vendor is common). Such hosts are transparently down-levelled (without needing a reboot).
	* The current error raised in case of a CPU mismatch is `POOL_HOSTS_NOT_HOMOGENEOUS` with `reason` argument `"CPUs differ"`. This doesn't quite capture the new situation, and is hard to internationalise (the error code is used for other situations as well). We will introduce a new error `POOL_JOINING_HOST_CPUS_INCOMPATIBLE`, which is raised if the above criterion is not met.
	* The `pool.other_config:cpuid_feature_mask` override key will no longer have any effect.
* `host.set_cpu_features` and `host.reset_cpu_features` will be removed: it is no longer to use the old method of CPU feature masking. Calls will fail with `MESSAGE_REMOVED`.

CLI Changes
-----------

The following changes to the `xe` CLI will be made:

* `xe host-cpu-info` (as well as `xe host-param-list` and friends) will return the fields of `host.cpu_info` as described above.
* `xe host-set-cpu-features` and `xe host-reset-cpu-features` will be removed.
* `xe host-get-cpu-features` will still return the value of `host.cpu_info:features` for a given host.

Low-level implementation
========================

Xenctrl
-------

The old `xc_get_boot_cpufeatures` hypercall will be removed, and replaced by two new functions, which are available to xenopsd through the Xenctrl module:

	external get_levelling_caps : handle -> int64 = "stub_xc_get_levelling_caps"
	
	type featureset_index = Featureset_host | Featureset_pv | Featureset_hvm
	external get_featureset : handle -> featureset_index -> int64 array = "stub_xc_get_featureset"

Xenopsd
-------

* Update the type `Host.cpu_info`, which contains all the fields that need to go into the `host.cpu_info` field in the xapi DB. The type already exists but is unused. Add the function `HOST.get_cpu_info` to obtain an instance of the type. Some code from xapi and the cpuid.ml from xen-api-libs can be reused.
* Add a platform key `featureset` (`Vm.t.platformdata`), which xenopsd will write to xenstore along with the other platform keys (no code change needed in xenopsd). Xenguest will pick this up when a domain is created.
* Review current cpuid-related functions in `xc/domain.ml`.

Xapi
----

### Xapi startup

* Update `Create_misc.create_host_cpu` function to use the new xenopsd call. 
* If the host features fall below pool level, e.g. due to a change in hardware: Do no enable the host (leave it disabled in the startup sequence) and send a XenAPI alert `host_cpus_downgraded`.
	
### VM start

- Inherit feature set from pool (PV or HVM) and set `VM.last_boot_CPU_flags` (`cpuid_helpers.ml`).
- Include feature set string in `platformdata` (see above).

### VM migrate and resume

- There are already CPU compatiblity checks on migration, both in-pool and cross-pool, as well as resume. Xapi compares `VM.last_boot_CPU_flags` of the VM to-migrate with `host.cpu_info` of the receiving host. Migration is only allow if the CPU vendors and the same, and `host.cpu_info:features` ⊇ `VM.last_boot_CPU_flags:features`. The check can be overridden by setting the `force` argument to `true`.
- These checks need to be updated to use `pool.cpu_info` (`features_pv` or `features_hvm` depending on how the VM was booted) rather than `host.cpu_info`.
- Maintain `VM.last_boot_CPU_flags` and create a new domain with the same CPU features enabled.
- Include feature set string in `platformdata` (see above).

### VM import

The `VM.last_boot_CPU_flags` field must be upgraded to the new format (only really needed for VMs that were suspended while exported; `preserve_power_state=true`).

### Pool join

Update pool join checks according to the rules above (see `pool.join`).

### Upgrade

* Upgrade `VM.last_boot_CPU_flags` to the new format for running and suspended VMs.

*More details needed here!!*

XenCenter integration
---------------------

- Don't explicitly down-level upon join anymore
- Become aware of new pool join rule
- Update Rolling Pool Upgrade

