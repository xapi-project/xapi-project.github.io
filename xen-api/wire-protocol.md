---
title: Wire Protocol for Remote API Calls
layout: default
---

API calls are sent over a network to a Xen-enabled host using the
XML-RPC protocol. In this Section we describe how the higher-level types
used in our API Reference are mapped to primitive XML-RPC types.

In our API Reference we specify the signatures of API functions in the
following style:

        (ref_vm Set)   VM.get_all()

This specifies that the function with name <span>VM.get\_all</span>
takes no parameters and returns a Set of <span>ref\_vm</span>s. These
types are mapped onto XML-RPC types in a straight-forward manner:

-   Floats, Bools, DateTimes and Strings map directly to the XML-RPC
    <span>double</span>, <span>boolean</span>,
    <span>dateTime.iso8601</span>, and <span>string</span> elements.

-   all “<span>ref\_</span>” types are opaque references, encoded as the
    XML-RPC’s <span>String</span> type. Users of the API should not make
    assumptions about the concrete form of these strings and should not
    expect them to remain valid after the client’s session with the
    server has terminated.

-   fields named “<span>uuid</span>” of type “<span>String</span>” are
    mapped to the XML-RPC <span>String</span> type. The string itself is
    the OSF DCE UUID presentation format (as output by
    <span>uuidgen</span>, etc).

-   ints are all assumed to be 64-bit in our API and are encoded as a
    string of decimal digits (rather than using XML-RPC’s built-in
    32-bit <span>i4</span> type).

-   values of enum types are encoded as strings. For example, a value of
    <span>destroy</span> of type <span>on\_normal\_exit</span>, would be
    conveyed as:

            <value><string>destroy</string></value>
          

-   for all our types, <span>t</span>, our type <span>t Set</span>
    simply maps to XML-RPC’s <span>Array</span> type, so for example a
    value of type <span>String Set</span> would be transmitted like
    this:

        <array>
          <data>
            <value><string>CX8</string></value>
            <value><string>PSE36</string></value>
            <value><string>FPU</string></value>
          </data>
        </array> 
          

-   for types <span>k</span> and <span>v</span>, our type <span>(k, v)
    Map</span> maps onto an XML-RPC struct, with the key as the name of
    the struct. Note that the <span>(k, v) Map</span> type is only valid
    when <span>k</span> is a <span>String</span>, <span>Ref</span>, or
    <span>Int</span>, and in each case the keys of the maps are
    stringified as above. For example, the <span>(String, double)
    Map</span> containing a the mappings Mike $\rightarrow$ 2.3 and John
    $\rightarrow$ 1.2 would be represented as:

        <value>
          <struct>
            <member>
              <name>Mike</name>
              <value><double>2.3</double></value>
            </member>
            <member>
              <name>John</name>
              <value><double>1.2</double></value>
            </member>
          </struct>
        </value>
          

-   our <span>Void</span> type is transmitted as an empty string.

Note on References vs UUIDs
---------------------------

References are opaque types — encoded as XML-RPC strings on the wire —
understood only by the particular server which generated them. Servers
are free to choose any concrete representation they find convenient;
clients should not make any assumptions or attempt to parse the string
contents. References are not guaranteed to be permanent identifiers for
objects; clients should not assume that references generated during one
session are valid for any future session. References do not allow
objects to be compared for equality. Two references to the same object
are not guaranteed to be textually identical.

UUIDs are intended to be permanent names for objects. They are
guaranteed to be in the OSF DCE UUID presentation format (as output by
<span>uuidgen</span>. Clients may store UUIDs on disk and use them to
lookup objects in subsequent sessions with the server. Clients may also
test equality on objects by comparing UUID strings.

The API provides mechanisms for translating between UUIDs and opaque
references. Each class that contains a UUID field provides:

-   A “<span>get\_by\_uuid</span>” method that takes a UUID, $u$, and
    returns an opaque reference to the server-side object that has
    UUID=$u$;

-   A <span>get\_uuid</span> function (a regular “field getter” RPC)
    that takes an opaque reference, $r$, and returns the UUID of the
    server-side object that is referenced by $r$.

Return Values/Status Codes {#synchronous-result}
--------------------------

The return value of an RPC call is an XML-RPC <span>Struct</span>.

-   The first element of the struct is named <span>Status</span>; it
    contains a string value indicating whether the result of the call
    was a “<span>Success</span>” or a “<span>Failure</span>”.

If <span>Status</span> was set to <span>Success</span> then the Struct
contains a second element named <span>Value</span>:

-   The element of the struct named <span>Value</span> contains the
    function’s return value.

In the case where <span>Status</span> is set to <span>Failure</span>
then the struct contains a second element named
<span>ErrorDescription</span>:

-   The element of the struct named <span>ErrorDescription</span>
    contains an array of string values. The first element of the array
    is an error code; the remainder of the array are strings
    representing error parameters relating to that code.

For example, an XML-RPC return value from the
<span>host.get\_resident\_VMs</span> function above may look like this:

        <struct>
           <member>
             <name>Status</name>
             <value>Success</value>
           </member>
           <member>
              <name>Value</name>
              <value>
                <array>
                   <data>
                     <value>81547a35-205c-a551-c577-00b982c5fe00</value>
                     <value>61c85a22-05da-b8a2-2e55-06b0847da503</value>
                     <value>1d401ec4-3c17-35a6-fc79-cee6bd9811fe</value>
                   </data>
                </array>
             </value>
           </member>
        </struct>

Making XML-RPC Calls
====================

Transport Layer
---------------

The following transport layers are currently supported:

-   HTTP/S for remote administration

-   HTTP over Unix domain sockets for local administration

Session Layer
-------------

The XML-RPC interface is session-based; before you can make arbitrary
RPC calls you must login and initiate a session. For example:

       session_id    session.login_with_password(string uname, string pwd)

Where <span>uname</span> and <span>password</span> refer to your
username and password respectively, as defined by the Xen administrator.
The <span>session\_id</span> returned by
<span>session.login\_with\_password</span> is passed to subequent RPC
calls as an authentication token.

A session can be terminated with the <span>session.logout</span>
function:

       void          session.logout(session_id session)

Synchronous and Asynchronous invocation
---------------------------------------

Each method call (apart from methods on “Session” and “Task” objects and
“getters” and “setters” derived from fields) can be made either
synchronously or asynchronously. A synchronous RPC call blocks until the
return value is received; the return value of a synchronous RPC call is
exactly as specified in Section [synchronous-result].

Only synchronous API calls are listed explicitly in this document. All
asynchronous versions are in the special <span>Async</span> namespace.
For example, synchronous call <span>VM.clone(...)</span> (described in
Chapter [api-reference]) has an asynchronous counterpart,
<span>Async.VM.clone(...)</span>, that is non-blocking.

Instead of returning its result directly, an asynchronous RPC call
returns a <span>task-id</span>; this identifier is subsequently used to
track the status of a running asynchronous RPC. Note that an asychronous
call may fail immediately, before a <span>task-id</span> has even been
created—to represent this eventuality, the returned <span>task-id</span>
is wrapped in an XML-RPC struct with a <span>Status</span>,
<span>ErrorDescription</span> and <span>Value</span> fields, exactly as
specified in Section [synchronous-result].

The <span>task-id</span> is provided in the <span>Value</span> field if
<span>Status</span> is set to <span>Success</span>.

The RPC call

        (ref_task Set)   Task.get_all(session_id s)

returns a set of all task IDs known to the system. The status (including
any returned result and error codes) of these tasks can then be queried
by accessing the fields of the Task object in the usual way. Note that,
in order to get a consistent snapshot of a task’s state, it is advisable
to call the “get\_record” function.

Example interactive session
===========================

This section describes how an interactive session might look, using the
python XML-RPC client library.

First, initialise python and import the library <span>xmlrpclib</span>:

    \$ python2.4
    ...
    >>> import xmlrpclib

Create a python object referencing the remote server:

    >>> xen = xmlrpclib.Server("https://localhost:443")

Acquire a session reference by logging in with a username and password
(error-handling ommitted for brevity; the session reference is returned
under the key <span>’Value’</span> in the resulting dictionary)

    >>> session = xen.session.login_with_password("user", "passwd")['Value']

When serialised, this call looks like the following:

    <?xml version='1.0'?>
    <methodCall>
      <methodName>session.login_with_password</methodName>
      <params>
        <param>
          <value><string>user</string></value>
        </param>
        <param>
          <value><string>passwd</string></value>
        </param>
      </params>
    </methodCall>

Next, the user may acquire a list of all the VMs known to the system:
(Note the call takes the session reference as the only parameter)

    >>> all_vms = xen.VM.get_all(session)['Value']
    >>> all_vms
    ['OpaqueRef:1', 'OpaqueRef:2', 'OpaqueRef:3', 'OpaqueRef:4' ]

The VM references here have the form <span>OpaqueRef:X</span>, though
they may not be that simple in the future, and you should treat them as
opaque strings. <span>*Templates*</span> are VMs with the
<span>is\_a\_template</span> field set to true. We can find the subset
of template VMs using a command like the following:

    >>> all_templates = filter(lambda x: xen.VM.get_is_a_template(session, x)['Value'], all_vms)

Once a reference to a VM has been acquired a lifecycle operation may be
invoked:

    >>> xen.VM.start(session, all_templates[0], False, False)
    {'Status': 'Failure', 'ErrorDescription': ['VM_IS_TEMPLATE', 'OpaqueRef:X']}

In this case the <span>start</span> message has been rejected, because
the VM is a template, and so an error response has been returned. These
high-level errors are returned as structured data (rather than as
XML-RPC faults), allowing them to be internationalised.

Rather than querying fields individually, whole <span>*records*</span>
may be returned at once. To retrieve the record of a single object as a
python dictionary:

    >>> record = xen.VM.get_record(session, all_templates[0])['Value']
    >>> record['power_state']
    'Halted'
    >>> record['name_label']
    'XenSource P2V Server'

To retrieve all the VM records in a single call:

    >>> records = xen.VM.get_all_records(session)['Value']
    >>> records.keys()
    ['OpaqueRef:1', 'OpaqueRef:2', 'OpaqueRef:3', 'OpaqueRef:4' ]
    >>> records['OpaqueRef:1']['name_label']
    'RHEL 4.1 Autoinstall Template'
