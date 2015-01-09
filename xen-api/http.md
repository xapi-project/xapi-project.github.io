---
title: Using HTTP to interact with XenServer
layout: default
---

XenServer exposes an HTTP interface on each host, that can be used
to perform various operations. This chapter describes the available
mechanisms.


Getting XenServer Performance Statistics
---------------------------------------------

XenServer records statistics about the performance of various
aspects of your XenServer installation. The metrics are stored
persistently for long term access and analysis of historical trends.
Where storage is available to a VM, the statistics are written to disk
when a VM is shut down. Statistics are stored in RRDs (Round Robin
Databases), which are maintained for individual VMs (including the
control domain) and the server. RRDs are resident on the server on which
the VM is running, or the pool master when the VM is not running. The
RRDs are also backed up every day.

> **Warning**
>
> In earlier versions of the XenServer API, instantaneous
> performance metrics could be obtained using the `VM_metrics`,
> `VM_guest_metrics`, `host_metrics` methods and associated methods.
> These methods has been deprecated in favor of using the http handler
> described in this chapter to download the statistics from the RRDs on
> the VMs and servers. Note that by default the legacy metrics will
> return zeroes. To revert to periodic statistical polling as present in
> earlier versions of XenServer, set the
> `other-config:rrd_update_interval=` parameters on your host to one of
> the following values, and restart your host:
>
> never
> :   This is the default, meaning no periodic polling is performed.
>
> 1
> :   Polling is performed every 5 seconds.
>
> 2
> :   Polling is performed every minute.
>
> By default, the older metrics APIs will not return any values, and so
> this key must be enabled to run monitoring clients which use the
> legacy monitoring protocol.

Statistics are persisted for a maximum of one year, and are stored at
different granularities. The average and most recent values are stored
at intervals of:

-   5 seconds for the past 10 minutes

-   one minute for the past 2 hours

-   one hour for the past week

-   one day for the past year

RRDs are saved to disk as uncompressed XML. The size of each RRD when
written to disk ranges from 200KiB to approximately 1.2MiB when the RRD
stores the full year of statistics.

> **Warning**
>
> If statistics cannot be written to disk, for example when a disk is
> full, statistics will be lost and the last saved version of the RRD
> will be used.

Statistics can be downloaded over HTTP in XML format, for example using
`wget`. See [](http://oss.oetiker.ch/rrdtool/doc/rrddump.en.html) and
[](http://oss.oetiker.ch/rrdtool/doc/rrdxport.en.html) for information
about the XML format. HTTP authentication can take the form of a
username and password or a session token. Parameters are appended to the
URL following a question mark (?) and separated by ampersands (&).

To obtain an update of all VM statistics on a host, the URL would be of
the form:

    http://:@/rrd_updates?start=

This request returns data in an rrdtool `xport` style XML format, for
every VM resident on the particular host that is being queried. To
differentiate which column in the export is associated with which VM,
the `legend` field is prefixed with the UUID of the VM.

To obtain host updates too, use the query parameter `host=true`:

    http://:@/rrd_updates?start=&host=true

The step will decrease as the period decreases, which means that if you
request statistics for a shorter time period you will get more detailed
statistics.

**Additional rrd\_updates parameters**

cf=ave|min|max
:   the data consolidation mode

interval=interval
:   the interval between values to be reported

> **Note**
>
> By default only `ave` statistics are available. To obtain `min` and
> `max` statistics for a VM, run the following command:
>
>     xe pool-param-set uuid= other-config:create_min_max_in_new_VM_RRDs

To obtain all statistics for a host:

    http:///host_rrd

To obtain all statistics for a VM:

    http:///vm_rrd?uuid=
