---
title: XenServer API extensions
layout: default
---

The XenAPI is a general and comprehensive interface to managing the life-cycles of Virtual Machines, and offers a lot of flexibility in the way that XenAPI providers may implement specific functionality (e.g. storage provisioning, or console handling). XenServer has several extensions which provide useful functionality used in our own XenCenter interface. The workings of these mechanisms are described in this chapter.

Extensions to the XenAPI are often provided by specifying `other-config` map keys to various objects. The use of this parameter indicates that the functionality is supported for that particular release of XenServer, but *not* as a long-term feature. We are constantly evaluating promoting functionality into the API, but this requires the nature of the interface to be well-understood. Developer feedback as to how you are using some of these extensions is always welcome to help us make these decisions.

Adding Xenstore entries to VMs
------------------------------

Developers may wish to install guest agents into VMs which take special action based on the type of the VM. In order to communicate this information into the guest, a special Xenstore name-space known as `vm-data` is available which is populated at VM creation time. It is populated from the `xenstore-data` map in the VM record.

Set the `xenstore-data` parameter in the VM record:

    xe vm-param-set uuid= xenstore-data:vm-data/foo=bar

Start the VM.

If it is a Linux-based VM, install the COMPANY\_TOOLS and use the `xenstore-read` to verify that the node exists in Xenstore.

> **Note**
>
> Only prefixes beginning with `vm-data` are permitted, and anything not in this name-space will be silently ignored when starting the VM.
