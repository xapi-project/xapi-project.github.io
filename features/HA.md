---
title: High-Availability
layout: default
---

High-Availability tries to keep VMs running, even when there are hardware
failures in the resource pool. Imagine

- if someone unplugs a FC switch, VMs running on affected hosts will lose
  access to their storage;
- if a NIC fails: web-server VMs will be cut off from the Internet;
- if a host crashes: all VMs will have crashed too.

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
