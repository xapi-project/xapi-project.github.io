---
title: thin LVHD storage
layout: default
design_doc: true
revision: 2
status: proposed
---

LVHD is a block-based storage system built on top of Xapi and LVM. LVHD
disks are represented as LVM LVs with vhd-format data inside. When a
disk is snapshotted, the LVM LV is "deflated" to the minimum-possible
size, just big enough to store the current vhd data. All other disks are
stored "inflated" i.e. consuming the maximum amount of storage space.
This proposal describes how we could add dynamic thin-provisioning to
LVHD such that

- disks only consume the space they need (plus an adjustable small
  overhead)
- when a disk needs more space, the allocation can be done *locally*
  in the common-case; in particular there is no network RPC needed
- when the resource pool master host has failed, allocations can still
  continue, up to some limit, allowing time for the master host to be
  recovered; in particular there is no need for very low HA timeouts.
- we can (in future) support in-kernel block allocation through the
  device mapper dm-thin target.

The following diagram shows the "Allocation plane":

![Allocation plane](allocation-plane.png)

All VM disk writes are channelled through `tapdisk` which keeps track
of the remaining reserved space within the device mapper device. When
the free space drops below a "low-water mark", tapdisk sends a message
to a local per-SR daemon called `local-allocator` and requests more
space.

The `local-allocator` maintains a free pool of blocks available for
allocation locally (hence the name). It will pick some blocks and
transactionally send the update to the `xenvmd` process running
on the SRmaster via the shared ring (labelled `ToLVM queue` in the diagram)
and update the device mapper tables locally.

There is one `xenvmd` process per SR on the SRmaster. `xenvmd` receives
local allocations from all the host shared rings (labelled `ToLVM queue`
in the diagram) and combines them together, appending them to a redo-log
also on shared storage. When `xenvmd` notices that a host's free space
(represented in the metadata as another LV) is low it allocates new free blocks
and pushes these to the host via another shared ring (labaelled `FromLVM queue`
in the diagram).

The `xenvmd` process maintains a cache of the current VG metadata for
fast query and update. All updates are appended to the redo-log to ensure
they operate in O(1) time. The redo log updates are periodically flushed
to the primary LVM metadata.

Note on running out of blocks
-----------------------------

Note that, while the host has plenty of free blocks, local allocations should
be fast. If the master fails and the local free pool starts running out
and `tapdisk` asks for more blocks, then the local allocator won't be able
to provide them.
`tapdisk` should start to slow
I/O in order to provide the local allocator more time.
Eventually if ```tapdisk``` runs
out of space before the local allocator can satisfy the request then
guest I/O will block. Note Windows VMs will start to crash if guest
I/O blocks for more than 70s. Linux VMs, no matter PV or HVM, may suffer
from "block for more than 120 seconds" issue due to slow I/O. This
known issue is that, slow I/O during dirty pages writeback/flush may
cause memory starvation, then other userland process or kernel threads
would be blocked.

The following diagram shows the Control-plane:

![Control plane](control-plane.png)

When thin-provisioning is enabled we will be modifying the LVM metadata at
an increased rate. We will cache the current metadata in the `xenvmd` process
and funnel all queries through it, rather than "peeking" at the metadata
on-disk. Note it will still be possible to peek at the on-disk metadata but it
will be out-of-date. It can still be used to query the PV state of the volume
group.

The `xenvm` CLI uses a simple
RPC interface to query the `xenvmd` process, tunnelled through `xapi` over
the management network. The RPC interface can be used for

- activating volumes locally: `xenvm` will query the LV segments and program
  device mapper
- deactivating volumes locally
- listing LVs, PVs etc

When the SM backend wishes to query or update volume group metadata it should use the
`xenvm` CLI while thin-provisioning is enabled.

The `xenvmd` process shall use a redo-log to ensure that metadata updates are
persisted in constant time and flushed lazily to the regular metadata area.

Components: roles and responsibilities
======================================

`xenvmd`:

- one per plugged SRmaster PBD
- owns the LVM metadata
- provides a fast query/update API so we can (for example) create lots of LVs very fast
- allocates free blocks to hosts when they are running low
- receives block allocations from hosts and incorporates them in the LVM metadata
- can safely flush all updates and downgrade to regular LVM

`xenvm`:

- a CLI which talks the `xenvmd` protocol to query / update LVs
- can be run on any host, calls are forwarded by `xapi`
- can "format" a LUN to prepare it for `xenvmd`
- can "upgrade" a LUN to prepare it for `xenvmd`

`local_allocator`:

- one per plugged PBD
- exposes a simple interface to `tapdisk` for requesting more space
- receives free block allocations via a queue on the shared disk from `xenvmd`
- sends block allocations to `xenvmd` and updates the device mapper target locally

`tapdisk`:

- monitors the free space inside LVs and requests more space when running out
- slows down I/O when nearly out of space

`xapi`:

- provides authenticated communication tunnels

`SM`:

- has an on/off switch for thin-provisioning
- can use either normal LVM or the `xenvm` CLI

Queues on the shared disk
=========================

The local allocator communicates with the remote allocator via a pair
of queues on the shared disk. Using the disk rather than the network means
that VMs will continue to run even if the management network is not working.
In particular

- if the (management) network fails, VMs continue to run on SAN storage
- if a host changes IP address, nothing needs to be reconfigured
- if xapi fails, VMs continue to run.

Logical messages in the queues
------------------------------

The local allocator needs to tell the remote allocator which blocks have
been allocated to which guest LV. The remote allocator needs to tell the
local allocator which blocks have become free. Since we are based on
LVM, a "block" is an extent, and an "allocation" is a segment i.e. the
placing of a physical extent at a logical extent in the logical volume.

The local allocator needs to send a message with logical contents:

- `volume`: a human-readable name of the LV
- `segments`: a list of LVM segments which says
   "place physical extent x at logical extent y using a linear mapping".

Note this message is idempotent.

The remote allocator needs to send a message with logical contents:

- `extents`: a list of physical extents which are free for the host to use

Although
for internal housekeeping the remote allocator will want to assign these
physical extents to logical extents within the host's free LV, the local
allocator doesn't need to know the logical extents. It only needs to know
the set of blocks which it is free to allocate.

Starting up the local allocator
-------------------------------

What happens when a local allocator (re)starts, after a

- process crash, respawn
- host crash, reboot?

When the local-allocator starts up, there are 2 cases:

1. the host has just rebooted, there are no attached disks and no running VMs
2. the process has just crashed, there are attached disks and running VMs

Case 1 is uninteresting. In case 2 there may have been an allocation in
progress when the process crashed and this must be completed. Therefore
the operation is journalled in a local filesystem in a directory which
is deliberately deleted on host reboot (Case 1). The allocation operation
consists of:

1. `push`ing the allocation to the master
2. updating the device mapper

Note that both parts of the allocation operation are idempotent and hence
the whole operation is idempotent. The journalling will guarantee it executes
at-least-once.

When the local-allocator starts up it needs to discover the list of
free blocks. Rather than have 2 code paths, it's best to treat everything
as if it is a cold start (i.e. no local caches already populated) and to
ask the master to resync the free block list. The resync is performed by
executing a "suspend" and "resume" of the free block queue, and requiring
the remote allocator to:

- `pop` all block allocations and incorporate these updates
- send the complete set of free blocks "now" (i.e. while the queue is
  suspended) to the local allocator.

Starting the remote allocator
-----------------------------

The remote allocator needs to know

- the device containing the volume group
- the hosts to "connect" to via the shared queues

The device containing the volume group should be written to a config
file when the SR is plugged.

TODO: decide how we should maintain the list of hosts to connect to?
or should we reconnect to all hosts? We probably can discover the metadata
volumes by querying the VG.

Shutting down the local allocator
---------------------------------

The local allocator should be able to crash at any time and recover
afterwards. If the user requests a `PBD.unplug` we can perform a 
clean shutdown by:

- signalling the remote allocator to suspend the block allocation queue
- arranging for the local allocator to acknowledge the suspension and exit
- when the remote allocator sees the acknowlegement, we know that the
  local allocator is offline and it doesn't need to poll the queue any more

Shutting down the remote allocator
----------------------------------

Shutting down the remote allocator is really a "downgrade": when using
thin provisioning, the remote allocator should be running all the time.
To downgrade, we need to stop all hosts allocating and ensure all updates
are flushed to the global LVM metadata. The remote allocator can shutdown
by:

- shutting down all local allocators (see previous section)
- flushing all outstanding block allocations to the LVM redo log
- flushing the LVM redo log to the global LVM metadata

Queues as rings
---------------

We can use a simple ring protocol to represent the queues on the disk.
Each queue will have a single consumer and single producer and reside within
a single logical volume.

To make diagnostics simpler, we can require the ring to only support `push`
and `pop` of *whole* messages i.e. there can be no partial reads or partial
writes. This means that the `producer` and `consumer` pointers will always
point to valid message boundaries.

One possible format used by the [prototype](https://github.com/mirage/shared-block-ring/blob/master/lib/ring.ml) is as follows:

- sector 0: a magic string
- sector 1: producer state
- sector 2: consumer state
- sector 3...: data

Within the producer state sector we can have:

- octets 0-7: producer offset: a little-endian 64-bit integer
- octet 8: 1 means "suspend acknowledged"; 0 otherwise

Within the consumer state sector we can have:

- octets 0-7: consumer offset: a little-endian 64-bit integer
- octet 8: 1 means "suspend requested"; 0 otherwise

The consumer and producer pointers point to message boundaries. Each
message is prefixed with a 4 byte length and padded to the next 4-byte
boundary.

To push a message onto the ring we need to

- check whether the message is too big to ever fit: this is a permanent
  error
- check whether the message is too big to fit given the current free
  space: this is a transient error
- write the message into the ring
- advance the producer pointer

To pop a message from the ring we need to

- check whether there is unconsumed space: if not this is a transient
  error
- read the message from the ring and process it
- advance the consumer pointer

Journals as queues
------------------

When we journal an operation we want to guarantee to execute it never
*or* at-least-once. We can re-use the queue implementation by `push`ing
a description of the work item to the queue and waiting for the
item to be `pop`ped, processed and finally consumed by advancing the
consumer pointer. The journal code needs to check for unconsumed data
during startup, and to process it before continuing.

Suspending and resuming queues
------------------------------

During startup (resync the free blocks) and shutdown (flush the allocations)
we need to suspend and resume queues. The ring protocol can be extended
to allow the *consumer* to suspend the ring by:

- the consumer asserts the "suspend requested" bit
- the producer `push` function checks the bit and writes "suspend acknowledged"
- the producer also periodically polls the queue state and writes
  "suspend acknowledged" (to catch the case where no items are to be pushed)
- after the producer has acknowledged it will guarantee to `push` no more
  items
- when the consumer polls the producer's state and spots the "suspend acknowledged",
  it concludes that the queue is now suspended.

The key detail is that the handshake on the ring causes the two sides
to synchronise and both agree that the ring is now suspended/ resumed.


Modelling the suspend/resume protocol
-------------------------------------

To check that the suspend/resume protocol works well enough to be used
to resynchronise the free blocks list on a slave, a simple
[promela model](queue.pml) was created. We model the queue state as
2 boolean flags:

```
bool suspend /* suspend requested */
bool suspend_ack /* suspend acknowledged *./
```

and an abstract representation of the data within the ring:

```
/* the queue may have no data (none); a delta or a full sync.
   the full sync is performed immediately on resume. */
mtype = { sync delta none }
mtype inflight_data = none
```

There is a "producer" and a "consumer" process which run forever,
exchanging data and suspending and resuming whenever they want.
The special data item `sync` is only sent immediately after a resume
and we check that we never desynchronise with asserts:

```
  :: (inflight_data != none) ->
    /* In steady state we receive deltas */
    assert (suspend_ack == false);
    assert (inflight_data == delta);
    inflight_data = none
```
i.e. when we are receiving data normally (outside of the suspend/resume
code) we aren't suspended and we expect deltas, not full syncs.

The model-checker [spin](http://spinroot.com/spin/whatispin.html)
verifies this property holds.
Interaction with HA
===================

Consider what will happen if a host fails when HA is disabled:

- if the host is a slave: the VMs running on the host will crash but
  no other host is affected.
- if the host is a master: allocation requests from running VMs will
  continue provided enough free blocks are cached on the hosts. If a
  host eventually runs out of free blocks, then guest I/O will start to
  block and VMs may eventually crash.

Therefore we *recommend* that users enable HA and only disable it
for short periods of time. Note that, unlike other thin-provisioning
implementations, we will allow HA to be disabled.

Host-local LVs
==============

When a host calls SMAPI ```sr_attach```, it will tell `xenvmd` on the
SRmaster to connect to the local allocator on the host. The `xenvmd`
daemon will create the volumes for queues and a volume to represent the
"free blocks" which a host is allowed to allocate.

Monitoring
==========

The local allocator process should export RRD datasources over shared
memory named

- ```sr_<SR uuid>_<host uuid>_free```: the number of free blocks in
  the local cache. It's useful to look at this and verify that it doesn't
  usually hit zero, since that's when allocations will start to block.
  For this reason we should use the `MIN` consolidation function.
- ```sr_<SR uuid>_<host uuid>_requests```: a counter of the number
  of satisfied allocation requests. If this number is too high then the quantum
  of allocation should be increased. For this reason we should use the
  `MAX` consolidation function.
- ```sr_<SR uuid>_<host uuid>_allocations```: a counter of the number of
  bytes being allocated. If the allocation rate is too high compared with
  the number of free blocks divided by the HA timeout period then the
  `SRmaster-allocator` should be reconfigured to supply more blocks with the host.

Modifications to tapdisk
========================

TODO: to be updated by Germano

```tapdisk``` will be modified to

- on open: discover the current maximum size of the file/LV (for a file
  we assume there is no limit for now)
- read a low-water mark value from a config file ```/etc/tapdisk3.conf```
- read a very-low-water mark value from a config file ```/etc/tapdisk3.conf```
- read a Unix domain socket path from a config file ```/etc/tapdisk3.conf```
- when there is less free space available than the low-water mark: connect
  to Unix domain socket and write an "extend" request
- upon receiving the "extend" response, re-read the maximum size of the
  file/LV
- when there is less free space available than the very-low-water mark:
  start to slow I/O responses and write a single 'error' line to the log.

The extend request
------------------

TODO: to be updated by Germano

The request has the following format:

Octet offsets    | Name     | Description
-----------------|----------|------------
0,1              | tl       | Total length (including this field) of message (in network byte order)
2                | type     | The value '0' indicating an extend request
3                | nl       | The length of the LV name in octets, including NULL terminator
4,..,4+nl-1      | name     | The LV name
4+nl,..,12+nl-1  | vdi_size | The virtual size of the logical VDI (in network byte order)
12+nl,..,20+nl-1 | lv_size  | The current size of the LV (in network byte order)
20+nl,..,28+nl-1 | cur_size | The current size of the vhd metadata (in network byte order)

The extend response
-------------------

The response is a single byte value "0" which is a signal to re-examime
the LV size. The request will block indefinitely until it succeeds. The
request will block for a long time if

- the SR has genuinely run out of space. The admin should observe the
  existing free space graphs/alerts and perform an SR resize.
- the master has failed and HA is disabled. The admin should re-enable
  HA or fix the problem manually.

Shared-block-rings
==================

The `toLVM` and `fromLVM` queues will be implemented as rings over the shared
storage blocks, similar to the Xenstore and Console ring protocols over
shared memory. The ring will have the following format:

Sector | Name     | Description
-------|----------|----------------------
0      | magic    | Well-known magic string to identify an intact ring
1      | producer | Producer pointer (byte offset)
2      | consumer | Consumer pointer (byte offset)
3...   | data     | Arbitrary data

When data is to be written to the ring the updates are ordered:

1. the data is written to the data section
2. the producer pointer is incremented to "expose" the data to the consumer

When data is to be read from the ring the updates are similarly ordered:

1. the data is read from the data section and processed
2. when the side-effects are fully persisted, the consumer pointer is incremented

The ring implementation will expect the ring data size to be always larger than
any individual write.

Example ring implementation: [shared-block-ring](https://github.com/mirage/shared-block-ring).

The local-allocator
===================

There is one `local-allocator` process per attached SR. The process will be
spawned by the SM ```sr_attach``` call, and sent a shutdown message from
the ```sr_detach``` call.

The `local-allocator` accepts command-line arguments:

```
thin-lvhd-local-allocator     \
  --config <path>             \
  --socket <path>             \
  --journal <path>            \
  --freePool <path>           \
  --fromLVM <path>            \
  --toLVM <path>
```
where

- `--config` names the config file
- `--socket` names the Unix domain socket used for receiving allocation requests
from `tapdisk3`
- `--journal` names the host local journal which is used to cope with daemon crashes
- `--freePool` names the device-mapper device containing the blocks free for
local allocation
- `--fromLVM` names the device containing new free block allocations from
the host which controls the LVM metadata
- `--toLVM` names the device containing the local allocations which should be
replayed against the LVM metadata

The `local-allocator` also reads a config file containing:

```
# global section

# amount to provide to an LV when requested
vdi-allocation-quantum=100M
```

When the `local-allocator` process starts up it will read the host local
journal and

- re-execute any pending allocation requests from tapdisk
- compute the lowest still-free block in the local free block device for
future allocations

The procedure for handling an allocation request from tapdisk is:

1. if there aren't enough free blocks in the free pool, wait polling the
   `fromLVM` queue
2. choose a range of blocks to assign to the tapdisk LV from the free LV
3. write the operation (i.e. exactly what we are about to do) to the journal.
   This ensures that it will be repeated if the allocator crashes and restarts.
   Note that, since the operation may be repeated multiple times, it must be
   idempotent.
5. push the block assignment to the `toLVM` queue
6. suspend the device mapper device
7. add/modify the device mapper target
8. resume the device mapper device
9. remove the operation from the local journal (i.e. there's no need to repeat
   it now)
10. reply to tapdisk

The shutdown request
--------------------

The shutdown request has the following format:

Octet offsets | Name     | Description
--------------|----------|------------
0,1           | tl       | Total length (including this field) of message (in network byte order)
2             | type     | The value '1' indicating a shutdown request

There is no response to the shutdown request. The `local-allocator` will
terminate as soon as it is able.

The SRmaster-allocator
======================

The `SRmaster-allocator` is a daemon run on the SRmaster node, started in
`sr_attach` and shutdown in `sr_detach`.

The `SRmaster-allocator` accepts command-line arguments:

```
SRmaster-allocator          \
--config <path>             \
--journal <path>
```
where

- `--config` names the config file
- `--journal` names the host local journal which is used to cope with daemon crashes

The config file contains the paths for all the control volumes and global
configuration,
for example

```
# global section
host-allocation-quantum=1G

[host1]
to-LVM=<path>
from-LVM=<path>

[host2]
to-LVM=<path>
from-LVM=<path>
```

The `SRmaster-allocator` continually

- peeks at updates from all the `to-LVM` queues
- calculates how much free space each host still has
- if the free space for a host drops below some threshold:
  - choose some free blocks
- writes the change it is going to make to the local journal
- pops the updates from the `to-LVM` queues
- pushes the updates to the `from-LVM` queues
- rewrites the LVM metadata
- removes the change from the local journal

The membership monitor
======================

The role of the membership monitor is to

- destroy a host's local LVs when it has left the pool and the `toLVM` queue
  has been flushed
- rewrite the `SRmaster-allocator` config file when hosts have joined or left
  the pool

We shall

- install a ```host-pre-declare-dead``` script to wait for the `SRmaster-allocator`
  to flush the `toLVM` queue (i.e. when `peek` returns 0 elements) and delete
  the LV
- modify XenAPI ```Host.declare_dead``` to call ```host-pre-declare-dead``` before
  the VMs are unlocked
- add a ```host-pre-forget``` hook type which will be called just before a Host
  is forgotten
- install a ```host-pre-forget``` script to destroy the host's local LVs

Modifications to LVHD SR
========================

- `sr_attach` should:
  - if an SRmaster, update the `MGT` major version number to prevent
  - if an SRmaster, spawn `SRmaster-allocator`
  - if the `toLVM`, `fromLVM`, free block LVs don't exist then create them
  - spawn `local-allocator`
- `sr_detach` should:
  - shut down the `local-allocator`
  - if an SRmaster, shut down the `SRmaster-allocator`
- `vdi_deactivate` should:
  - run a plugin on the SRmaster to wait for all already-generated LVM updates
    to be flushed to the LVM metadata
- `vdi_activate` should:
  - if necessary, run a plugin on the SRmaster to deflate the LV to the new
    minimum size (+ some slack),

Note that it is possible to attach and detach the individual hosts in any order
but when the SRmaster is unplugged then there will be no "refilling" of the host
local free LVs; it will behave as if the master host has failed.

Enabling thin provisioning
==========================

Thin provisioning will be automatically enabled on upgrade. When the SRmaster
plugs in `PBD` the `MGT` major version number will be bumped to prevent old
hosts from plugging in the SR and getting confused. When any host plugs in a
`PBD` it will create the necessary metadata volumes.
When a VDI is activated, it will be deflated to the new low size.

Disabling thin provisioning
===========================

We shall make a tool which will

- allow someone to downgrade their pool after enabling thin provisioning
- allow developers to test the upgrade logic without fully downgrading their
  hosts

The tool will

- check if there is enough space to fully inflate all non-snapshot leaves
- unplug all the non-SRmaster `PBD`s
- unplug the SRmaster `PBD`. As a side-effect all pending LVM updates will be
  written to the LVM metadata.
- modify the `MGT` volume to have the lower metadata version
- fully inflate all non-snapshot leaves

Walk-through: upgrade
=====================

Rolling upgrade should work in the usual way. As soon as the pool master has been
upgraded, hosts will be able to use thin provisioning when new VDIs are attached.
A VM suspend/resume/reboot or migrate will be needed to turn on thin provisioning
for existing running VMs.

Walk-through: downgrade
=======================

A pool may be safely downgraded to a previous version without thin provisioning
provided that the downgrade tool is run. If the tool hasn't run then the old
pool will refuse to attach the SR because the metadata has been upgraded.

Walk-through: after a host failure
==================================

If HA is enabled:

- ```xhad``` elects a new master if necessary
- the ```xhad``` tells ```Xapi``` which hosts are alive and which have failed.
- ```Xapi``` runs the ```host-pre-declare-dead``` scripts for every failed host
- the ```host-pre-declare-dead``` wait for the `toLVM` operations to be replayed
  against the LVM metadata on the SRmaster
- ```Xapi``` unlocks the VMs and restarts them on new hosts.

If HA is not enabled:

- the admin must tell ```Xapi``` which hosts have failed with ```xe host-declare-dead```
- ```Xapi``` runs the ```host-pre-declare-dead``` scripts for every failed host
- the ```host-pre-declare-dead``` wait for the `toLVM` operations to be replayed
against the LVM metadata on the SRmaster
- ```Xapi``` unlocks the VMs
- the admin may now restart the VMs on new hosts.

Future use of dm-thin?
======================

Dm-thin also uses 2 local LVs: one for the "thin pool" and one for the metadata.
After replaying our journal we could potentially delete our host local LVs and
switch over to dm-thin.

Summary of the impact on the admin
==================================

- If the VM workload performs a lot of disk allocation, then the admin *should*
  enable HA.
- The admin *must* not downgrade the pool without first cleanly detaching the
  storage.
- Extra metadata is needed to track thin provisioing, reducing the amount of
  space available for user volumes.
- If an SR is completely full then it will not be possible to enable thin
  provisioning.
