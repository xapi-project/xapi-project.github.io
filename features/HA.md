---
title: High-Availability
layout: default
---

High-Availability (HA) tries to keep VMs running, even when there are hardware
failures in the resource pool, when the admin is not present. Without HA
the following may happen:

- during the night someone spills a cup of coffee over an FC switch; then
- VMs running on the affected hosts will lose access to their storage; then
- business-critical services will go down; then
- monitoring software will send a text message to an off-duty admin; then
- the admin will travel to the office and fix the problem by restarting
  the VMs elsewhere.

With HA the following will happen:

- during the night someone spills a cup of coffee over an FC switch; then
- VMs running on the affected hosts will lose access to their storage; then
- business-critical services will go down; then
- the HA software will determine which hosts are affected and shut them down; then
- the HA software will restart the VMs on unaffected hosts; then
- services are restored; then *on the next working day*
- the admin can arrange for the faulty switch to be replaced.

HA is designed to handle an emergency and allow the admin time to fix
failures properly.

Example
=======

The following diagram shows an HA-enabled pool, before and after a network
link between two hosts fails.

![High-Availability in action](http://xapi-project.github.io/xapi-project/doc/features/ha.png)

When HA is enabled, all hosts in the pool
- exchange periodic heartbeat messages over the network
- send heartbeats to a shared storage device.
- attempt to acquire a "master lock" on the shared storage.

HA is designed to recover as much as possible of the pool after a single failure
i.e. it removes single points of failure. When some subset of the pool suffers
a failure then the remaining pool members
- figure out whether they are in the largest fully-connected set;
  - if they are not in the largest set then they "fence" themselves (i.e.
    force reboot via the hypervisor watchdog)
- elect a master using the "master lock"
- restart all lost VMs.

After HA has recovered a pool, it is important that the original failure is
addressed because the remaining pool members may not be able to cope with
any more failures.

Design
======

HA consists of the following components:

- [xhad](https://github.com/xenserver/xhad): the cluster membership daemon
  maintains a quorum of hosts through network and storage heartbeats
- [xapi](https://github.com/xapi-project/xen-api): used to configure the
  HA policy i.e. which network and storage to use for heartbeating and which
  VMs to restart after a failure.
- [xen](https://xenproject.org/): the Xen watchdog is used to reliably
  fence the host when the host has been (partially or totally) isolated
  from the cluster

To avoid a "split-brain", the cluster membership daemon must "fence" (i.e.
isolate) nodes when they are not part of the cluster. In general there are
2 approaches:

- cut the power of remote hosts which you can't talk to on the network
  any more. This is the approach taken by most open-source clustering
  software since it is simpler. However it has the downside of requiring
  the customer buy more hardware and set it up correctly.
- rely on the remote hosts using a watchdog to cut their own power (i.e.
  halt or reboot) after a timeout. This relies on the watchdog being
  reliable. Most other people [don't trust the Linux watchdog](http://doc.opensuse.org/products/draft/SLE-HA/SLE-ha-guide_sd_draft/cha.ha.requirements.html); 
  after all the Linux kernel is highly threaded, performs a lot of (useful)
  functions and kernel bugs which result in deadlocks do happen.
  We use the Xen watchdog because we believe that the Xen hypervisor is
  simple enough to reliably fence the host (via triggering a reboot of
  domain 0 which then triggers a host reboot).

xhad
====

[xhad](https://github.com/xenserver/xhad) is the cluster membership daemon:
it exchanges heartbeats with the other nodes to determine which nodes are
still in the cluster (the "live set") and which nodes have *definitely*
failed (through watchdog fencing). When a host has definitely failed, xapi
will unlock all the disks and restart the VMs according to the HA policy.

Since Xapi is a critical part of the system, the xhad also acts as a
Xapi watchdog. It polls Xapi every few seconds and checks if Xapi can
respond. If Xapi seems to have failed then xhad will restart it. If restarts
continue to fail then xhad will consider the host to have failed and
self-fence.

xhad is configured via a simple config file written on each host in
```/etc/xensource/xhad.conf```. The file must be identical on each host
in the cluster. To make changes to the file, HA must be disabled and then
re-enabled afterwards. Note it may not be possible to re-enable HA depending
on the configuration change (e.g. if a host has been added but that host has
a broken network configuration then this will block HA enable).

The xhad.conf file is written in XML and contains

- pool-wide configuration: this includes a list of all hosts which should
  be in the liveset and global timeout information
- local host configuration: this identifies the local host and described
  which local network interface and block device to use for heartbeating.

The following is an example xhad.conf file:
```
<?xml version="1.0" encoding="utf-8"?>
<xhad-config version="1.0">

  <!--pool-wide configuration-->
  <common-config>
    <GenerationUUID>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</GenerationUUID>
    <UDPport>694</UDPport>

    <!--for each host, specify host UUID, and IP address-->
    <host>
      <HostID>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</HostID>
      <IPaddress>xxx.xxx.xxx.xx1</IPaddress>
    </host>

    <host>
      <HostID>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</HostID>
      <IPaddress>xxx.xxx.xxx.xx2</IPaddress>
    </host>

    <host>
      <HostID>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</HostID>
      <IPaddress>xxx.xxx.xxx.xx3</IPaddress>
    </host>

    <!--optional parameters [sec] -->
    <parameters>
      <HeartbeatInterval>4</HeartbeatInterval>
      <HeartbeatTimeout>30</HeartbeatTimeout>
      <StateFileInterval>4</StateFileInterval>
      <StateFileTimeout>30</StateFileTimeout>
      <HeartbeatWatchdogTimeout>30</HeartbeatWatchdogTimeout>
      <StateFileWatchdogTimeout>45</StateFileWatchdogTimeout>
      <BootJoinTimeout>90</BootJoinTimeout>
      <EnableJoinTimeout>90</EnableJoinTimeout>
      <XapiHealthCheckInterval>60</XapiHealthCheckInterval>
      <XapiHealthCheckTimeout>10</XapiHealthCheckTimeout>
      <XapiRestartAttempts>1</XapiRestartAttempts>
      <XapiRestartTimeout>30</XapiRestartTimeout>
      <XapiLicenseCheckTimeout>30</XapiLicenseCheckTimeout>
    </parameters>
  </common-config>

  <!--local host configuration-->
  <local-config>
    <localhost>
      <HostID>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx2</HostID>
      <HeartbeatInterface> xapi1</HeartbeatInterface>
      <HeartbeatPhysicalInterface>bond0</HeartbeatPhysicalInterface>
      <StateFile>/dev/statefiledevicename</StateFile>
    </localhost>
  </local-config>

</xhad-config>
```

The fields have the following meaning:

- GenerationUUID: a UUID generated each time HA is reconfigured. This allows
  xhad to tell an old host which failed; had been removed from the
  configuration; repaired and then restarted that the world has changed
  while it was away.
- UDPport: the port number to use for network heartbeats. It's important
  to allow this traffic through the firewall and to make sure the same
  port number is free on all hosts (beware of portmap services occasionally
  binding to it).
- HostID: a UUID identifying a host in the pool. We would normally use
  xapi's notion of a host uuid.
- IPaddress: any IP address on the remote host. We would normally use
  xapi's notion of a management network.
- HeartbeatTimeout: if a heartbeat packet is not received for this many
  seconds, then xhad considers the heartbeat to have failed. This is
  the user-supplied "HA timeout" value, represented below as ```T```.
  ```T``` must be bigger than 10; we would normally use 60s.
- StateFileTimeout: if a storage update is not seen for a host for this
  many seconds, then xhad considers the storage heartbeat to have failed.
  We would normally use the same value as the HeartbeatTimeout ```T```.
- HeartbeatInterval: interval between heartbeat packets sent. We would
  normally use a value ```2 <= t <= 6```, derived from the user-supplied
  HA timeout via ```t = (T + 10) / 10```
- StateFileInterval: interval betwen storage updates (also known as
  "statefile updates"). This would normally be set to the same value as
  HeartbeatInterval.
- HeartbeatWatchdogTimeout: If the host does not send a heartbeat for this
  amount of time then the host self-fences via the Xen watchdog. We normally
  set this to ```T```.
- StateFileWatchdogTimeout: If the host does not update the statefile for
  this amount of time then the host self-fences via the Xen watchdog. We
  normally set this to ```T+15```.
- BootJoinTimeout: When the host is booting and joining the liveset (i.e.
  the cluster), consider the join a failure if it takes longer than this
  amount of time. We would normally set this to ```T+60```.
- EnableJoinTimeout: When the host is enabling HA for the first time,
  consider the enable a failure if it takes longer than this amount of time.
  We would normally set this to ```T+60```.
- XapiHealthCheckInterval: Interval between "health checks" where we run
  a script to check whether Xapi is responding or not.
- XapiHealthCheckTimeout: Number of seconds to wait before assuming that
  Xapi has deadlocked during a "health check".
- XapiRestartAttempts: Number of Xapi restarts to attempt before concluding
  Xapi has permanently failed.
- XapiRestartTimeout: Number of seconds to wait for a Xapi restart to
  complete before concluding it has failed.
- XapiLicenseCheckTimeout: Number of seconds to wait for a Xapi license
  check to complete before concluding that xhad should terminate.

In addition to the config file, Xhad exposes a simple control API which
is exposed as scripts:

- ```ha_set_pool_state (Init | Invalid)```: sets the global pool state to "Init" (before starting
  HA) or "Invalid" (causing all other daemons who can see the statefile to
  shutdown)
  "Invalid"
- ```ha_start_daemon```: if the pool state is "Init" then the daemon will
  attempt to contact other daemons and enable HA. If the pool state is
  "Active" then the host will attempt to join the existing liveset.
- ```ha_query_liveset```: returns the current state of the cluster.
- ```ha_propose_master```: returns whether the current node has been
  elected pool master.
- ```ha_stop_daemon```: shuts down the xhad on the local host. Note this
  will not disarm the Xen watchdog by itself.
- ```ha_disarm_fencing```: disables fencing on the local host.
- ```ha_set_excluded```: when a host is being shutdown cleanly, record the
  fact that the VMs have all been shutdown so that this host can be ignored
  in future cluster membership calculations.

Fencing
-------

Xhad continuously monitors whether the host should remain alive, or if
it should self-fence. There are two "survival rules" which will keep a host
alive; if neither rule applies (or if xhad crashes or deadlocks) then the
host will fence. The rules are:

1. Xapi is running; the storage heartbeats are visible; this host is a
   member of the "best" partition (as seen through the storage heartbeats)

where the "best" partition is the largest one if that is unique, or if there
are multiple partitions of the same size then the one containing the lowest
host uuid is considered best.

2. Xapi is running; the storage is inaccessible; all hosts which should
   be running (i.e. not those "excluded" by being cleanly shutdown) are
   online and have also lost storage access (as seen through the network
   heartbeats).

The first survival rule is the "normal" case. The second rule exists only
to prevent the storage from becoming a single point of failure: all hosts
can remain alive until the storage is repaired. Note that if a host has
failed and has not yet been repaired, then the storage becomes a single
point of failure for the degraded pool. HA removes single point of failures,
but multiple failures can still cause problems. It is important to fix
failures properly after HA has worked around them.

Enabling HA
-----------

Before HA can be enabled the admin must take care to configure the
environment properly. In particular:

- NIC bonds should be available for network heartbeats;
- multipath should be configured for the storage heartbeats;
- all hosts should be online and fully-booted.

Xapi will create a raw disk in a shared SR for use by the storage
heartbeats and the master will tell every host in the pool to write
an identical xhad.conf file. Control jumps to the same routine that
is used to handle host startup:

Starting up a host
------------------

![Starting up a host](HA.start.svg)

First Xapi starts up the xhad via the ```ha_start_daemon``` script. The
daemons read their config files and start exchanging heartbeats over
the network and storage. All hosts must be online and all heartbeats must
be working for HA to be enabled -- it is not sensible to enable HA when
there are already failures in the pool. Assuming the host manages to
join the liveset then it clears the "excluded" flag which would have
been set if the host had been shutdown cleanly before -- this is only
needed when a host is shutdown cleanly and then restarted.

Xapi periodically queries the state of xhad via the ```ha_query_liveset```
command. The state will be ```Starting``` until the liveset is fully
formed at which point the state will be ```Online```.

When the ```ha_start_daemon``` script returns then Xapi will decide
whether to stand for master election or not. Initially when HA is being
enabled and there is a master already, this node will be expected to
stand unopposed. Later when HA notices that the master host has been
fenced, all remaining hosts will stand for election and one of them will
be chosen.

Shutting down a host
--------------------

![Shutting down a host](HA.shutdown.svg)

When a host is to be shutdown cleanly, it can be safely "excluded"
from the pool such that a future failure of the storage heartbeat will
not cause all pool hosts to self-fence (see survival rule 2 above).
When a host is "excluded" all other hosts know that the host does not
consider itself a master and has no resources locked i.e. no VMs are
running on it. An excluded host will never allow itself to form part
of a "split brain".

Once a host has given up its master role and shutdown any VMs, it is safe
to disable fencing with ```ha_disarm_fencing``` and stop xhad with
```ha_stop_daemon```. Once the daemon has been stopped the "excluded"
bit can be set in the statefile via ```ha_set_excluded``` and the
host safely rebooted.

Disabling HA cleanly
--------------------

![Disabling HA cleanly](HA.disable.clean.svg)

HA can be shutdown cleanly when the statefile is working i.e. when hosts
are alive because of survival rule 1. First the master Xapi tells the local
Xhad to mark the pool state as "invalid" using ```ha_set_pool_state```.
Every xhad instance will notice this state change the next time it performs
a storage heartbeat. The Xhad instances will shutdown and Xapi will notice
that HA has been disabled the next time it attempts to query the liveset.

If a host loses access to the statefile (or if none of the hosts have
access to the statefile) then HA can be disabled uncleanly.

Disabling HA uncleanly
----------------------

![Disabling HA uncleanly](HA.disable.unclean.svg)

HA should always be disabled cleanly when possible. If the storage has
failed and can't be easily repaired, then HA can be disabled manually
on every host. Since all hosts are online thanks to survival rule 2,
the Xapi master is able to tell all Xapi instances to disable their
recovery logic. Once the Xapis have been disabled -- and there is no
possibility of split brain -- each host is asked to disable the watchdog
with ```ha_disarm_fencing``` and then to stop Xhad with ```ha_stop_daemon```.

Add a host to the pool
----------------------

We assume that adding a host to the pool is an operation the admin will
perform manually, so it is acceptable to disable HA for the duration
and to re-enable it afterwards. If a failure happens during this operation
then the admin will take care of it by hand.

