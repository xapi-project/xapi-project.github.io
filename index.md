---
layout: default
title: Welcome
---

## The [xapi toolstack](http://www.xenproject.org/developers/teams/xapi.html)

- manages clusters of Xen hosts with shared storage and networking
- allows running VMs to be migrated between hosts (with or without storage)
  with minimal downtime
- automatically restarts VMs after host failure
  ([High Availability](features/HA/HA.html))
- allows cross-site [Disaster Recovery](features/DR/DR.html)
- simplifies maintenance through [Rolling Pool Upgrade](features/RPU/RPU.html)
- collects performance statistics for historical analysis and for alerting
- has a full-featured
  [XML-RPC based API](xen-api/index.html),
  used by clients such as
  [XenCenter](https://github.com/xenserver/xenadmin),
  [Xen Orchestra](https://xen-orchestra.com),
  [OpenStack](http://www.openstack.org)
  and [CloudStack](http://cloudstack.apache.org)

The xapi toolstack is developed by the
[xapi project](http://www.xenproject.org/developers/teams/xapi.html):
a sub-project of the Linux Foundation Xen Project.

## Getting the Xapi toolstack

The easiest way to use it is to install
[Citrix Hypervisor Express Edition](https://www.citrix.com/en-gb/downloads/citrix-hypervisor/)
or [XCP-ng](https://xcp-ng.org/#easy-to-install).

Otherwise, you can

- follow the [build instructions](https://github.com/xenserver/buildroot)
- try experimental [ARM packages](http://wiki.xenproject.org/wiki/Running_XCP/xapi_on_ARM)

## Members of the XAPI security team

* [Rob Hoes](https://github.com/robhoes) [@xenserver](https://github.com/xenserver)
* [Pau Ruiz Safont](https://github.com/psafont) [@xcp-ng](https://github.com/xcp-ng)

The preferred way to report security issues is to follow the [usual process for Xen](https://xenproject.org/about/security-policy/)

## Get in touch

You're welcome to

- checkout the [code on github](https://github.com/xapi-project/)
