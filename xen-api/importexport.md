---
title: VM import/export
layout: default
---

Because the import and export of VMs can take some time to complete, an
asynchronous HTTP interface to the import and export operations is
provided. To perform an export using the XenServer API, construct
an HTTP GET call providing a valid session ID, task ID and VM UUID, as
shown in the following pseudo code:

    task = Task.create()
    result = HTTP.get(
      server, 80, "/export?session_id=&task_id=&ref=");

For the import operation, use an HTTP PUT call as demonstrated in the
following pseudo code:

    task = Task.create()
    result = HTTP.put(
      server, 80, "/import?session_id=&task_id=&ref=");
