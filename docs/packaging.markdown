---
title: Packaging
nav_order: 6
toc: true
---

Packaging can be somewhat difficult to get right due to some of the specific requirements of this provider and of unexpected default behaviour of distributions.
The root cause of most issues is typically related to the management network requirement. That is this provider requires that any box has the
DHCP enabled for the first network device attached.

The most results where this requirement is not met are failure of the guest to get an IP address on boot or failure for SSH connections to be established.

## No IP Address Detected

This typically manifests with the following message appearing as part of a traceback

_The specified wait_for timeout (2 seconds) was exceeded (Fog::Errors::TimeoutError)_


