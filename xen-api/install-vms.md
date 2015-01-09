---
title: Installing VMs
layout: default
---

VMs can be installed from:

- iso images
- the network
- specially marked pre-installed "templates (aka "golded images")
- VM imports
- disk imports

Installing PV Linux from media
==============================

The installation of paravirtual Linux guests is complicated by the fact that a Xen-aware kernel must be booted, rather than simply installing the guest using hardware-assistance. This does have the benefit of providing near-native installation speed due to the lack of emulation overhead. XenServer supports the installation of several different Linux distributions, and abstracts this process as much as possible.

To this end, a special bootloader known as `eliloader` is present in the control domain which reads various `other-config` keys in the VM record at start time and performs distribution-specific installation behavior.

-   `install-repository` - Required. Path to a repository; 'http', 'https', 'ftp', or 'nfs'. Should be specified as would be used by the target installer, but not including prefixes, e.g. method=.

-   `install-vnc` - Default: false. Use VNC where available during the installation.

-   `install-vncpasswd` - Default: empty. The VNC password to use, when providing one is possible using the command-line of the target distribution.

-   `install-round` - Default: 1. The current bootloader round. Not to be edited by the user (see below)

Red Hat Enterprise Linux 4.1/4.4
--------------------------------

`eliloader` is used for two rounds of booting. In the first round, it returns the installer `initrd` and kernel from `/opt/xensource/packages/files/guest-installer`. Then, on the second boot, it removes the additional updates disk from the VM, switches the bootloader to `pygrub`, and then begins a normal boot.

This sequence is required since Red Hat does not provide a Xen kernel for these distributions, and so the XenServer custom kernels for those distributions are used instead.

Red Hat Enterprise Linux 4.5/5.0
--------------------------------

Similar to the RHEL4.4 installation, except that the kernel and ramdisk are downloaded directly form the network repository that was specified by the user, and switch the bootloader to `pygrub` immediately. Note that pygrub is not executed immediately, and so will only be parsed on the next boot.

The network retrieval enables users to install the upstream Red Hat vendor kernel directly from their network repository. An updated XenServer kernel is also provided on the `xs-tools.iso` built-in ISO image which fixes various Xen-related bugs.

SUSE Enterprise Linux 10 SP1
----------------------------

This requires a two-round boot process. The first round downloads the kernel and ramdisk from the network repository and boots them. The second round then inspects the disks to find the installed kernel and ramdisk, and sets the `PV-bootloader-args` to reflect these paths within the guest filesystem. This process emulates the `domUloader` which SUSE use as an alternative to `pygrub`. Finally, the bootloader is set to `pygrub` and is executed to begin a normal boot.

The SLES 10 installation method means that the path for the kernel and ramdisk is stored in the VM record rather than in the guest `menu.lst`, but this is the only way it would ever work since the YAST package manager doesn't write a valid `menu.lst`.

CentOS 4.5 / 5.0
----------------

The CentOS installation mechanism is similar to that of the Red Hat installation notes above, save that some MD5 checksums are different which `eliloader` recognizes.
