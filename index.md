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
- simplifies maintainence through [Rolling Pool Upgrade](features/RPU/RPU.html)
- collects performance statistics for historical analysis and for alerting
- has a full-featured
  [XML-RPC based API](http://xapi-project.github.io/xen-api/),
  used by clients such as
  [XenCenter](https://github.com/xenserver/xenadmin),
  [Xen Orchestra](https://xen-orchestra.com),
  [OpenStack](http://www.openstack.org)
  and [CloudStack](http://cloudstack.apache.org)

The xapi toolstack is developed by the
[xapi project](http://www.xenproject.org/developers/teams/xapi.html):
a sub-project of the Linux Foundation Xen Project.

## Getting the Xapi toolstack

The easiest way is to install
[open-source XenServer](http://www.xenserver.org/).

Otherwise, you can

- follow the [build instructions](https://github.com/xenserver/buildroot)
- try experimental [ARM packages](http://wiki.xenproject.org/wiki/Running_XCP/xapi_on_ARM)

## Get in touch

You're welcome to

- join the [xen-api](http://lists.xenproject.org/mailman/listinfo/xen-api)
  mailing list
- join the #xen-api channel on freenode
- checkout the [code on github](https://github.com/xapi-project/)
