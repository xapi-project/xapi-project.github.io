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

In the current Xapi toolstack there is a single global cluster called a "Pool"
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

We will define the following APIs:

- `Cluster.add`: add a host to a cluster. On exit the local host software
  will know about the new host but it may need to be restarted before the
  change takes effect
  - in:`hostname:string`: the hostname of the management domain
  - in:`uuid:string`: a UUID identifying the host
  - in:`address:string list`: a list of addresses through which the host
      can be contacted
  - out: Task.id
- `Cluster.remove`: removes a named host from the cluster. On exit the local
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

- add read-only field `Host.clusters: Set(String)`: a set of string names for
  the clusters this host is supposed to be in, which may be different to the
  set of cluster services actually running. For now there will be
  2 legal values: [] and [ "o2cb" ]. In future we might add "xhad". The
  default value for schema upgrade is [].
- extend enum `vdi_type` to include `o2cb_statefile` as well as `ha_statefile`
- add method `Host.join`
  - in: `self:Host`: the host to modify
  - in: `cluster:String`: the cluster name. The only legal value is "o2cb".
  add method `Host.leave`
  - in: `self:Host`: the host to modify
  - in: `cluster:String`: the cluster name. The only legal value is "o2cb".
- modify `Pool.join` to resync with the master's `Host.clusters` list.
- modify `Pool.eject` to enter maintenance mode and to call `Cluster.leave`
  on the target host and the master (and as many other nodes as possible)
- modify `Pool.hello` to join the same clusters as the master.

This is not quite right -- every host needs to know about every other host.

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

Standard alerts
---------------

- network bonding
- multipath

Recommended visibility in the UI

Post-crash diagnostics
----------------------

A tool to read the stack from the crash kernel dump and determine which system
reset the host. We need to display this somewhere.

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
