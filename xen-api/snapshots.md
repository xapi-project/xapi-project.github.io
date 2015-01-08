---
title: Snapshots
layout: default
---

Snapshots represent the state of a VM, or a disk (VDI) at a point in time.
They can be used for:

- backups (hourly, daily, weekly etc)
- experiments (take snapshot, try something, revert back again)
- golden images (install OS, get it just right, clone it 1000s of times)

Example: incremental backup with xe
===================================

For a VDI with uuid $VDI, take a snapshot:

```sh
FULL=$(xe vdi-snapshot uuid=$VDI)
```

Next perform a full backup into a file "full.vhd", in vhd format:

```sh
xe vdi-export uuid=$FULL filename=full.vhd format=vhd  --progress
```

If the SR was using the vhd format internally (this is the default)
then the full backup will be sparse and will only contain blocks if they
have been written to.

After some time has passed and the VDI has been written to, take another
snapshot:

```sh
DELTA=$(xe vdi-snapshot uuid=$VDI)
```

Now we can backup only the disk blocks which have changed between the original
snapshot $FULL and the next snapshot $DELTA into a file called "delta.vhd":

```sh
xe vdi-export uuid=$DELTA filename=delta.vhd format=vhd base=$FULL --progress
```

We now have 2 files on the local system:

- "full.vhd": a complete backup of the first snapshot
- "delta.vhd": an incremental backup of the second snapshot, relative to
  the first

For example:

```sh
test $ ls -lh *.vhd
-rw------- 1 dscott xendev 213M Aug 15 10:39 delta.vhd
-rw------- 1 dscott xendev 8.0G Aug 15 10:39 full.vhd
```

To restore the original snapshot you must create an empty disk with the
correct size. To find the size of a .vhd file use ```qemu-img``` as follows:

```sh
test $ qemu-img info delta.vhd
image: delta.vhd
file format: vpc
virtual size: 24G (25769705472 bytes)
disk size: 212M
```

Here the size is 25769705472 bytes.
Create a fresh VDI in SR $SR to restore the backup as follows:

```sh
SIZE=25769705472
RESTORE=$(xe vdi-create name-label=restored virtual-size=$SIZE sr-uuid=$SR type=user)
```

then import "full.vhd" into it:

```sh
xe vdi-import uuid=$RESTORE filename=full.vhd format=vhd --progress
```

Once "full.vhd" has been imported, the incremental backup can be restored
on top:

```sh
xe vdi-import uuid=$RESTORE filename=delta.vhd format=vhd --progress
```

Note there is no need to supply a "base" parameter when importing; Xapi will
treat the "vhd differencing disk" as a set of blocks and import them. It
is up to you to check you are importing them to the right place.

Now the VDI $RESTORE should have the same contents as $DELTA.

XenAPI
======

When integrating with Xapi from another tool it is easiest to use the
XenAPI directly rather than invoking the CLI.

Each of the ```xe``` commands above works by making an HTTP GET (for export)
or HTTP PUT (for import).

For import we send an HTTP 1.0 PUT request (Note with no transfer-encoding)
as follows:

```
PUT /import_raw_vdi?session_id=%s&task_id=%s&vdi=%s&format=%s HTTP/1.0\r\n
Connection: close\r\n
\r\n
\r\n
```

where

- ```session_id``` is a currently logged-in session
- ```task_id``` is a ```Task``` reference which will be used to monitor the
  progress of this task and receive errors from it
- ```vdi``` is the reference of the ```VDI``` into which the data will be
  imported
- ```format``` is either ```vhd``` or ```raw```

For export we send an HTTP 1.0 GET request as follows:

```
GET /export_raw_vdi?session_id=%s&task_id=%s&vdi=%s&format=%s[&base=%s] HTTP/1.0\r\n
Connection: close\r\n
\r\n
\r\n
```

where the common parameters have the same meaning as in the import case. The
new optional parameter has the following meaning:

- ```base``` is the reference of a ```VDI``` which has already been
  exported and this export should only contain the blocks which have changed
  since then.

To see the XenAPI in action, have a look at the
[example included in the xen-api tree](https://github.com/xapi-project/xen-api/blob/b07fd68347e53635d87f6ff0eac325337c123605/scripts/examples/python/exportimport.py#L24).
