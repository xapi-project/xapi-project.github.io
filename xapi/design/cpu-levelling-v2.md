---
title: CPU feature levelling 2.0
layout: default
design_doc: true
status: proposed
revision: 5
revision_history:
- revision_number: 1
  description: Initial version
- revision_number: 2
  description: Add details about VM migration and import
- revision_number: 3
  description: Included and excluded use cases
- revision_number: 4
  description: Rolling Pool Upgrade use cases
- revision_number: 5
  description: Lots of changes to simplify the design
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

A VM can only be migrated safely from one host to another if both hosts offer the set of CPU features which the VM expects.  If this is not the case, CPU features may appear or disappear as the VM is migrated, causing it to crash.   The purpose of feature levelling is to hide features which the hosts do not have in common from the VM, so that it does not see any change in CPU capabilities when it is migrated.

Most pools start off with homogenous hardware, but over time it may become impossible to source new hosts with the same specifications as the ones already in the pool.   The main use of feature levelling is to allow such newer, more capable hosts to be added to an existing pool while preserving the ability to migrate existing VMs to any host in the pool.

XXX: If all the hosts in a pool are upgraded to more capable models, the overall feature set offered by the pool could also be updated to be the intersection of the features offered by the upgraded hosts.   Upgrading the pool-level feature set will not be implemented in the first release of this feature.

Principles
----------

The CPU levelling feature aims to both:

1. Make VM migrations _safe_ by ensuring that a VM will see the same CPU features before and after a migration.
2. Make VMs as _mobile_ as possible, so that it can be freely migrated around in a XenServer pool.

To make migrations safe:

* A migration request will be blocked if the destination host does not offer the some of the CPU features that the VM currently sees.
* Any additional CPU features that the destination host is able to offer will be hidden from the VM.

To make VMs mobile:

* A VM that is started in a XenServer pool will be able to see only CPU features that are common to all hosts in the pool.

Included use cases
------------------

 1. A user wants to add a new host to an existing XenServer pool.   The new host has all the features of the existing hosts, plus extra features which the existing hosts do not.   The new host will be allowed to join the pool, but its extra features will be hidden from VMs.
 
 2. A user wants to add a new host to an existing XenServer pool.   The new host does not have all the features of the existing ones.   The new host will not be allowed to join the pool.
 
 3. A user wants to upgrade or repair the hardware of a host in an existing XenServer pool.   After upgrade the host has all the features it used to have, plus extra features which other hosts in the pool do not have.   The extra features are masked out and the host resumes its place in the pool when it is booted up again.
 
 4. A user wants to upgrade or repair the hardware of a host in an existing XenServer pool.   After upgrade the host has fewer features than it used to have.   When the host is booted up again, it is disabled in the pool and no VMs can be started on it or migrated to it.
 
 5. A user wants to remove a host from an existing XenServer pool.    The host will be removed as normal after any VMs on it have been migrated away.   The feature set offered by the pool will not change, even if the host which was removed was the least capable in the pool and its removal would allow additional features common to the remaining hosts to be unmasked.
 
 6. A user wants to re-add a host to an existing XenServer pool from which the host had previously been removed.  The host will be allowed to join the pool, because the pool feature set was not recalculated when it was removed.   This use case ensures that a host which was removed for maintenance or to be kept as a cold spare can later be re-added.
 
Excluded use cases
------------------
 
 1. A user wants to create a pool by joining a new host to an existing XenServer host which is not running any VMs.   The new host does not have all the features of the existing one.   The new host will not be allowed to join the pool.   In future, a 're-levelling' command could allow the user to mask features of the existing XenServer host to match those offered by the new host.   If the pool had no VMs, this operation would be safe.   To work around this problem, hosts should be added to a pool in increasing order of capability.
 
 2. A user wants to replace all the hosts in an existing XenServer pool with newer, more capable models and upgrade the pool's feature set to reveal the features offered by the new hosts.   The pool feature set will remain the same, even after the last of the older, less capable hosts is removed.   In the future, 're-levelling' could allow the pool feature set to be expanded, however this should only be done with the user's consent as doing so would prevent any older hosts from being re-added to the pool.
 
Rolling pool upgrade
--------------------
 
* When a heterogeneous pool is upgraded, it might turn out that the master is the most capable host.   If the pool level is set to the master's level, then all the other hosts will be disabled after the upgrade.   Instead, as each host is upgraded and comes back online, we will compare its feature level with the pool level and down-level the pool if the newly-upgraded host is below the pool's level.
 
* A VM which was running on the pool before the upgrade is expected to continue to run afterwards.   However, when the VM is migrated to an upgraded host, some of the CPU features it had been using might disappear, either because they are not offered by the host or because the new feature-levelling mechanism hides them.   To allow such a VM to continue running, it will be given a temporary VM-level feature set allowing all CPU features.   When the VM is rebooted it will inherit the pool-level feature set.

* A VM which is started during the upgrade will be given the current pool-level feature set.   The pool-level feature set may drop after the VM is started, as more hosts are upgraded and re-join the pool, however the VM is guaranteed to be able to migrate to any host which has already been upgraded.   If the VM is started on the master, there is a risk that it may only be able to run on that host.
 
* To allow the VMs with grandfathered-in flags to be migrated around in the pool, the intra pool VM migration pre-checks will compare the VM's feature flags to the target host's flags, not the pool flags.   This will maximise the chance that a VM can be migrated somewhere in a heterogeneous pool, particularly in the case where only a few hosts in the pool do not have features which the VMs require.   TODO: This requires that the VM's feature set describes roughly what features it requires;  with an 'allow all' feature set, we can't choose the best host for a VM.   The best we can do is to migrate the VM to the most capable host with space in the pool.
  
* To allow cross-pool migration, we will still check the VM's requirements against the *pool-level* features of the target pool.   This is to avoid the possibility that we migrate a VM to an 'island' in the other pool, from which it cannot be migrated any further.


XenAPI Changes
--------------

### Fields

* `host.cpu_info` is a field of type `(string -> string) map` that contains information about the CPUs in a host. It contains the following keys: `cpu_count`, `socket_count`, `vendor`, `speed`, `modelname`, `family`, `model`, `stepping`, `flags`, `features`, `features_after_reboot`, `physical_features` and `maskable`.
	* The following keys are specific to hardware-based CPU masking and will be removed: `features_after_reboot`, `physical_features` and `maskable`.
	* The `features` key will continue to hold the current CPU features that the host is able to use. In practise, these features will be available to Xen itself and dom0; guests may only see a subset. The current format is a string of four 32-bit words represented as four groups of 8 hexadecimal digits, separated by dashes. This will change to an arbitrary number of 32-bit words. Each bit at a particular position (starting from the left) still refers to a distinct CPU feature (`1`: feature is present; `0`: feature is absent), and feature strings may be compared between hosts. The old format simply becomes a special (4 word) case of the new format, and bits in the same position may be compared between old and new feature strings.
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

* `pool.join` currently requires that the CPU vendor and feature set (according to `host.cpu_info:vendor` and `host.cpu_info:features`) of the joining host are equal to those of the pool master. This requirement will be loosened to mandate only equality in CPU vendor:
	* The join will be allowed if `host.cpu_info:vendor` equals `pool.cpu_info:vendor`.
	* This means that xapi will additionally allow hosts that have a _more_ extensive feature set than the pool (as long as the CPU vendor is common). Such hosts are transparently down-levelled to the pool level (without needing reboots).
	* This further means that xapi will additionally allow hosts that have a _less_ extensive feature set than the pool (as long as the CPU vendor is common). In this case, the pool is transparently down-levelled to the new host's level (without needing reboots). Note that this does not affect any running VMs in any way; the mobility of running VMs will not be restricted.
	* The current error raised in case of a CPU mismatch is `POOL_HOSTS_NOT_HOMOGENEOUS` with `reason` argument `"CPUs differ"`. This will remain the error that is raised if the pool join fails due to incompatible CPU vendors.
	* The `pool.other_config:cpuid_feature_mask` override key will no longer have any effect.
* `host.set_cpu_features` and `host.reset_cpu_features` will be removed: it is no longer to use the old method of CPU feature masking (CPU feature sets are controlled automatically by xapi). Calls will fail with `MESSAGE_REMOVED`.
* VM lifecycle operations will be updated internally to use the new feature fields, to ensure that:
	* Newly started VMs will be given CPU features according to the pool level for maximal mobility.
	* For safety, running VMs will maintain their feature set across migrations and suspend/resume cycles. CPU features will transparently be hidden from VMs.
	* Furthermore, migrate and resume will only be allowed in case the target host's CPUs are capable enough, i.e. `host.cpu_info:vendor` = `VM.last_boot_CPU_flags:vendor` and `host.cpu_info:features_{pv,hvm}` ⊇ `VM.last_boot_CPU_flags:features`. A `VM_INCOMPATIBLE_WITH_THIS_HOST` error will be returned otherwise (as happens today).
	* For cross pool migrations, to ensure maximal mobility in the target pool, a stricter condition will apply: the VM must satisfy the pool CPU level rather than just the target host's level: `pool.cpu_info:vendor` = `VM.last_boot_CPU_flags:vendor` and `pool.cpu_info:features_{pv,hvm}` ⊇ `VM.last_boot_CPU_flags:features`


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

In particular, the `get_featureset` function will be used by xapi/xenopsd to ask Xen which are the widest sets of CPU features that it can offer to a VM (PV or HVM). I don't think there is a use for `get_levelling_caps` yet.

Xenopsd
-------

* Update the type `Host.cpu_info`, which contains all the fields that need to go into the `host.cpu_info` field in the xapi DB. The type already exists but is unused. Add the function `HOST.get_cpu_info` to obtain an instance of the type. Some code from xapi and the cpuid.ml from xen-api-libs can be reused.
* Add a platform key `featureset` (`Vm.t.platformdata`), which xenopsd will write to xenstore along with the other platform keys (no code change needed in xenopsd). Xenguest will pick this up when a domain is created, and will apply the CPUID policy to the domain. This has the effect of masking out features that the host may have, but which have a `0` in the feature set bitmap.
* Review current cpuid-related functions in `xc/domain.ml`.

Xapi
----

### Xapi startup

* Update `Create_misc.create_host_cpu` function to use the new xenopsd call. 
* If the host features fall below pool level, e.g. due to a change in hardware: down-level the pool by updating `pool.cpu_info.features_{pv,hvm}`. Newly started VMs will inherit the new level; already running VMs will not be affected, but will not be able to migrate to this host.
	
### VM start

- Inherit feature set from pool (`pool.cpu_info.features_{pv,hvm}`) and set `VM.last_boot_CPU_flags` (`cpuid_helpers.ml`).
- The domain will be started with this CPU feature set enabled, by writing the feature set string to `platformdata` (see above).

### VM migrate and resume

- There are already CPU compatiblity checks on migration, both in-pool and cross-pool, as well as resume. Xapi compares `VM.last_boot_CPU_flags` of the VM to-migrate with `host.cpu_info` of the receiving host. Migration is only allowed if the CPU vendors and the same, and `host.cpu_info:features` ⊇ `VM.last_boot_CPU_flags:features`. The check can be overridden by setting the `force` argument to `true`.
- For in-pool migrations, these checks will be updated to use the appropriate `features_pv` or `features_hvm` field.
- For cross-pool migrations. These checks will be updated to use `pool.cpu_info` (`features_pv` or `features_hvm` depending on how the VM was booted) rather than `host.cpu_info`.
- If the above checks pass, then the `VM.last_boot_CPU_flags` will be maintained, and the new domain will be started with the same CPU feature set enabled, by writing the feature set string to `platformdata` (see above).
- In case the VM is migrated to a host with a higher xapi software version (e.g. a migration from a host that does not have CPU levelling v2), the feature string may be longer. This may happen during a rolling pool upgrade or a cross-pool migration, or when a suspended VM is resume after an upgrade. In this case, the following safety rules apply:
	- Only the existing (shorter) feature string will be used to determine whether the migration will be allowed. This is the best we can do, because we are unaware of the state of the extended feature set on the older host.
	- The existing feature set in `VM.last_boot_CPU_flags` will be extended with the extra bits in `host.cpu_info:features`, i.e. the widest feature set that can possibly be granted to the VM (just in case the VM was using any of these features before the migration). (XXX: should this be based on `_{pv,hvm}`?)

### VM import

The `VM.last_boot_CPU_flags` field must be upgraded to the new format (only really needed for VMs that were suspended while exported; `preserve_power_state=true`), as described above.

### Pool join

Update pool join checks according to the rules above (see `pool.join`), i.e. remove the CPU features constraints.

### Upgrade

* The pool level (`pool.cpu_info`) will be initialised when the pool master upgrades, and automatically adjusted if needed (downwards) when slaves are upgraded, by each upgraded host's started sequence (as above under "Xapi startup").
* The `VM.last_boot_CPU_flags` fields of running and suspended VMs will be "upgraded" to the new format on demand, when a VM is migrated to or resume on an upgraded host, as described above.


XenCenter integration
---------------------

- Don't explicitly down-level upon join anymore
- Become aware of new pool join rule
- Update Rolling Pool Upgrade

