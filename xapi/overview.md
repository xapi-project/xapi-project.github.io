---
title: Xapi Overview
layout: default
---
Xapi is the [xapi-project](http://github.com/xapi-project) host and cluster manager.
Xapi is responsible for

- aggregating hosts into a single entity (a "resource pool")
- allocating VMs to hosts
- managing shared storage
- recoverying from host failure ("High-Availability")
- preparing for site failure ("Disaster Recovery")
- providing the XenAPI XMLRPC interface
- upgrading pools
- hotfixing hosts
- reporting bugs
- etc

## Principles

1. The XenAPI interface must remain backwards compatible, allowing older
   clients to continue working
2. Xapi delegates all Xenstore/libxc/libxl access to Xenopsd, so Xapi could
   be run in an unprivileged helper domain
3. Xapi delegates the low-level storage manipulation to SM plugins.
