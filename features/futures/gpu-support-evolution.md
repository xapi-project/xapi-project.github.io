---
title: GPU support evolution
layout: default
design_doc: true
revision: 1
status: proposed
---

Introduction
------------

As of XenServer 6.5, VMs can be provisioned with access to graphics processors
(either emulated or passed through) in four different ways. Virtualisation of
Intel graphics processors will exist as a fifth kind of graphics processing
available to VMs. These five situations all require the VM's device model to be
created in subtly different ways:

__Pure software emulation__

- qemu is launched either with no special parameter, if the basic Cirrus
  graphics processor is required, otherwise qemu is launched with the
  `-std-vga` flag.

__Generic GPU passthrough__

- qemu is launched with the `-priv` flag to turn on privilege separation
- qemu can additionally be passed the `-std-vga` flag to choose the
  corresponding emulated graphics card.

__Intel integrated GPU passthrough (GVT-d)__

- As well as the `-priv` flag, qemu must be launched with the `-std-vga` and
  `gfx_passthru` flags. The actual PCI passthrough is handled separately
  via xen.

__NVIDIA vGPU__

- qemu is launched with the `-vgpu` flag
- a secondary display emulator, demu, is launched with the following parameters:
  - `--domain` - the VM's domain ID
  - `--vcpus` - the number of vcpus available to the VM
  - `--gpu` - the PCI address of the physical GPU on which the emulated GPU will
    run
  - `--config` - the path to the config file which contains detail of the GPU to
      emulate

__Intel vGPU (GVT-g)__

- here demu is not used, but instead qemu is launched with five parameters:
  - `-xengt`
  - `-vgt_low_gm_sz` - the low GM size in MiB
  - `-vgt_high_gm_sz` - the high GM size in MiB
  - `-vgt_fence_sz` - the number of fence registers
  - `-priv`

xenopsd
-------

To handle all these possibilities, we will add some new types to xenopsd's
interface:

```
module Pci = struct
  type address = {
    domain: int;
    bus: int;
    device: int;
    fn: int;
  }

  ...
end

module Vgpu = struct
  type gvt_g = {
    physical_pci_address: Pci.address;
    low_gm_sz: int64;
    high_gm_sz: int64;
    fence_sz: int;
  }

  type nvidia = {
    physical_pci_address: Pci.address;
    config_file: string
  }

  type implementation =
    | GVT_g of gvt_g
    | Nvidia of nvidia

  type id = string * string

  type t = {
    id: id;
    position: int;
    implementation: implementation;
  }

  type state = {
    plugged: bool;
    emulator_pid: int option;
  }
end

module Vm = struct
  type igd_passthrough of
    | GVT_d

  type video_card =
    | Cirrus
    | Standard_VGAS
    | Vgpu
    | Igd_passthrough of igd_passthrough

  ...
end

module Metadata = struct
  type t = {
    vm: Vm.t;
    vbds: Vbd.t list;
    vifs: Vif.t list;
    pcis: Pci.t list;
    vgpus: Vgpu.t list;
    domains: string option;
  }
end
```

The `video_card` type is used to indicate to the function
`Xenops_server_xen.VM.create_device_model_config` how the VM's emulated graphics
card will be implemented. A value of `Vgpu` indicates that the VM needs to be
started with one or more virtualised GPUs - the function will need to look at
the list of GPUs associated with the VM to work out exactly what parameters to
send to qemu.

If `Vgpu.state.emulator_pid` of a plugged vGPU is `None`, this indicates that
the emulation of the vGPU is being done by qemu rather than by a separate
emulator.

n.b. adding the `vgpus` field to `Metadata.t` will break backwards compatibility
with old versions of xenopsd, so some upgrade logic will be required.

This interface will allow us to support multiple vGPUs per VM in future if
necessary, although this may also require reworking the interface between
xenopsd, qemu and demu. For now, xenopsd will throw an exception if it is asked
to start a VM with more than one vGPU.

xapi
----

To support the above interface, xapi will convert all of a VM's non-passthrough
GPUs into `Vgpu.t` objects when sending VM metadata to xenopsd.

In contrast to GVT-d, which can only be run on an Intel GPU which has been
has been hidden from dom0, GVT-g will only be allowed to run on a GPU which has
_not_ been hidden from dom0.

If a GVT-g-capable GPU is detected, and it is not hidden from dom0, xapi will
create a set of VGPU_type objects to represent the vGPU presets which can run on
the physical GPU. Exactly how these presets are defined is TBD, but a likely
solution is via a set of config files as with NVIDIA vGPU.
