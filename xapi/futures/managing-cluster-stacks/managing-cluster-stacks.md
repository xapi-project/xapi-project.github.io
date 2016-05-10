---
title: Managing Cluster Stacks
layout: design
design_doc: true
revision: 1
status: proposed
---

When investigation several options for distributed and clustered
filesystems, there have been dependencies on cluster management
software such as O2CB for OCFS2 and corosync for GFS2.

In the current Xapi toolstack there is a single global implicit
cluster called a "Pool" which is used for: resource locking;
"clustered" storage repositories and fault handling (in HA). In the
long term we will allow these types of clusters to be managed
separately or all together, depending on the sophistication of the
admin and the complexity of their environment. We will take a small
step in that direction by keeping the cluster management code at "arms
length" from the Xapi Pool.join code.

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

- `Plugin:Membership.create`: add a host to a cluster. On exit the local host cluster software
  will know about the new host but it may need to be restarted before the
  change takes effect
  - in:`cluster:string`: the uuid of the cluster
  - in:`hostname:string`: the hostname of the management domain
  - in:`uuid:string`: a UUID identifying the host
  - in:`id:int`: the lowest available unique integer identifying the host
      where an integer will never be re-used unless it is guaranteed that
      all nodes have forgotten any previous state associated with it
  - in:`configuration:Map(String,String)`: the configuration field of the cluster row.
  - in:`address:string list`: a list of addresses through which the host
      can be contacted
  - out: unit
- `Plugin:Membership.destroy`: removes a named host from the cluster. On exit the local
  host software will know about the change but it may need to be restarted
  before it can take effect  
  - in:`uuid:string`: the UUID of the host to remove
  `Plugin:Cluster.query`: queries the state of the cluster
  - out:`maintenance_required:bool`: true if there is some outstanding configuration
    change which cannot take effect until the cluster is restarted.
  - out:`hosts`: a list of all known hosts together with a state including:
    whether they are known to be alive or dead; or whether they are currently
    "excluded" because the cluster software needs to be restarted
- `Plugin:Cluster.start`: turn on the cluster software and let the local host join.
  This call must be idempotent.
- `Plugin:Cluster.stop`: turn off the cluster software

Xapi will be modified to:

- add table `Cluster` which will have columns
  - `name: string`: this is the name of the Cluster plugin (TODO: use same
    terminology as SM?)
  - 'configuration: Map(String,String)`: this will contain any cluster-global
    information, overrides for default values etc.
  - `enabled: Bool`: this is true when the cluster "should" be running. It
    may require maintenance to synchronise changes across the hosts.
  - `maintenance_required: Bool`: this is true when the cluster needs to
    be placed into maintenance mode to resync its configuration
- add method `XenAPI:Cluster.enable` which sets `enabled=true` and waits for all
  hosts to report `Membership.enabled=true`.
- add method `XenAPI:Cluster.disable` which sets `enabled=false` and waits for all
  hosts to report `Membership.enabled=false`.
- add table `Membership` which will have columns
  - `id: int`: automatically generated lowest available unique integer
    starting from 0
  - `cluster: Ref(Cluster)`: the type of cluster. This will never be NULL.
  - `host: Ref(host)`: the host which is a member of the cluster. This may
    be NULL.
  - `left: Date`: if not 1/1/1970 this means the time at which the host
    left the cluster.
  - `maintenance_required: Bool`: this is true when the Host believes the
    cluster needs to be placed into maintenance mode.
- add field `Host.memberships: Set(Ref(Membership))`
- add method `Pool.enable_corosync` with arguments
  - in: `configuration: Map(String,String)`: available for future configuration tweaks
  - This will create the
    `Cluster` entry and the `Membership` entries. All `Memberships` will have
    `maintenance_required=true` reflecting the fact that the desired cluster
    state is out-of-sync with the actual cluster state.
- add method `XenAPI:Membership.enable`
  - in: `self:Host`: the host to modify
  - in: `cluster:Cluster: the cluster.
- add method `XenAPI:Membership.disable`
  - in: `self:Host`: the host to modify
  - in: `cluster:Cluster`: the cluster name.
- add a cluster monitor thread which
    - watches the `Host.memberships` field and calls `Plugin:Membership.create` and
      `Plugin:Membership.destroy` to keep the local cluster software up-to-date
      when any host in the pool changes its configuration
    - if the host was not previously in a cluster, it will call `Plugin:Membership.create`
      for every host in the cluster before calling `Plugin:Cluster.start`
    - calls `Plugin:Cluster.query` after an `Plugin:Membership:create` or
      `Plugin:Membership.destroy` to see whether the cluster software needs
      rsynchronising
    - when all hosts have a last start time later than a `Membership`
      record's `left` date, deletes the `Membership`.
- modify `XenAPI:Pool.join` to resync with the master's `Host.memberships` list.
- modify `XenAPI:Pool.eject` to
  - call `Membership.disable` in the cluster plugin to stop the `corosync` or other service
  - call `Membership.destroy` in the cluster plugin to remove every other host
    from the local configuration
  - remove the `Host` metadata from the pool
  - set `XenAPI:Membership.left` to `NOW()`
- modify `XenAPI:Host.forget` to
  - remove the `Host` metadata from the pool
  - set `XenAPI:Membership.left` to `NOW()`
  - set `XenAPI:Cluster.maintenance_required` to true

A Cluster plugin called "corosync" will be added which

- on `Plugin:Membership.destroy`
  - comment out the relevant node id in corosync.conf
  - set the 'needs a restart' flag (?)
- on `Plugin:Membership.create`
  - Create the corosync.conf configuration file. Example:
```
totem {
  version: 2
  secauth: off
  cluster_name: <<POOL UUID>>
  transport: udpu
  token_retransmits_before_loss_const: 10
  token: 10000
}

logging {
  debug: on
}

quorum {
  provider: corosync_votequorum
}

nodelist {
  node {
    ring0_addr: <<IP ADDRESS>>
    nodeid: <<ID>>
  }
  node {
    ring0_addr: <<ANOTHER IP ADDRESS>>
    nodeid: <<ID>>
  }
}
```
  - enable the corosync and dlm services
- on `Plugin:Cluster.stop`: stop the dlm and corosync services; `chkconfig` the services off;
- keeps track of the current 'live' corosync.conf which allows it to
  - report the cluster service as 'needing a restart' (which implies
    we need maintenance mode)

