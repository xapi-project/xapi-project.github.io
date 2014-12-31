---
title: thin LVHD storage
layout: default
design_doc: true
revision: 1
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
  in the common-case; in particular there is no network RPC in the
  common-case
- when the resource pool master host has failed, allocations can still
  continue, up to some limit, allowing time for the master host to be
  recovered; in particular there is no need for very low HA timeouts.
- we can (in future) support in-kernel block allocation through the
  device mapper dm-thin target.

![Architecture](thin-lvhd.png)

