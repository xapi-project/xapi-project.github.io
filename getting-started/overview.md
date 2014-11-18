---
layout: default
title: Overview
---

## The [xapi toolstack](http://www.xenproject.org/developers/teams/xapi.html)

- manages clusters of Xen hosts as single entities
- allows running VMs to be migrated between hosts (including with storage)
  with minimal downtime
- automatically restarts VMs after host failure ("High Availability")
- facilitates disaster recovery cross-site
- simplifies maintainence through rolling pool upgrade
- collects performance statistics for historical analysis and for alerting
- has a full-featured XML-RPC based API, used by clients such as
  [XenCenter](https://github.com/xenserver/xenadmin),
  [Xen Orchestra](https://xen-orchestra.com),
  [OpenStack](http://www.openstack.org)
  and [CloudStack](http://cloudstack.apache.org)

The xapi toolstack is developed by the
[xapi project](http://www.xenproject.org/developers/teams/xapi.html):
a sub-project of the Linux Foundation Xen Project.

## Components

- [Xapi](https://github.com/xapi-project/xen-api): manages a cluster
  of Xen hosts, co-ordinating access to network and storage.
- [Xenopsd](https://github.com/xapi-project/xenopsd): a low-level
  "domain manager" which takes care of creating, suspending, resuming, migrating,
  rebooting domains by interacting with Xen via libxc and libxl.
- [Xcp-rrdd](https://github.com/xapi-project/xcp-rrdd): a
  performance counter monitoring daemon which aggregates "datasources" defined
  via a plugin API and records history for each.
- [Xcp-networkd](https://github.com/xapi-project/xcp-networkd):
  a host network manager which takes care of configuring interfaces, bridges
  and OpenVSwitch instances
- [Squeezed](https://github.com/xapi-project/squeezed): a single
  host ballooning daemon which "balances" memory between running VMs.
- [SM](https://github.com/xapi-project/sm): Storage Manager
  plugins which connect Xapi's internal storage interfaces to the control
  APIs of external storage systems.
