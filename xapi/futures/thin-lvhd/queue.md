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
