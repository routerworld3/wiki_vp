
## What your Envoy log is saying

You showed:

```text
"GET /api/v1/buckets/test-download-issues/objects/download?prefix=test.zip HTTP/1.1"
200
UPE
upstream_reset_after_response_started{protocol_error}
0
357675778
44456
1
y.y.x.16
```

### Read it like this

* **HTTP 200** = Envoy already sent success headers to the client, so the download **started successfully**
* **357,675,778 bytes sent** = about **357 MB** already went to the client
* **duration 44,456 ms** = about **44 seconds**
* **UPE** = Envoy response flag for **Upstream Protocol Error**
* **upstream_reset_after_response_started{protocol_error}** = the **upstream side** reset or broke the stream **after** the response had already started ([Envoy Proxy][1])

That means the failure is **not**:

* request rejected before start,
* not a simple 401 before download,
* not “client never got anything.”

It means:

> **Envoy had already begun streaming the file, then something upstream of Envoy broke the HTTP protocol/stream.** ([Envoy Proxy][1])

---

# Most important implication

This specific log line points to a problem on the **Envoy ↔ upstream** side, not the **client ↔ HAProxy** side.

In your chain:

```text
Client → HAProxy → NLB → Istio/Envoy → MinIO
```

this error is much more likely happening on:

```text
Envoy → MinIO
```

or in the local HTTP processing around that leg.

Because Envoy documents `upstream_reset_after_response_started{details}` as meaning the **upstream connection was reset after a response was started**, and codec/protocol details like `protocol_error` indicate an HTTP/protocol problem during the response stream. ([Envoy Proxy][1])

---

# Why this is different from a pure auth failure

A pure auth failure usually looks more like:

* 302 redirect to Keycloak
* 401 / 403
* login callback activity
* no large payload successfully streamed first

But your log says:

* status **200**
* hundreds of MB already sent
* then **upstream protocol error**

So this particular event looks like:

> **download started, then upstream stream broke mid-flight**

That is much more consistent with:

* upstream app closing badly,
* HTTP framing/chunking issue,
* connection reset from upstream,
* proxy/protocol mismatch,
* idle/max-duration/stream issue that surfaces as protocol break,
* or auth/session logic that triggers **mid-stream** and causes the upstream side to stop the response in a way Envoy considers a protocol error.

---

# Can auth still be involved?

Yes, **possibly indirectly**.

Because you said:

* MinIO uses Keycloak
* users sometimes get the same UI error when auth expires

That means one possibility is:

```text
Download starts with valid session
→ session/token check changes during long transfer
→ upstream app or auth layer aborts response
→ Envoy sees broken upstream response
→ logs UPE / upstream_reset_after_response_started{protocol_error}
```

So auth is **still possible**, but **not in the simple “302 before download” sense**.

Instead, it would be a **mid-stream upstream abort** that Envoy reports as a protocol/reset problem.

---

# What this log most strongly suggests

## Strongest interpretation

The real failure is likely in one of these buckets:

### 1. MinIO or something in front of MinIO is aborting the response mid-stream

This is the first thing I would suspect.

### 2. Envoy and upstream disagree on HTTP behavior

Examples:

* upstream closes unexpectedly
* malformed chunking/trailers
* stream reset
* HTTP/1.1 keepalive / framing issue
* HTTP/2-to-HTTP/1.1 translation edge case

### 3. Session/auth logic is killing the stream after it begins

Less common, but your Keycloak clue keeps this on the table.

### 4. Timeout or stream limit is hit somewhere upstream, but surfaces as protocol_error

Possible if application or proxy does not close gracefully.

---

# What this log does **not** mainly suggest

It does **not** mainly look like:

* client receive window collapse as the primary root cause
* HAProxy frontend-only TCP tuning issue
* simple WAN impairment by itself

Why? Because Envoy is specifically blaming the **upstream** side with `upstream_reset_after_response_started{protocol_error}`. ([Envoy Proxy][1])

WAN issues can still exist, but this log says the immediate break Envoy observed was **upstream-side protocol/reset**, not downstream-side client stall.

---

# How to map this to your byte counts

You said failures are often around **300 MB to 450 MB**.

That pattern is interesting because it suggests:

* the stream is healthy initially,
* then something repeats around a time/size boundary,
* not a random handshake/auth problem at request start.

That kind of pattern often points to:

* stream/session timeout,
* upstream app/resource boundary,
* chunked transfer interruption,
* token/session refresh edge case,
* or proxy stream handling under long-lived responses.

---

# What logs to check next, with keywords

## 1. Istio/Envoy ingress logs

Search around the exact failure timestamp for:

```bash
grep -Ei 'UPE|upstream_reset_after_response_started|protocol_error|reset|stream|codec|http1|http2'
```

Useful clues:

* repeated same path
* same byte range before failure
* same upstream host/pod
* same response flag

---

## 2. Envoy sidecar logs near MinIO pod, if sidecars are injected

This may be even better than ingress logs.

Search for:

```bash
grep -Ei 'protocol_error|upstream_reset|remote_reset|local_reset|codec|stream|http1|http2|reset reason'
```

This helps locate whether the break is:

* ingress gateway → MinIO service
* sidecar → MinIO container
* or MinIO app itself

---

## 3. MinIO logs

Search for:

```bash
grep -Ei 'error|abort|broken pipe|reset|connection reset|unexpected EOF|context canceled|unauthorized|expired|oidc|openid|sts|session'
```

The most useful non-auth keywords here are:

* `broken pipe`
* `connection reset`
* `unexpected EOF`
* `context canceled`

The most useful auth keywords are:

* `oidc`
* `openid`
* `sts`
* `expired`
* `session`
* `unauthorized`

---

## 4. Keycloak logs

Search for:

```bash
grep -Ei 'authentication_expired|login_required|expired|invalid_token|refresh|session'
```

If these line up exactly with the failed downloads, auth moves much higher on the list.

---

# Best diagnostic question to answer

You now want to answer:

> **Who broke the stream first?**

There are three candidates:

### A. MinIO broke it

Then MinIO logs should show abort/reset/error around the same second.

### B. Envoy/sidecar/proxy layer broke it

Then sidecar or gateway logs will show stream/protocol reset without corresponding MinIO app error.

### C. Auth/session logic caused MinIO or proxy to abort it

Then MinIO and/or Keycloak logs will line up with session/token expiry.

---

# My current best read

Based on the exact Envoy line you shared:

> **This looks more like an upstream mid-stream abort/protocol break than a frontend WAN-only problem.**

So I would rank likely causes like this:

1. **MinIO / upstream app / upstream proxy stream abort**
2. **Auth/session expiry causing upstream abort mid-download**
3. **Envoy-upstream HTTP protocol mismatch / framing issue**
4. **Pure client/WAN issue**

That ranking is because `UPE upstream_reset_after_response_started{protocol_error}` is an upstream-side signal after the response had already begun. ([Envoy Proxy][1])

---

# Very short summary

Your log means:

> **Envoy already started the 200 OK download, sent hundreds of MB, then the upstream side broke the HTTP stream in a way Envoy classified as a protocol error.**

So this is a **big clue away from “just HAProxy TCP tuning”** and toward:

* **MinIO**
* **Envoy ↔ MinIO protocol behavior**
* or **auth/session expiry killing the stream mid-flight**

The next most valuable step is to line up one failed timestamp across **ingress Envoy log + MinIO log + Keycloak log** and see which one breaks first.

[1]: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/response_code_details?utm_source=chatgpt.com "Response Code Details"
