---
title: VM import/export
layout: default
---

VMs can be exported to a file and later imported to any XenServer host. The export protocol is a simple HTTP(S) GET, which should be performed on the master if the VM is on a pool member. Authorization is either standard HTTP basic authentication, or if a session has already been obtained, this can be used. The VM to export is specified either by UUID or by reference. To keep track of the export, a task can be created and passed in using its reference. The request might result in a redirect if the VM's disks are only accessible on a pool member.

The following arguments are passed on the command line:

<table>
<col width="28%" />
<col width="68%" />
<thead>
<tr class="header">
<th align="left">Argument</th>
<th align="left">Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">session_id</td>
<td align="left">the reference of the session being used to authenticate; required only when not using HTTP basic authentication</td>
</tr>
<tr class="even">
<td align="left">task_id</td>
<td align="left">the reference of the task object with which to keep track of the operation; optional, required only if you have created a task object to keep track of the export</td>
</tr>
<tr class="odd">
<td align="left">ref</td>
<td align="left">the reference of the VM; required only if not using the UUID</td>
</tr>
<tr class="even">
<td align="left">uuid</td>
<td align="left">the UUID of the VM; required only if not using the reference</td>
</tr>
</tbody>
</table>

For example, using the Linux command line tool cURL:

curl http://root:foo@myxenserver1/export?uuid=<vm_uuid> -o <exportfile>

will export the specified VM to the file `exportfile`.

To export just the metadata, use the URI `http://server/export_metadata`.

The import protocol is similar, using HTTP(S) PUT. The `session_id` and `task_id` arguments are as for the export. The `ref` and `uuid` are not used; a new reference and uuid will be generated for the VM. There are some additional parameters:

<table>
<col width="28%" />
<col width="68%" />
<thead>
<tr class="header">
<th align="left">Argument</th>
<th align="left">Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">restore</td>
<td align="left">if <em>true</em>, the import is treated as replacing the original VM - the implication of this currently is that the MAC addresses on the VIFs are exactly as the export was, which will lead to conflicts if the original VM is still being run.</td>
</tr>
<tr class="even">
<td align="left">force</td>
<td align="left">if <em>true</em>, any checksum failures will be ignored (the default is to destroy the VM if a checksum error is detected)</td>
</tr>
<tr class="odd">
<td align="left">sr_id</td>
<td align="left">the reference of an SR into which the VM should be imported. The default behavior is to import into the <em>Pool.default_SR</em>.</td>
</tr>
</tbody>
</table>

For example, again using cURL:

curl -T <exportfile> http://root:foo@myxenserver2/import

will import the VM to the default SR on the server.

> **Note**
>
> Note that if no default SR has been set, and no sr\_uuid is specified, the error message "DEFAULT\_SR\_NOT\_FOUND" is returned.

Another example:

curl -T <exportfile> http://root:foo@myxenserver2/import?sr_id=<opaque_ref_of_sr>

will import the VM to the specified SR on the server.

To import just the metadata, use the URI `http://server/import_metadata`

### Xen Virtual Appliance (XVA) VM Import Format

XenServer supports a human-readable legacy VM input format called XVA. This section describes the syntax and structure of XVA.

An XVA consists of a directory containing XML metadata and a set of disk images. A VM represented by an XVA is not intended to be directly executable. Data within an XVA package is compressed and intended for either archiving on permanent storage or for being transmitted to a VM server - such as a XenServer host - where it can be decompressed and executed.

XVA is a hypervisor-neutral packaging format; it should be possible to create simple tools to instantiate an XVA VM on any other platform. XVA does not specify any particular runtime format; for example disks may be instantiated as file images, LVM volumes, QCoW images, VMDK or VHD images. An XVA VM may be instantiated any number of times, each instantiation may have a different runtime format.

XVA does not:

-   specify any particular serialization or transport format

-   provide any mechanism for customizing VMs (or templates) on install

-   address how a VM may be upgraded post-install

-   define how multiple VMs, acting as an appliance, may communicate

These issues are all addressed by the related Open Virtual Appliance specification.

An XVA is a directory containing, at a minimum, a file called `ova.xml`. This file describes the VM contained within the XVA and is described in Section 3.2. Disks are stored within sub-directories and are referenced from the ova.xml. The format of disk data is described later in Section 3.3.

The following terms will be used in the rest of the chapter:

-   HVM: a mode in which unmodified OS kernels run with the help of virtualization support in the hardware.

-   PV: a mode in which specially modified "paravirtualized" kernels run explicitly on top of a hypervisor without requiring hardware support for virtualization.

The "ova.xml" file contains the following elements:

<appliance version="0.1">

The number in the attribute "version" indicates the version of this specification to which the XVA is constructed; in this case version 0.1. Inside the \<appliance\> there is exactly one \<vm\>: (in the OVA specification, multiple \<vm\>s are permitted)

<vm name="name">

Each \<vm\> element describes one VM. The "name" attribute is for future internal use only and must be unique within the ova.xml file. The "name" attribute is permitted to be any valid UTF-8 string. Inside each \<vm\> tag are the following compulsory elements:

<label>... text ... </label>

A short name for the VM to be displayed in a UI.

<shortdesc> ... description ... </shortdesc>

A description for the VM to be displayed in the UI. Note that for both \<label\> and \<shortdesc\> contents, leading and trailing whitespace will be ignored.

<config mem_set="268435456" vcpus="1"/>

The `<config>` element has attributes which describe the amount of memory in bytes (mem\_set) and number of CPUs (VCPUs) the VM should have.

Each `<vm>` has zero or more \<vbd\> elements representing block devices which look like the following:

<vbd device="sda" function="root" mode="w" vdi="vdi_sda"/>

The attributes have the following meanings:

device  
name of the physical device to expose to the VM. For linux guests we use "sd[a-z]" and for windows guests we use "hd[a-d]".

function  
if marked as "root", this disk will be used to boot the guest. (NB this does not imply the existence of the Linux root i.e. / filesystem) Only one device should be marked as "root". See Section 3.4 describing VM booting. Any other string is ignored.

mode  
either "w" or "ro" if the device is to be read/write or read-only

vdi  
the name of the disk image (represented by a \<vdi\> element) to which this block device is connected

Each \<vm\> may have an optional \<hacks\> section like the following: \<hacks is\_hvm="false" kernel\_boot\_cmdline="root=/dev/sda1 ro"/\> The \<hacks\> element is present in the XVA files generated by XenServer but will be removed in future. The attribute "is\_hvm" is either "true" or "false", depending on whether the VM should be booted in HVM or not. The "kernel\_boot\_cmdline" contains additional kernel commandline arguments when booting a guest using pygrub.

In addition to a \<vm\> element, the \<appliance\> will contain zero or more \<vdi\> elements like the following:

<vdi name="vdi_sda" size="5368709120" source="file://sda"
type="dir-gzipped-chunks">

Each \<vdi\> corresponds to a disk image. The attributes have the following meanings:

-   name: name of the VDI, referenced by the vdi attribute of \<vbd\> elements. Any valid UTF-8 string is permitted.

-   size: size of the required image in bytes

-   source: a URI describing where to find the data for the image, only file:// URIs are currently permitted and must describe paths relative to the directory containing the ova.xml

-   type: describes the format of the disk data (see Section 3.3)

A single disk image encoding is specified in which has type "dir-gzipped-chunks": Each image is represented by a directory containing a sequence of files as follows:

-rw-r--r-- 1 dscott xendev 458286013    Sep 18 09:51 chunk000000000.gz
-rw-r--r-- 1 dscott xendev 422271283    Sep 18 09:52 chunk000000001.gz
-rw-r--r-- 1 dscott xendev 395914244    Sep 18 09:53 chunk000000002.gz
-rw-r--r-- 1 dscott xendev 9452401      Sep 18 09:53 chunk000000003.gz
-rw-r--r-- 1 dscott xendev 1096066      Sep 18 09:53 chunk000000004.gz
-rw-r--r-- 1 dscott xendev 971976       Sep 18 09:53 chunk000000005.gz
-rw-r--r-- 1 dscott xendev 971976       Sep 18 09:53 chunk000000006.gz
-rw-r--r-- 1 dscott xendev 971976       Sep 18 09:53 chunk000000007.gz
-rw-r--r-- 1 dscott xendev 573930       Sep 18 09:53 chunk000000008.gz

Each file (named "chunk-XXXXXXXXX.gz") is a gzipped file containing exactly 1e9 bytes (1GB, not 1GiB) of raw block data. The small size was chosen to be safely under the maximum file size limits of several filesystems. If the files are gunzipped and then concatenated together, the original image is recovered.

XenServer provides two mechanisms for booting a VM: (i) using a paravirtualized kernel extracted through pygrub; and (ii) using HVM. The current implementation uses the "is\_hvm" flag within the \<hacks\> section to decide which mechanism to use.

This rest of this section describes a very simple Debian VM packaged as an XVA. The VM has two disks, one with size 5120MiB and used for the root filesystem and used to boot the guest using pygrub and the other of size 512MiB which is used for swap. The VM has 512MiB of memory and uses one virtual CPU.

At the topmost level the simple Debian VM is represented by a single directory:

$ ls -l
total 4
drwxr-xr-x 3 dscott xendev 4096 Oct 24 09:42 very simple Debian VM

Inside the main XVA directory are two sub-directories - one per disk - and the single file: ova.xml:

$ ls -l very\ simple\ Debian\ VM/
total 8
-rw-r--r-- 1 dscott xendev 1016 Oct 24 09:42 ova.xml
drwxr-xr-x 2 dscott xendev 4096 Oct 24 09:42 sda
drwxr-xr-x 2 dscott xendev 4096 Oct 24 09:53 sdb

Inside each disk sub-directory are a set of files, each file contains 1GB of raw disk block data compressed using gzip:

$ ls -l very\ simple\ Debian\ VM/sda/
total 2053480
-rw-r--r-- 1 dscott xendev 202121645 Oct 24 09:43 chunk-000000000.gz
-rw-r--r-- 1 dscott xendev 332739042 Oct 24 09:45 chunk-000000001.gz
-rw-r--r-- 1 dscott xendev 401299288 Oct 24 09:48 chunk-000000002.gz
-rw-r--r-- 1 dscott xendev 389585534 Oct 24 09:50 chunk-000000003.gz
-rw-r--r-- 1 dscott xendev 624567877 Oct 24 09:53 chunk-000000004.gz
-rw-r--r-- 1 dscott xendev 150351797 Oct 24 09:54 chunk-000000005.gz

$ ls -l very\ simple\ Debian\ VM/sdb
total 516
-rw-r--r-- 1 dscott xendev 521937 Oct 24 09:54 chunk-000000000.gz

The example simple Debian VM would have an XVA file like the following:

<?xml version="1.0" ?>
<appliance version="0.1">
<vm name="vm">
<label>
very simple Debian VM
</label>
<shortdesc>
the description field can contain any valid UTF-8
</shortdesc>
<config mem_set="536870912" vcpus="1"/>
<hacks is_hvm="false" kernel_boot_cmdline="root=/dev/sda1 ro ">
<!--This section is temporary and will be ignored in future. Attribute
is_hvm ("true" or "false") indicates whether the VM will be booted in HVM mode. In
future this will be autodetected. Attribute kernel_boot_cmdline contains the kernel
commandline for the case where a proper grub menu.lst is not present. In future
booting shall only use pygrub.-->
</hacks>
<vbd device="sda" function="root" mode="w" vdi="vdi_sda"/>
<vbd device="sdb" function="swap" mode="w" vdi="vdi_sdb"/>
</vm>
<vdi name="vdi_sda" size="5368709120" source="file://sda" type="dir-gzippedchunks"/>
<vdi name="vdi_sdb" size="536870912" source="file://sdb" type="dir-gzippedchunks"/>
</appliance>


Because the import and export of VMs can take some time to complete, an
asynchronous HTTP interface to the import and export operations is
provided. To perform an export using the XenServer API, construct
an HTTP GET call providing a valid session ID, task ID and VM UUID, as
shown in the following pseudo code:

    task = Task.create()
    result = HTTP.get(
      server, 80, "/export?session_id=&task_id=&ref=");

For the import operation, use an HTTP PUT call as demonstrated in the
following pseudo code:

    task = Task.create()
    result = HTTP.put(
      server, 80, "/import?session_id=&task_id=&ref=");
