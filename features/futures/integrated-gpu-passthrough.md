---
title: Integrated GPU passthrough support
layout: default
design_doc: true
revision: 1
status: proposed
---

Introduction
------------

Passthrough of discrete GPUs has been
[available since XenServer 6.0](/xapi/design/gpu-passthrough.html). With some
extensions, we will also be able to support passthrough of integrated GPUs.

- Whether an integrated GPU will be accessible to dom0 or available to
  passthrough to guests must be configurable via XenAPI.
- Passthrough of an integrated GPU requires an extra flag to be sent to qemu.

Host Configuration
------------------

A new host field will be added:

- `host.integrated_GPU_passthrough enum(disabled|enable_on_reboot|enabled|disable_on_reboot)`

as well as new API calls:

- `host.enable_integrated_GPU_passthrough`
- `host.disable_integrated_GPU_passthrough`

Enabling integrated GPU passthrough will modify the xen commandline (using the
xen-cmdline tool) such that dom0 will not be able to access the integrated GPU
on next boot.

A state diagram for the field host.integrated_GPU_passthrough is shown below:

![host.integrated_GPU_passthrough flow diagram](integrated-gpu-passthrough.png)

Note that when a client enables or disables integrated GPU passthrough, the
change can be cancelled until the host is rebooted.

Handling vga_arbiter
--------------------

Normally, xapi will not create a PGPU object for the PCI device with address
reported by `/dev/vga_arbiter`. This is to prevent a GPU in use by dom0 from
from being passed through to a guest. This will no longer be the case if:

1.  Integrated GPU passthrough is enabled.
2.  The vendor ID of the device is contained in a whitelist provided by xapi's
    config file.

Interfacing with xenopsd
------------------------

When starting a VM attached to an integrated GPU, the VM config sent to xenopsd
will contain a video_card of type IGD_passthrough. This will override the type
determined from VM.platform:vga. xapi will consider a GPU to be integrated if
both:

1.  It resides on bus 0.
2.  The vendor ID of the device is contained in a whitelist provided by xapi's
    config file.

When xenopsd starts qemu for a VM with a video_card of type IGD_passthrough,
it will pass the flags "-std-vga" AND "-gfx_passthru".
