---
class: VM
field: memory_overhead
---

The `VM.memory_*` fields describe how much virtual RAM the
VM can see. Every running VM requires extra host memory to store
things like

- shadow copies of page tables, needed during migration or
  if hardware assisted paging is not available
- video RAM for the virtual graphics card
- records in the hypervisor describing the VM and the vCPUs

These memory "overheads" are recomputed every time the VM's
configuration changes, and the result is stored in
`VM.memory_overhead`.

For more information, read about
[Host memory accounting](../../xapi/design/memory-accounting.html)
