# Stateful Default Actions 

---

#  Context: What Are These Default Actions?

When you configure a **stateful firewall policy** in **strict rule order**, AWS Network Firewall allows you to define **default actions** that apply **after all rules are evaluated** — or when **no rule matches**.

You can select **one or more** of these defaults:

| Action              | Applies To             | Description                                                                            |
| ------------------- | ---------------------- | -------------------------------------------------------------------------------------- |
| `alert_strict`      | All packets            | Logs **alerts** for all packets, but **does not drop** any traffic                     |
| `alert_established` | Established flows only | Logs alerts **only for packets in established TCP flows**                              |
| `drop_strict`       | All packets            | Drops all packets unless **explicitly allowed by a `pass` rule**                       |
| `drop_established`  | Established flows only | Drops **only established traffic**, allowing TCP 3-way handshake packets to go through |

---

#  Why Use These Defaults?

* They determine **what happens when no rule matches**
* In **strict mode**, you are in full control — nothing happens unless **you write a rule**
* These defaults help you:

  *  Enforce **default-deny** (zero trust)
  *  Enable **alert-only visibility**
  *  Enable **passive debugging**

---

#  Examples for Each Default

---

###  `alert_strict`

> “Log everything, don’t block anything.”

Used for: **monitoring only**, staging a rule set.

**Effect**:

* Every packet is logged as an alert
* No packets are dropped

**Use case**:

* Testing TLS SNI inspection rules before enforcing them
* Observing JA3 fingerprint matches

---

###  `alert_established`

> “Only log packets once a connection is established.”

Used for: **reduced verbosity** logging

**Effect**:

* Logs **only packets** in TCP flows that completed a handshake
* Ignores connection setup traffic (SYN/SYN-ACK)

**Use case**:

* Log outbound HTTPS behavior only after connection is made

---

###  `drop_strict`

> “Drop everything unless a rule explicitly allows it.”

Used for: **strict default-deny posture**

**Effect**:

* All traffic is dropped unless a `pass` rule matches

**Use case**:

* Zero trust model
* Force operators to explicitly `pass` TLS for only approved SNI (e.g., allow `.mil`, deny `.xyz`)

---

###  `drop_established`

> “Allow connection setup but drop data unless allowed.”

Used for: **application-layer allowlists**, such as SNI

**Effect**:

* TCP handshakes are allowed
* But all further packets in established connections are dropped unless matched by a rule

**Use case**:

* Use with TLS inspection to allow firewall to parse SNI
* Let TCP handshake complete → inspect `ClientHello` → block bad SNI

---

#  AWS Recommendations

| Goal                                             | AWS Recommended Default                     |
| ------------------------------------------------ | ------------------------------------------- |
| Passive visibility                               | `alert_strict` or `alert_established`       |
| App-layer inspection with TLS SNI                | `drop_established`                          |
| Full Zero Trust                                  | `drop_strict`                               |
| Mixed: alert on SNI mismatch, block some traffic | `alert_established` + specific `drop` rules |

---


#  Key Tips

| Tip                                                 | Why                                                 |
| --------------------------------------------------- | --------------------------------------------------- |
| Use `drop_established` with TLS inspection          | Allows SNI parsing before blocking                  |
| Don't use both `drop_strict` and `drop_established` | They're mutually exclusive                          |
| `alert_strict` is great for dry-run testing         | See what traffic would match, no impact             |
| Always pair with explicit `pass` or `drop` rules    | Strict mode does **nothing** unless you write rules |

---

