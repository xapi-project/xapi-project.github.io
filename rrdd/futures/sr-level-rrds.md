---
title: SR-Level RRDs
layout: default
design_doc: true
revision: 5
status: confirmed
design_review: 139
revision_history:
- revision_number: 1
  description: Initial version
- revision_number: 2
  description: Added details about the VDI's binary format and size, and the SR capability name.
- revision_number: 3
  description: Tar was not needed after all!
- revision_number: 4
  description: Add details about discovering the VDI using a new vdi_type.
- revision_number: 5
  description: Add detauls about the http handlers and interaction with xapi's database
---

## Introduction

Xapi has RRDs to track VM- and host-level metrics. There is a desire to have SR-level RRDs as a new category, because SR stats are not specific to a certain VM or host. Examples are size and free space on the SR. While recording SR metrics is relatively straightforward within the current RRD system, the main question is where to archive them, which is what this design aims to address.

## Stats Collection

All SR types, including the existing ones, should be able to have RRDs defined for them. Some RRDs, such as a "free space" one, may make sense for multiple (if not all) SR types. However, the way to measure something like free space will be SR specific. Furthermore, it should be possible for each type of SR to have its own specialised RRDs.

It follows that each SR will need its own `xcp-rrdd` plugin, which runs on the SR master and defines and collects the stats. For the new thin-lvhd SR this could be `xenvmd` itself. The plugin registers itself with `xcp-rrdd`, so that the latter records the live stats from the plugin into RRDs.

## Archiving

SR-level RRDs will be archived in the SR itself, in a VDI, rather than in the local filesystem of the SR master. This way, we don't need to worry about master failover.

The VDI will be 4MB in size. This is a little more space than we would need for the RRDs we have in mind at the moment, but will give us enough headroom for the foreseeable future. It will not have a filesystem on it for simplicity and performance. There will only be one RRD archive file for each SR (possibly containing data for multiple metrics), which is gzipped by `xcp-rrdd`, and can be copied directly onto the VDI.

Xapi will be in charge of the lifecycle of this VDI, not the plugin or `xcp-rrdd`, which will make it a little easier to manage them. Only xapi will attach/detach and read from/write to this VDI. We will keep `xcp-rrdd` as simple as possible, and have it archive to its standard path in the local file system. Xapi will then copy the RRDs in and out of the VDI.

A new value `"rrd"` in the `vdi_type` enum of the datamodel will be defined, and the `VDI.type` of the VDI will be set to that value. The storage backend will write the VDI type to the LVM metadata of the VDI, so that xapi can discover the VDI containing the SR-level RRDs when attaching an SR to a new pool. This means that SR-level RRDs are currently restricted to LVM SRs.

Because we will not write plugins for all SRs at once, and therefore do not need xapi to set up the VDI for all SRs, we will add an SR "capability" for the backends to be able to tell xapi whether it has the ability to record stats and will need storage for them. The capability name will be: `SR_STATS`.

## Management of the SR-stats VDI

The SR-stats VDI will be attached/detached on `PBD.plug`/`unplug` on the SR master.

* On `PBD.plug` on the SR master, if the SR has the stats capability, xapi:
	* Creates a stats VDI if not already there (search for an existing one based on the VDI type).
	* Attaches the stats VDI if it did already exist, and copies the RRDs to the local file system (standard location in the filesystem; asks `xcp-rrdd` where to put them).
	* Informs `xcp-rrdd` about the RRDs so that it will load the RRDs and add newly recorded data to them (needs a function like `push_rrd_local` for VM-level RRDs).
	* Detaches stats VDI.
	
* On `PBD.unplug` on the SR master, if the SR has the stats capability xapi:
	* Tells `xcp-rrdd` to archive the RRDs for the SR, which it will do to the local filesystem.
	* Attaches the stats VDI, copies the RRDs into it, detaches VDI.
	
## Periodic Archiving
	
Xapi's periodic scheduler regularly triggers `xcp-rrdd` to archive the host and VM RRDs. It will need to do this for the SR ones as well. Furthermore, xapi will need to attach the stats VDI and copy the RRD archives into it (as on `PBD.unplug`).

## Exporting

There will be a new handler for downloading an SR RRD:

    http://<server>/sr_rrd?session_id=<SESSION HANDLE>&uuid=<SR UUID>

The rrd_updates handler will also be updated. Currently the URL looks
like this:

    http://<server>/rrd_updates?session_id=<SESSION HANDLE>&start=10258122541&host=true

This will be extended with a 'sr=true' parameter, which will cause
updates to be sent for the SR.

## Database updating.

If the SR is presenting a data source called 'physical_utilisation',
xapi will record this periodically in its database. In order to do
this, xapi will fork a thread that, every n minutes (2 suggested, but
open to suggestions here), will query the attached SRs, then query
RRDD for the latest data source for these, and update the database.

The utilisation of VDIs will _not_ be updated in this way until
scalability worries for RRDs are addressed.

Xapi will cache whether it is SR master for every attached SR and only
attempt to update if it is the SR master.

