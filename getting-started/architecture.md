---
title: Architecture
layout: default
---

The Xapi toolstack manages a cluster of hosts, network switches and storage
on behalf of clients such as
[XenCenter](https://github.com/xenserver/xenadmin),
[Xen Orchestra](https://xen-orchestra.com),
[OpenStack](http://www.openstack.org)
and [CloudStack](http://cloudstack.apache.org).

The most fundamental concept is of a *Resource pool*: the whole cluster
managed as a single entity. The following diagram shows a cluster of hosts
running xapi, all sharing some storage:

![A Resource Pool](pool.png)

At any time, at most one host is known as the *pool master* and is responsible
for co-ordination and locking resources within the pool. When a pool is
first created a master host is chosen. The master role can be transferred

- on user request in an orderly fashion (`xe pool-designate-new-master`)
- on user request in an emergency (`xe pool-emergency-transition-to-master`)
- automatically if HA is enabled on the cluster.

All hosts expose an HTTP and XML/RPC interface running on port 80 and with TLS/SSL
on port 443, but control operations will only be processed on the master host.
Attempts to send a control operation to another host will result in a XenAPI
redirect error message. For efficiency the following operations are permitted
on non-master hosts:

- querying performance counters (and their history)
- connecting to VNC consoles
- import/export (particularly when disks are on local storage)

Since the master host acts as co-ordinator and lock manager, the other hosts
will often talk to the master. Non-master hosts will also talk to each other
(over the same HTTP and XMLRPC channels) to

- transfer VM memory images (*VM migration*)
- mirror disks (*storage migration*)

Note that some types of shared storage (in particular all those using vhd)
require co-ordination for disk GC and coalesce. This co-ordination is currently
done by xapi and hence it is not possible to share this kind of storage between
resource pools.

The following diagram shows the software running on a single host. Note that
all hosts run the same software (although not necessarily the same version,
  if we are in the middle of a rolling upgrade).

![A Host](host.png)

The xapi toolstack expects the host to be running Xen 4.4 or later, on either
x86 or ARM. The Xen hypervisor partitions the host into *Domains*, some of
which can have privileged hardware access, and the rest are unprivileged guests.
The xapi toolstack normally runs all of its components in the privileged
initial domain, Domain 0, also known as "the control domain". However there is
experimental code which supports "driver domains" allowing storage and networking
drivers to be isolated in their own domains.

The toolstack consists of a set of co-operating daemons, building on top of the
basic set common to all Xen hosts. We have:

- [Xapi](https://github.com/xapi-project/xen-api): manages
  clusters of hosts, co-ordinating access to shared storage and networking.
- [Xenopsd](https://github.com/xapi-project/xenopsd): a low-level
  "domain manager" which takes care of creating, suspending, resuming, migrating,
  rebooting domains by interacting with Xen via libxc and libxl.
- [Xcp-rrdd](https://github.com/xapi-project/xcp-rrdd): a
  performance counter monitoring daemon which aggregates "datasources" defined
  via a plugin API and records history for each.
- [Xcp-networkd](https://github.com/xapi-project/xcp-networkd):
  a host network manager which takes care of configuring interfaces, bridges
  and OpenVSwitch instances
- [SM](https://github.com/xapi-project/sm): Storage Manager
  plugins which connect Xapi's internal storage interfaces to the control
  APIs of external storage systems.
- *perfmon*: a daemon which monitors performance counters and sends "alerts"
  if values exceed some pre-defined threshold
- *mpathalert*: a daemon which monitors "storage paths" and sends "alerts"
  if paths fail and need repair
- *snapwatchd*: a daemon which responds to snapshot requests sent via an in-guest
  VSS agent (for Windows).
- *stunnel*: a daemon which decodes TLS/SSL and forwards traffic to xapi.
- *xenconsoled*: allows access to guest consoles. This is common to all Xen
  hosts
- *xenstored*: a key-value pair configuration database for connecting VM
  disks and network interfaces. This is also common to all hosts

All inter-daemon control within domain 0 takes place over named Unix domain sockets
using a combination of json RPC and the XenAPI. Communication between Xen domains
uses shared memory (via grant mapping or grant copy) and event-channels, all
configured by parameters written to Xenstore.
