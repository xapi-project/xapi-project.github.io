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

SM plugin
=========

File format

- vhd
- raw

TODO: who should set up the cluster?

Monitoring and diagnostics
==========================

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

If I/O fails for more than 60s when running `o2cb` then the host will fence.

Multipath QoS

Heartbeat QoS

Standard alerts
---------------

- network bonding
- multipath

Recommended visibility in the UI

Post-crash diagnostics
----------------------

We must make sure the crash kernel runs reliably when `xhad` and `o2cb`
fence the host.

Xapi will be modified to

- (when it looks for crash dumps): run a crash-dump analyser program which
outputs one of the following values:
- o2cb: if the kernel was panic'ed by o2cb
- xhad: if the Xen watchdog fired
- bug: otherwise, with the expectation that this bug report will be uploaded
somewhere or analysed by a developer
- add a new column `cause: String` to the `Host_crashdump` table. This will
contain the output of the script.
- if the cause was `o2cb` then: TODO: some kind of alert?
- if the cause was `xhad` then: TODO: some kind of alert?

XenCenter will be modified to: (The goal is to help the user understand
what happened and to fix it)

Network configuration
=====================

Bonding
Monitoring the bond (as xhad does)

Open question: how dependent is OCFS2 on hostnames?

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

Open question: should we add a `Host.prepare_for_maintenance` (better name TBD)
to take care of all this without XenCenter having to script it. This would also
help CLI and powershell users do the right thing.

Open question: should we insist that the host is rebooted to leave maintenance
mode? This would make maintenance mode more reliable and allow us to integrate
maintenance mode with xHA (where maintenance mode is a "staged reboot")

Open question: should we leave all clusters as part of maintenance mode? We
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

- "Maintenance mode" now includes detaching all storage.
- Host network reconfiguration can only be done in maintenance mode
