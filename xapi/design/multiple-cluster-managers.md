---
title: multiple cluster managers
layout: default
design_doc: true
revision: 1
status: proposed
---

Xapi currently uses a cluster manager called
[xhad](../../features/HA/HA.html). Sometimes other software comes with its own
built-in way of managing clusters, which would clash with xhad (example:
xhad could choose to fence node 'a' while the other system could fence node
'b' resulting in a total failure). To integrate xapi with this other software
we have 2 choices:

1. modify the other software to take membership information from xapi; or
2. modify xapi to take membership information from this other software.

This document proposes a way to modify xapi to take membership information from
external software.

API changes
===========

- New RO field `Pool.ha_cluster_stack` of type string which will be set to 'xhad'
  on upgrade.
- New parameter to `Pool.enable_ha` called `cluster_stack` of type string which
  will have the default value of empty string (meaning: let the implementation
	choose).

Since other software will require specific `cluster_stack` settings we will
define new exceptions:

- `UNKNOWN_CLUSTER_STACK`: the operation cannot be performed because the
  requested cluster stack does not exist. The user should check the
	type was entered correctly and, failing that, check to see if the software
	is installed. The exception will have a single parameter: the name of the
	cluster stack which was not found.
- `INCOMPATIBLE_CLUSTER_STACK_ACTIVE`: the operation cannot be performed because an
  incompatible cluster stack is active. The single parameter will be the name
	of the required cluster stack. This could happen (or example) if you tried to
	create an OCFS2 SR with XenServer HA already enabled.
- `CLUSTER_STACK_CONSTRAINT`: HA cannot be enabled with the provided cluster
  stack because some third-party software is already active which requires
	a different cluster stack setting. The two parameters are: a reference to
	an object (such as an SR) which has created the restriction, and the name
	of the cluster stack that this object requires.

Implementation
==============

The `xapi.conf` file will have a new field: `cluster-stack-root` which will
have the default value `/usr/libexec/xapi/cluster-stack`. The existing `xhad`
scripts and tools will be moved to `/usr/libexec/xapi/cluster-stack/xhad/`.
A hypothetical cluster stack called `foo` would be placed in
`/usr/libexec/xapi/cluster-stack/foo/`.

In `Pool.enable_ha` with `cluster_stack="foo"` we will verify that the
subdirectory `<cluster-stack-root>/foo` exists. If it does not exist, then
the call will fail with `UNKNOWN_CLUSTER_STACK`.

Alternative cluster stacks will need to conform to the exact same interface
as [xhad](../../features/HA/HA.md).
