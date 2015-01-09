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

Security enhancements
---------------------

The control domain in XenServer PRODUCT\_VERSION and above has various security enhancements in order to harden it against attack from malicious guests. Developers should never notice any loss of correct functionality as a result of these changes, but they are documented here as variations of behavior from other distributions.

-   The socket interface, `xenstored`, access using `libxenstore`. Interfaces are restricted by `xs_restrict()`.

-   The device `/dev/xen/evtchn`, which is accessed by calling `xs_evtchn_open()` in `libxenctrl`. A handle can be restricted using `xs_evtchn_restrict()`.

-   The device `/proc/xen/privcmd`, accessed through `xs_interface_open()` in `libxenctrl`. A handle is restricted using `xc_interface_restrict()`. Some privileged commands are naturally hard to restrict (e.g. the ability to make arbitrary hypercalls), and these are simply prohibited on restricted handles.

-   A restricted handle cannot later be granted more privilege, and so the interface must be closed and re-opened. Security is only gained if the process cannot subsequently open more handles.

The control domain privileged user-space interfaces can now be restricted to only work for certain domains. There are three interfaces affected by this change:

-   The `qemu` device emulation processes and `vncterm` terminal emulation processes run as a non-root user ID and are restricted into an empty directory. They uses the restriction API above to drop privileges where possible.

-   Access to xenstore is rate-limited to prevent malicious guests from causing a denial of service on the control domain. This is implemented as a token bucket with a restricted fill-rate, where most operations take one token and opening a transaction takes 20. The limits are set high enough that they should never be hit when running even a large number of concurrent guests under loaded operation.

-   The VNC guest consoles are bound only to the `localhost` interface, so that they are not exposed externally even if the control domain packet filter is disabled by user intervention.

Advanced settings for network interfaces
----------------------------------------

Virtual and physical network interfaces have some advanced settings that can be configured using the `other-config` map parameter. There is a set of custom ethtool settings and some miscellaneous settings.

### ethtool settings

Developers might wish to configure custom ethtool settings for physical and virtual network interfaces. This is accomplished with `ethtool-<option>` keys in the `other-config` map parameter.

<table>
<col width="20%" />
<col width="49%" />
<col width="28%" />
<thead>
<tr class="header">
<th align="left">Key</th>
<th align="left">Description</th>
<th align="left">Valid settings</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">ethtool-rx</td>
<td align="left">Specify if RX checksumming is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="even">
<td align="left">ethtool-tx</td>
<td align="left">Specify if TX checksumming is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="odd">
<td align="left">ethtool-sg</td>
<td align="left">Specify if scatter-gather is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="even">
<td align="left">ethtool-tso</td>
<td align="left">Specify if tcp segmentation offload is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="odd">
<td align="left">ethtool-ufo</td>
<td align="left">Specify if UDP fragmentation offload is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="even">
<td align="left">ethtool-gso</td>
<td align="left">Specify if generic segmentation offload is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="odd">
<td align="left">ethtool-autone g</td>
<td align="left">Specify if autonegotiation is enabled</td>
<td align="left"><code>on</code> or <code>true</code> to enable the setting, <code>off</code> or <code>false</code> to disable it</td>
</tr>
<tr class="even">
<td align="left">ethtool-speed</td>
<td align="left">Set the device speed in Mb/s</td>
<td align="left">10, 100, or 1000</td>
</tr>
<tr class="odd">
<td align="left">ethtool-duplex</td>
<td align="left">Set full or half duplex mode</td>
<td align="left">half or full</td>
</tr>
</tbody>
</table>

For example, to enable TX checksumming on a virtual NIC using the xe CLI:

    xe vif-param-set uuid=<VIF UUID> other-config:ethtool-tx="on"

or:

    xe vif-param-set uuid=<VIF UUID> other-config:ethtool-tx="true"

To set the duplex setting on a physical NIC to half duplex using the xe CLI:

    xe vif-param-set uuid=<VIF UUID> other-config:ethtool-duplex="half"

### Miscellaneous settings

You can also set a promiscuous mode on a VIF or PIF by setting the `promiscuous` key to `on`. For example, to enable promiscuous mode on a physical NIC using the xe CLI:

    xe pif-param-set uuid=<PIF UUID> other-config:promiscuous="on"

or:

    xe pif-param-set uuid=<PIF UUID> other-config:promiscuous="true"

The VIF and PIF objects have a `MTU` parameter that is read-only and provide the current setting of the maximum transmission unit for the interface. You can override the default maximum transmission unit of a physical or virtual NIC with the `mtu` key in the `other-config` map parameter. For example, to reset the MTU on a virtual NIC to use jumbo frames using the xe CLI:

    xe vif-param-set uuid=<VIF UUID> other-config:mtu=9000

Note that changing the MTU of underlying interfaces is an advanced and experimental feature, and may lead to unexpected side-effects if you have varying MTUs across NICs in a single resource pool.

Internationalization for SR names
---------------------------------

The SRs created at install time now have an `other_config` key indicating how their names may be internationalized.

`other_config["i18n-key"]` may be one of

-   `local-hotplug-cd`

-   `local-hotplug-disk`

-   `local-storage`

-   `xenserver-tools`

Additionally, `other_config["i18n-original-value-<field name>"]` gives the value of that field when the SR was created. If XenCenter sees a record where `SR.name_label` equals `other_config["i18n-original-value-name_label"]` (that is, the record has not changed since it was created during XenServer installation), then internationalization will be applied. In other words, XenCenter will disregard the current contents of that field, and instead use a value appropriate to the user's own language.

If you change `SR.name_label` for your own purpose, then it no longer is the same as `other_config["i18n-original-value-name_label"]`. Therefore, XenCenter does not apply internationalization, and instead preserves your given name.

Hiding objects from XenCenter
-----------------------------

Networks, PIFs, and VMs can be hidden from XenCenter by adding the key `HideFromXenCenter=true` to the `other_config` parameter for the object. This capability is intended for ISVs who know what they are doing, not general use by everyday users. For example, you might want to hide certain VMs because they are cloned VMs that shouldn't be used directly by general users in your environment.

In XenCenter, hidden Networks, PIFs, and VMs can be made visible, using the View menu.
