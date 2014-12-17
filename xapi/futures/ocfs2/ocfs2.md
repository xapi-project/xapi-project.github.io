---
title: OCFS2 storage
layout: default
design_doc: true
revision: 1
status: proposed
---

Insert a diagram showing:

- SM plugin of type 'OCFS2'
- O2CB configured for global heartbeats
- storage-clusterd with an O2CB config manager
- SAN
- multiple LUNs, one SR per LUN

Storage clusters
================

OCFS2 uses the O2CB "cluster stack" which is similar to our `xhad`. To configure
O2CB we need to

- assign each host an integer node number (from zero)
- on pool/cluster join: update the configuration on every node to include the
  new node. In OCFS2 this can be done online.
- on pool/cluster leave/eject: update the configuration on every node to exclude
  the old node. In OCFS2 this needs to be done offline.

In the current Xapi toolstack there is a single global implicit cluster called a "Pool"
which is used for: resource locking; "clustered" storage repositories and fault handling (in HA). In the long term we will allow these types of clusters to be
managed separately or all together, depending on the sophistication of the
admin and the complexity of their environment. We will take a small step in that
direction by keeping the OCFS2 O2CB cluster management code at "arms length"
from the Xapi Pool.join code.

In
[xcp-idl](https://github.com/xapi-project/xcp-idl)
we will define a new API category called "Cluster" (in addition to the
categories for
[Xen domains](https://github.com/xapi-project/xcp-idl/blob/37c676548a53b927ac411ab51f33892a7b891fda/xen/xenops_interface.ml#L102)
, [ballooning](https://github.com/xapi-project/xcp-idl/blob/37c676548a53b927ac411ab51f33892a7b891fda/memory/memory_interface.ml#L38)
, [stats](https://github.com/xapi-project/xcp-idl/blob/37c676548a53b927ac411ab51f33892a7b891fda/rrd/rrd_interface.ml#L76)
,
[networking](https://github.com/xapi-project/xcp-idl/blob/37c676548a53b927ac411ab51f33892a7b891fda/network/network_interface.ml#L106)
and
[storage](https://github.com/xapi-project/xcp-idl/blob/37c676548a53b927ac411ab51f33892a7b891fda/storage/storage_interface.ml#L51)
). These APIs will only be called by Xapi on localhost. In particular they will
not be called across-hosts and therefore do not have to be backward compatible.
These are "cluster plugin APIs".

We will define the following APIs:

- `Membership.create`: add a host to a cluster. On exit the local host cluster software
  will know about the new host but it may need to be restarted before the
  change takes effect
  - in:`hostname:string`: the hostname of the management domain
  - in:`uuid:string`: a UUID identifying the host
  - in:`id:int`: the lowest available unique integer identifying the host
      where an integer will never be re-used unless it is guaranteed that
      all nodes have forgotten any previous state associated with it
  - in:`address:string list`: a list of addresses through which the host
      can be contacted
  - out: Task.id
- `Membership.destroy`: removes a named host from the cluster. On exit the local
  host software will know about the change but it may need to be restarted
  before it can take effect  
  - in:`uuid:string`: the UUID of the host to remove
  `Cluster.query`: queries the state of the cluster
  - out:`needs_restart:bool`: true if there is some outstanding configuration
    change which cannot take effect until the cluster is restarted.
  - out:`hosts`: a list of all known hosts together with a state including:
    whether they are known to be alive or dead; or whether they are currently
    "excluded" because the cluster software needs to be restarted
- `Cluster.start`: turn on the cluster software and let the local host join
- `Cluster.stop`: turn off the cluster software

Xapi will be modified to:

- add table `Cluster` which will have columns
  - `name: string`: this is the name of the Cluster plugin (TODO: use same
    terminology as SM?)
- add table `Membership` which will have columns
  - `id: int`: automatically generated lowest available unique integer
    starting from 0
  - `cluster: Ref(Cluster)`: the type of cluster. This will never be NULL.
  - `host: Ref(host)`: the host which is a member of the cluster. This may
    be NULL.
  - `left: Date`: if not 1/1/1970 this means the time at which the host
    left the cluster.
- add field `Host.memberships: Set(Ref(Membership))`
- extend enum `vdi_type` to include `o2cb_statefile` as well as `ha_statefile`
- add method `Membership.create`
  - in: `self:Host`: the host to modify
  - in: `cluster:Cluster: the cluster.
  add method `Membership.destroy`
  - in: `self:Host`: the host to modify
  - in: `cluster:Cluster`: the cluster name.
- add a cluster monitor thread which
    - watches the `Host.memberships` field and calls `Membership.create` and
      `Membership.destroy` to keep the local cluster software up-to-date
      when any host changes its configuration
    - calls `Cluster.query` after an `create` or `destroy` to see whether the
      SR needs maintenance
    - when all hosts have a last start time later than a `Membership`
      record's `left` date, deletes the `Membership`.
- modify `Pool.join` to resync with the master's `Host.memberships` list.
- modify `Pool.eject` to
  - enter maintenance mode
  - call `Membership.destroy` in the cluster plugin
  - remove the `Host` metadata
  - set `Membership.left` to `NOW()`

A Cluster plugin called "o2cb" will be added which

- on `Cluster.remove`
  - comment out the relevant node id in cluster.conf
  - set the 'needs a restart' flag
- on `Cluster.add`
  - if the provided node id is too high: return an error. This means the
    cluster needs to be rebooted to free node ids.
  - if the node id is not too high: rewrite the cluster.conf using
    the "online" tool.
- on `Cluster.start`: find or create a VDI with `type=o2cb_statefile`;
  add this to the "static-vdis" list; `chkconfig` the service on. We
  will use the global heartbeat mode of `o2cb`.
- on `Cluster.stop`: stop the service; `chkconfig` the service off;
  remove the "static-vdis" entry; leave the VDI itself alone
- keeps track of the current 'live' cluster.conf which allows it to
  - report the cluster service as 'needing a restart' (which implies
    we need maintenance mode)

TODO: finding or creating the VDI here is racy

XenServer HA
============

We need to ensure `o2cb` and `xhad` do not try to conflict by fencing
hosts at the same time. We shall:

- use the default `o2cb` timeouts (hosts fence if no I/O in 60s): this
  needs to be short because disk I/O *on otherwise working hosts* can
  be blocked while another host is failing/ has failed.

- make the `xhad` host fence timeouts much longer: 300s. It's much more
  important that this is reliable than fast. We will make this change
  globally and not just when using OCFS2.

In the `xhad` config we will cap the `HeartbeatInterval` and `StatefileInterval`
at 5s (the default otherwise would be 31s). This means that 60 heartbeat
messages have to be lost before `xhad` concludes that the host has failed.

SM plugin
=========

File format

- vhd
- raw

TODO: who should set up the cluster?

I/O paths
=========

When either HA or OCFS O2CB "fences" the host it will look to the admin like
a host crash and reboot. We need to (in priority order)

1. help the admin *prevent* fences by monitoring their I/O paths
   and fixing issues before they lead to trouble
2. when a fence/crash does happen, help the admin
   - tell the difference between an I/O error (admin to fix) and a software
     bug (which should be reported)
   - understand how to make their system more reliable


Monitoring I/O paths
--------------------

If heartbeat I/O fails for more than 60s when running `o2cb` then the host will fence.
This can happen either

- for a good reason: for example the host software may have deadlocked; someone may
  have pulled the power; or perhaps a capacitor on the motherboard exploded

- for a bad reason: for example a network bond link failure may have been ignored
  and then the second link failed; or the heartbeat thread may have been starved of
  I/O bandwidth by other processes 

Since the consequences of fencing are severe -- all VMs on the host crash simultaneously --
it is important to avoid the host fencing for bad reasons.

We should recommend that all users

- use network bonding for their network heartbeat
- use multipath for their storage heartbeat

Furthermore we need to *help* users monitor their I/O paths. It's no good if they use
a bonded network but fail to notice when one of the paths have failed.

The current XenServer HA implementation generates the following I/O-related alerts:

- `HA_HEARTBEAT_APPROACHING_TIMEOUT` (priority 5 "informational"): when half the
  network heartbeat timeout has been reached.
- `HA_STATEFILE_APPROACHING_TIMEOUT` (priority 5 "informational"): when half the
  storage heartbeat timeout has been reached.
- `HA_NETWORK_BONDING_ERROR` (priority 3 "service degraded"): when one of the bond
  links have failed. Note this only works with the bridge and is silently missing
  with the OVS.
- `HA_STATEFILE_LOST` (priority 2 "service loss imminent"): when the storage heartbeat
  has completely failed and only the network heartbeat is left.
- MULTIPATH_PERIODIC_ALERT (priority 3 "service degrated"): when one of the multipath
  links have failed.

Unfortunately alerts are triggered on "edges" i.e. when state changes, and not on "levels"
so it is difficult to see whether the link is currently broken.

We should define datasources suitable for use by xcp-rrdd to expose the current state
(and the history) of the I/O paths as follows:

- `pif_<name>_paths_failed`: the total number of paths which we know have failed.
- `pif_<name>_paths_total`: the total number of paths which are configured.
- `sr_<name>_paths_failed`: the total number of storage paths which we know have failed.
- `sr_<name>_paths_total`: the total number of storage paths which are configured.

These datasources should be generated by `xcp-rrdd` plugins.

XenCenter (and any diagnostic tools) should warn when the system is at risk of fencing
in particular if any of the following are true:

- `pif_<name>_paths_failed` is non-zero
- `sr_<name>_paths_failed` is non-zero
- `pif_<name>_paths_total` is less than 2
- `sr_<name>_paths_total` is less than 2

Heartbeat "QoS"
---------------

The network and storage paths used by heartbeats *must* remain responsive otherwise
the host will fence (i.e. the host and all VMs will crash).

Outstanding issue: how slow can `multipathd` get? How does it scale with the number of
LUNs.

Post-crash diagnostics
======================

When a host crashes the effect on the user is severe: all the VMs will also
crash. In cases where the host crashed for a bad reason (such as a single failure
after a configuration error) we must help the user understand how they can
avoid the same situation happening again.

We must make sure the crash kernel runs reliably when `xhad` and `o2cb`
fence the host.

Xcp-rrdd will be modified to store RRDs in an `mmap(2)`d file in the dom0
filesystem (rather than in-memory). Xcp-rrdd will call `msync(2)` every 5s
to ensure the historical records have hit the disk.

Xapi will be modified to

- (when it looks for crash dumps): run a crash-dump analyser program which
outputs one of the following values:
- o2cb: if the kernel was panic'ed by o2cb
- xhad: if the Xen watchdog fired
- bug: otherwise, with the expectation that this bug report will be uploaded
somewhere or analysed by a developer
- add a new column `cause: String` to the `Host_crashdump` table. This will
contain the output of the script.
- if the cause was `o2cb` or `xhad` then:
  - consulting the archived RRDs, we will look for evidence of a path failure
    or a misconfiguration
  - if we can't find any evidence then we will say `unknown`

XenCenter will be modified to explain what the "cause" means and link to the
appropriate documentation.

Network configuration
=====================

The documentation should strongly recommend

- the management network is bonded
- the management network is dedicated i.e. used only for management traffic
  (including heartbeats)
- the OCFS2 storage is multipathed

Maintenance mode
================

The purpose of "maintenance mode" is to take a host out of service and leave
it in a state where it's safe to fiddle with it without affecting services
in VMs.

XenCenter currently does the following:

- `Host.disable`: prevents new VMs starting here
- makes a list of all the VMs running on the host
- `Host.evacuate`: move the running VMs somewhere else

The problems with maintenance mode are:

- it's not safe to fiddle with the host network configuration with storage
  still attached. For NFS this risks deadlocking the SR. For OCFS2 this
  risks fencing the host.
- it's not safe to fiddle with the storage or network configuration if HA
  is running because the host will be fenced. It's not safe to disable fencing
  unless we guarantee to reboot the host on exit from maintenance mode.

We should also

- `PBD.unplug`: all storage. This allows the network to be safely reconfigured.
  If the network is configured when NFS storage is plugged then the SR can
  permanently deadlock; if the network is configured when OCFS2 storage is
  plugged then the host can crash.

TODO: should we add a `Host.prepare_for_maintenance` (better name TBD)
to take care of all this without XenCenter having to script it. This would also
help CLI and powershell users do the right thing.

TODO: should we insist that the host is rebooted to leave maintenance
mode? This would make maintenance mode more reliable and allow us to integrate
maintenance mode with xHA (where maintenance mode is a "staged reboot")

TODO: should we leave all clusters as part of maintenance mode? We
probably need to do this to avoid fencing.

Walk-through: adding OCFS2 storage
==================================

Walk-through: remove a host
===========================

Walk-through: after a crash
===========================

Summary of the impact on the admin
==================================

OCFS2 is fundamentally a different type of storage to all existing storage
types supported by xapi. OCFS2 relies upon O2CB, which provides
[Host-level High Availability](../../features/HA/HA.md). All HA implementations
(including O2CB and `xhad`) impose restrictions on the server admin to
prevent unnecessary host "fencing" (i.e. crashing). Once we have OCFS2 as
a feature, we will have to live with these restrictions which previously only
applied when HA was explicitly enabled. To reduce complexity we will not try
to enforce restrictions only when OCFS2 is being used or is likely to be used.

Impact even if not using OCFS2
------------------------------

- "Maintenance mode" now includes detaching all storage.
- Host network reconfiguration can only be done in maintenance mode
- XenServer HA enable takes longer
- XenServer HA failure detection takes longer


Impact when using OCFS2
-----------------------

- Sometimes a host will not be able to join the pool without taking the
  pool into maintenance mode
