---
title: VM consoles
layout: default
---

Most XenAPI graphical interfaces will want to gain access to the VM consoles, in order to render them to the user as if they were physical machines. There are several types of consoles available, depending on the type of guest or if the physical host console is being accessed:

**Console access**

|Operating System|Text|Graphical|Optimized graphical|
|:---------------|:---|:--------|:------------------|
|Windows|No|VNC, using an API call|RDP, directly from guest|
|Linux|Yes, through VNC and an API call|No|VNC, directly from guest|
|Physical Host|Yes, through VNC and an API call|No|No|

Hardware-assisted VMs, such as Windows, directly provide a graphical console over VNC. There is no text-based console, and guest networking is not necessary to use the graphical console. Once guest networking has been established, it is more efficient to setup Remote Desktop Access and use an RDP client to connect directly (this must be done outside of the XenAPI).

Paravirtual VMs, such as Linux guests, provide a native text console directly. XenServer provides a utility (called `vncterm`) to convert this text-based console into a graphical VNC representation. Guest networking is not necessary for this console to function. As with Windows above, Linux distributions often configure VNC within the guest, and directly connect to it over a guest network interface.

The physical host console is only available as a `vt100` console, which is exposed through the XenAPI as a VNC console by using `vncterm` in the control domain.

RFB (Remote Framebuffer) is the protocol which underlies VNC, specified in [The RFB Protocol](http://www.realvnc.com/docs/rfbproto.pdf). Third-party developers are expected to provide their own VNC viewers, and many freely available implementations can be adapted for this purpose. RFB 3.3 is the minimum version which viewers must support.

### Retrieving VNC consoles using the API

VNC consoles are retrieved using a special URL passed through to the host agent. The sequence of API calls is as follows:

1.  Client to Master/443: XML-RPC: `Session.login_with_password()`.

2.  Master/443 to Client: Returns a session reference to be used with subsequent calls.

3.  Client to Master/443: XML-RPC: `VM.get_by_name_label()`.

4.  Master/443 to Client: Returns a reference to a particular VM (or the "control domain" if you want to retrieve the physical host console).

5.  Client to Master/443: XML-RPC: `VM.get_consoles()`.

6.  Master/443 to Client: Returns a list of console objects associated with the VM.

7.  Client to Master/443: XML-RPC: `VM.get_location()`.

8.  Returns a URI describing where the requested console is located. The URIs are of the form: `https://192.168.0.1/console?ref=OpaqueRef:c038533a-af99-a0ff-9095-c1159f2dc6a0`.

9.  Client to 192.168.0.1: HTTP CONNECT "/console?ref=(...)"

The final HTTP CONNECT is slightly non-standard since the HTTP/1.1 RFC specifies that it should only be a host and a port, rather than a URL. Once the HTTP connect is complete, the connection can subsequently directly be used as a VNC server without any further HTTP protocol action.

This scheme requires direct access from the client to the control domain's IP, and will not work correctly if there are Network Address Translation (NAT) devices blocking such connectivity. You can use the CLI to retrieve the console URI from the client and perform a connectivity check.

Retrieve the VM UUID by running:

xe vm-list params=uuid --minimal name-label=

Retrieve the console information:

xe console-list vm-uuid=
uuid ( RO): 714f388b-31ed-67cb-617b-0276e35155ef
vm-uuid ( RO): 8acb7723-a5f0-5fc5-cd53-9f1e3a7d3069
vm-name-label ( RO): etch
protocol ( RO): RFB
location ( RO): https://192.168.0.1/console?ref=(...)

Use command-line utilities like `ping` to test connectivity to the IP address provided in the `location` field.

### Disabling VNC forwarding for Linux VM

When creating and destroying Linux VMs, the host agent automatically manages the `vncterm` processes which convert the text console into VNC. Advanced users who wish to directly access the text console can disable VNC forwarding for that VM. The text console can then only be accessed directly from the control domain directly, and graphical interfaces such as XenCenter will not be able to render a console for that VM.

Before starting the guest, set the following parameter on the VM record:

xe vm-param-set uuid=uuid other-config:disable_pv_vnc=1

Start the VM.

Use the CLI to retrieve the underlying domain ID of the VM with:

xe vm-list params=dom-id uuid= --minimal

On the host console, connect to the text console directly by:

/usr/lib/xen/bin/xenconsole

This configuration is an advanced procedure, and we do not recommend that the text console is directly used for heavy I/O operations. Instead, connect to the guest over SSH or some other network-based connection mechanism.
