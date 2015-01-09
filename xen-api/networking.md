---
title: Networking
layout: default
---

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
