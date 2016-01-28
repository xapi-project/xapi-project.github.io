---
title: Schedule Snapshot Design
layout: default
design_doc: true
revision: 1
status: proposed
---

The scheduled snapshot feature will utilize the existing architecture of VMPR. In terms of functionality, schedule snapshot is basically VMPR without its archiving capability.

Introduction
------------

* Schedule snapshot will be a new object in xapi as VMSS.
* A pool can have multiple VMSS and each VMSS will be configured to take snapshot of type disk, checkpoint or quiesce for the VMs as part of VMSS, on configured intervals.

Datapath Design
---------------

* There will be a cron job for VMSS.
* VMSS plugin will go through all the schedule snapshot policies in the pool and check if any of them are due.
* If a snapshot is due then : Go through all the VM objects in XAPI associated with this schedule snapshot policy and create a new snapshot.
* If the snapshot operation fails, create a notification alert for the event and move to the next VM.
* Flag the snapshot to have been created by the schedule service, using either other-config for the VM object or another parameter added for this purpose.
* Check if an older snapshot now needs to be deleted to comply with the retention value defined in the schedule policy.
* If we need to delete any existing snapshots, delete the oldest snapshot created via schedule policy.
* Set the last-run timestamp in the schedule policy.

Xapi Changes
------------

There is a new record for VM Scheduled Snapshot with new fields.

New fields:

* "name-label" type String : Name label for VMSS.
* "name-description" type String : Name description for VMSS.
* "is-schedule-snapshot-enabled" type Bool : Enable/Disable VMSS to take snapshot.
* "schedule-snapshot-type" type [DiskSnapshot; Checkpoint; Quiesce] : Type of snapshot policy takes.
* "schedule-snapshot-retention-value" type Int64 : Number of snapshots limit for a VM, max limit is 10.
* "schedule-snapshot-frequency" type [hourly; daily; weekly] : Frequency of taking snapshot of VMs.
* "snapshot-schedule" type (hour: DateTime, min: DateTime, days: string list) : Time Hour, Min of interval  of 15mins and Days of a week. 
* "is-schedule-snapshot-running" type Bool : If VMSS is in progress of taking snapshot.
* "schedule-snapshot-last-run-time" type Date : DateTime of last execution of VMSS.
* "is-alarm-enabled" type Bool : Alarm enable/disable for VMSS.
* "alarm-config" : type (is_alarm_enabled,["email_address", ((String), "");"smtp_server", ((String), "");"smtp_port", ((IntRange(1,65535)), "25")] : Sets the alarm config field for VMSS.
* "VMs" type VM refs : List of VMs part of VMSS.

New fields to VM record:

* "schedule-snapshot" type VMSS ref : VM part of VMSS.
* "is-snapshot-from-vmss" type Bool : If snapshot created from VMSS.

New APIs
--------

* vmss_snapshot_now (Ref vmss, Pool_Operater) -> String : This call executes the schedule snapshot immediately.
* vmss_create_alert (Ref _vmss, String "name", Int "priority", String "body", String "data", Local_Root) -> unit : This call creates an alert for schedule snapshot.
* vmss_get_alerts (Ref vmss, Int "hours_from_now", Pool_Operater) -> Set String : This call fetches a history of alerts for a given schedule snapshot
* vmss_set_snapshot_retention_value (Ref vmss, Int value, Pool_Operater) -> unit : Set the value of the_schedule_snapshot_retention value max is 10.
* vmss_set_is_schedule_snapshot_running (Ref vmss, Bool value, Local_Root) -> unit : Set the value of the is_schedule_snapshot_running field
* vmss_set_snapshot_frequency (Ref vmss, String "value", Pool_Operater) -> unit : Set the value of the snapshot_frequency field
* vmss_set_snapshot_schedule (Ref vmss, Map(String,String) "value", Pool_Operater) -> unit : Set the schedule to take snapshot.
* vmss_set_is_alarm_enabled (Ref vmss, Bool "value", Pool_Operater) -> unit : Set the value of the is_alarm_enabled field
* vmss_set_alarm_config (Ref vmss, Map(String,String) "value", Pool_Operater) -> unit : Set the alarm_config
* vmss_add_to_snapshot_schedule (Ref vmss, String "key", String "value", Pool_Operater) -> unit : Add key value pair to VMSS
* vmss_add_to_alarm_config (Ref vmss, String "key", String "value", Pool_Operater) -> unit : Add key value pair to alarm_config field.
* vmss_remove_from_snapshot_schedule (Ref vmss, String "key", Pool_Operater) -> unit : Remove key from VMSS.
* vmss_remove_from_alarm_config (Ref vmss, String "key", Pool_Operater) -> unit : Remove key from alarm_config field.
* vmss_set_schedule_snapshot_last_run_time (Ref vmss, DateTime "value", Local_Root) -> unit : Set the last run time for VMSS.

New CLIs
--------

* vmss-create (required : "name-label";"schedule-snapshot-type";"schedule-snapshot-frequency", optional : "name-description";"is-schedule-snapshot-enabled";"snapshot-schedule:";"snapshot-retention-value";"is-alarm-enabled";"alarm-config:") -> unit : Creates VM schedule snapshot.
* vmss-destroy (required : uuid) -> unit : Destroys a VM schedule snapshot.

