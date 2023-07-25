---
title: Handling *.forwarded socket messages.
layout: default
---
This page describes how to handle forwarded requests.
------------------

Some XAPI daemon uses a *.forwarded unix domain socket to receive "forwarded"
requests from XAPI.
It uses a different interface than XML-RPC over HTTP, and can be a bit
confusing at first stance.

Through this socket, XAPI forwards the request from a host using a
JSON-serialized HTTP Request from the XAPI internal http library,
it is defined as such :

|        name        |           type         |           description
| ------------------ | ---------------------- | ------------------------------
| m                  | `string`               | HTTP method name
| uri                | `string`               | HTTP route
| query              | `Map<string, string>`  | HTTP Query strings (parameters)
| version            | `string`               | HTTP library version (1.1)
| frame              | `bool`                 | HTTP frame policy
| transfer_encoding  | `string?`              | 
| accept             | `string?`              | HTTP Accept header
| content_length     | `int64?`               | HTTP Content-Length header
| auth               | `List<string>`         | HTTP Auth header
| cookie             | `Map<string, string>`  | HTTP cookies
| task               | `string?`              | 
| subtask_of         | `string?`              | 
| content_type       | `string?`              | HTTP Content-Type header
| host               | `string?`              | HTTP Host header
| user_agent         | `string?`              | HTTP User-Agent header
| close              | `bool`                 | HTTP close policy
| additional_headers | `Map<string, string>`  | Additionnal HTTP headers
| body               | `string?`              | HTTP Request body
| traceparent        | `string?`              |

Example request
```json
{
  "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,
image/webp,*/*;q=0.8",
  "additional_headers": {
    "STUNNEL_PROXY": "TCP6 ...",
    "accept-encoding": "gzip, deflate, br"
  },
  "auth": [],
  "close": true,
  "cookie": {},
  "frame": false,
  "m": "Get",
  "query": {
    "host": "true",
    "interval": "1",
    "kind": "gauge",
    "start": "1687352958"
  },
  "uri": "/rrd_updates",
  "user_agent": "",
  "version": "1.1"
}
```

This request is sent through a Unix Domain Socket message (using
sendmsg/recvmsg, check recv(2) for more information).

This message contains a auxiliary data (CMSG) that contains a file descriptor,
this file descriptor is used to provide send the response.

The response is a regular HTTP response sent through the file descriptor.