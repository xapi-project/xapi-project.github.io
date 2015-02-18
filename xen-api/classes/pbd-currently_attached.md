---
class: PBD
field: currently_attached
---

When the `currently_attached` field is true, it means that the host has
successfully authenticated and mounted the remote storage device. In
the case of NFS this would typically mean the filesystem has been mounted;
in the case of iSCSI this would typically mean that a connection to the
target has been established.

If the connection to the storage fails (for example: if the network goes
down or a storage target fails), the host will keep trying to re-establish
the connection and the `currently_attached` field will remain `true`.
This implies that the `currently_attached=true` does not mean that the
storage is working well, or at all, simply that the host is trying to make
it work.

