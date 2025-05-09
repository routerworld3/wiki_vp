# Surricata Rules Overview
```suricata
# Alert on traffic to a specific IP and port
alert tcp any any -> 192.168.1.10 80 (msg:"Alert to specific IP and port 80"; sid:20250508001;)

# Drop traffic from multiple CIDR ranges to any port
drop ip [10.0.1.0/24, 10.0.2.0/24, 172.16.0.0/20] any -> $EXTERNAL_NET any (msg:"Drop traffic from multiple internal CIDRs"; sid:20250508002;)

# Drop TCP traffic to multiple high-risk ports from $HOME_NET
drop tcp $HOME_NET any -> $EXTERNAL_NET [21, 22, 23, 445] (msg:"Drop TCP to high-risk ports"; sid:20250508003;)

# Drop UDP traffic to specific ports from $HOME_NET
drop udp $HOME_NET any -> $EXTERNAL_NET [53, 161, 162] (msg:"Drop UDP to DNS and SNMP ports"; sid:20250508004;)

# Drop ICMP traffic from any source to $HOME_NET
drop icmp any any -> $HOME_NET any (msg:"Drop incoming ICMP"; sid:20250508005;)

# Drop all traffic to a specific IP on various ports
drop ip any any -> 203.0.113.5 [80, 443, 8080] (msg:"Drop all traffic to specific IP on HTTP/HTTPS/8080"; sid:20250508006;)

# Stateful rule: Drop established TCP connections to a specific port
drop tcp $HOME_NET any -> $EXTERNAL_NET 111 (msg:"Drop established TCP to port 111 (RPC)"; flow:to_server,established; sid:20250508007;)

# Stateful rule: Alert on new TCP connections to a specific port
alert tcp $HOME_NET any -> $EXTERNAL_NET 3389 (msg:"Alert new TCP to port 3389 (RDP)"; flow:to_server,not_established; sid:20250508008;)

# Stateful rule: Drop all traffic from a specific IP regardless of port
drop ip 192.168.1.5 any -> $EXTERNAL_NET any (msg:"Drop all traffic from specific internal IP"; sid:20250508009;)

# Stateful rule: Alert on HTTP traffic to a specific IP range on port 80
alert http $HOME_NET any -> [198.51.100.0/24] 80 (msg:"Alert HTTP traffic to specific IP range on port 80"; flow:to_server,established; sid:20250508010;)
```

## Explanation of the Rules:

* **`alert tcp any any -> 192.168.1.10 80 (msg:"Alert to specific IP and port 80"; sid:20250508001;)`**:
  * `alert`: The action to take when the rule matches (generate an alert).
  * `tcp`: The protocol (TCP).
  * `any any`: Any source IP and any source port.
  * `->`: Direction of traffic (from source to destination).
  * `192.168.1.10`: The destination IP address.
  * `80`: The destination port.
  * `(msg:"Alert to specific IP and port 80";)`: A message to include in the alert log.
  * `sid:20250508001;`: A unique rule identifier (Suricata ID).

* **`drop ip [10.0.1.0/24, 10.0.2.0/24, 172.16.0.0/20] any -> $EXTERNAL_NET any (msg:"Drop traffic from multiple internal CIDRs"; sid:20250508002;)`**:
  * `drop`: The action to take (silently block the traffic).
  * `ip`: Matches any IP protocol (TCP, UDP, ICMP, etc.).
  * `[10.0.1.0/24, 10.0.2.0/24, 172.16.0.0/20]`: A list of source CIDR ranges.
  * `any`: Any source port.
  * `$EXTERNAL_NET`: A Suricata variable representing external networks (you might need to define this based on your configuration).
  * `any`: Any destination IP and any destination port.

* **`drop tcp $HOME_NET any -> $EXTERNAL_NET [21, 22, 23, 445] (msg:"Drop TCP to high-risk ports"; sid:20250508003;)`**:
  * `tcp`: The protocol (TCP).
  * `$HOME_NET`: A Suricata variable representing your internal network(s).
  * `any`: Any source port.
  * `[21, 22, 23, 445]`: A list of destination ports (FTP, SSH, Telnet, SMB).

* **`drop udp $HOME_NET any -> $EXTERNAL_NET [53, 161, 162] (msg:"Drop UDP to DNS and SNMP ports"; sid:20250508004;)`**:
  * `udp`: The protocol (UDP).
  * `[53, 161, 162]`: A list of destination ports (DNS, SNMP).

* **`drop icmp any any -> $HOME_NET any (msg:"Drop incoming ICMP"; sid:20250508005;)`**:
  * `icmp`: The protocol (ICMP).
  * Drops all incoming ICMP traffic to your internal network.

* **`drop ip any any -> 203.0.113.5 [80, 443, 8080] (msg:"Drop all traffic to specific IP on HTTP/HTTPS/8080"; sid:20250508006;)`**:
  * `ip`: Matches all protocols.
  * Drops all traffic destined for the IP address `203.0.113.5` on ports 80, 443, and 8080.

* **`drop tcp $HOME_NET any -> $EXTERNAL_NET 111 (msg:"Drop established TCP to port 111 (RPC)"; flow:to_server,established; sid:20250508007;)`**:
  * `flow:to_server,established`: This stateful keyword ensures the rule only applies to traffic going from the `$HOME_NET` to the `$EXTERNAL_NET` and only for connections that have already been established.

* **`alert tcp $HOME_NET any -> $EXTERNAL_NET 3389 (msg:"Alert new TCP to port 3389 (RDP)"; flow:to_server,not_established; sid:20250508008;)`**:
  * `flow:to_server,not_established`: This stateful keyword alerts only on the initial SYN packet of a new TCP connection to port 3389.

* **`drop ip 192.168.1.5 any -> $EXTERNAL_NET any (msg:"Drop all traffic from specific internal IP"; sid:20250508009;)`**:
  * Drops all traffic originating from the specific internal IP `192.168.1.5` to any external destination and port.

* **`alert http $HOME_NET any -> [198.51.100.0/24] 80 (msg:"Alert HTTP traffic to specific IP range on port 80"; flow:to_server,established; sid:20250508010;)`**:
  * `http`: This keyword allows for HTTP-specific inspection (though in this case, it's just matching the protocol and port).
  * Alerts on established HTTP traffic going to the specified IP range on port 80.

### Key Concepts:

* **Action:** What to do when a rule matches (`alert`, `drop`, `pass`, `reject`).
* **Protocol:** The network protocol (`tcp`, `udp`, `icmp`, `ip`, `http`, `tls`, `dns`, `ssh`).
* **Source IP and Port:** The origin of the traffic. `any` matches any IP or port. You can specify single IPs, CIDR ranges (using square brackets `[]` for multiple), or use variables.
* **Destination IP and Port:** The target of the traffic. Similar to the source, you can specify single IPs, CIDR ranges, multiple ports (using square brackets `[]`), or use variables.
* **Direction (`->`, `<>`, `<-`):**
  * `->`: From source to destination.
  * `<>`: Bidirectional.
  * `<-`: From destination to source.
* **Message (`msg`):** A descriptive string for the rule, useful in logs and alerts.
* **Suricata ID (`sid`):** A unique identifier for each rule. It's good practice to manage these.
* **Stateful Keywords (`flow`):** Used for tracking the state of a connection. Examples:
  * `established`: The TCP connection has been established (SYN-ACK received).
  * `not_established`: The TCP connection is not yet established (e.g., SYN packet).
  * `to_server`: Traffic going from the initiator to the responder.
  * `from_server`: Traffic going from the responder to the initiator.
* **Application Layer Keywords (`http.host`, `tls.sni`, `ssh.software`, `dns.query`):** Allow inspection of application layer protocols.
* **Variables (`$HOME_NET`, `$EXTERNAL_NET`):** Represent network address spaces and make rules more readable and manageable. You need to define these variables in your Suricata configuration.

**Important Notes:**

* **Variable Definition:** You need to define the Suricata variables like `$HOME_NET` and `$EXTERNAL_NET` in your Suricata configuration file (`suricata.yaml`).
* **Rule Order:** The order of your rules can be crucial, especially when using `pass` rules. Suricata processes rules in the order they appear. You might need to consider using `priority` if your Suricata configuration uses the `default` rule evaluation order. AWS Network Firewall recommends using `STRICT_ORDER` for more predictable behavior.
* **Testing:** Always thoroughly test your Suricata rules in a non-production environment before deploying them. Incorrectly configured rules can block legitimate traffic.
* **Performance:** A large number of complex stateful rules can impact the performance of your firewall. Optimize your rules for efficiency.
* **AWS Network Firewall:** When using these rules with AWS Network Firewall, ensure they are compatible with the AWS Network Firewall Suricata rule format and limitations. You might need to structure them within JSON rule group definitions as shown in the examples in your provided text.

## Advance Rules

```suricata
# Alert on specific payload content in HTTP traffic
alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"Alert - Potential SQL Injection attempt in URI"; http.uri; content:"SELECT"; nocase; sid:20250508101;)

alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"Alert - User-Agent containing suspicious string"; http.user_agent; content:"malicious_string"; nocase; sid:20250508102;)

# Drop traffic with specific payload content in TCP on a specific port
drop tcp any any -> $EXTERNAL_NET 6667 (msg:"Drop IRC traffic containing potential bot command"; content:"PRIVMSG #botnet :!command"; nocase; sid:20250508103;)

# GeoIP fencing: Drop all incoming traffic from a specific country (e.g., Russia - RU)
drop ip $EXTERNAL_NET any -> $HOME_NET any (msg:"Drop incoming traffic from Russia"; geoip:src,RU; sid:20250508201;)

# GeoIP fencing: Alert on any traffic to or from a specific set of countries (e.g., China - CN, Iran - IR)
alert ip any any -> any any (msg:"Alert - Traffic to/from China or Iran"; geoip:any,CN,IR; sid:20250508202;)

# GeoIP fencing: Drop outbound HTTP traffic to a specific country (e.g., North Korea - KP)
drop http $HOME_NET any -> $EXTERNAL_NET 80 (msg:"Drop outbound HTTP to North Korea"; geoip:dst,KP; sid:20250508203;)

# Combine payload inspection and GeoIP: Alert on HTTP POST requests with specific content originating from a specific country (e.g., Nigeria - NG)
alert http $HOME_NET any -> $EXTERNAL_NET 80 (msg:"Alert - HTTP POST with suspicious data from Nigeria"; http.method; content:"POST"; http.request_body; content:"/upload.php?"; nocase; geoip:src,NG; flow:to_server,established; sid:20250508301;)

# Stateful GeoIP rule: Drop established TCP connections to a specific port originating from a blocked country (e.g., Syria - SY)
drop tcp $EXTERNAL_NET any -> $HOME_NET 443 (msg:"Drop established HTTPS from Syria"; flow:from_server,established; geoip:src,SY; sid:20250508302;)

# GeoIP fencing with negation: Allow traffic only from specific countries (e.g., United States - US, United Kingdom - UK), drop all others
drop ip $EXTERNAL_NET any -> $HOME_NET any (msg:"Drop incoming traffic not from US or UK"; geoip:src,!US,UK; sid:20250508401;)
pass ip $EXTERNAL_NET any -> $HOME_NET any (msg:"Allow incoming traffic from US or UK"; geoip:src,US,UK; sid:20250508402; noalert;)
```

**Explanation of the Advanced Rules:**

**Payload Inspection:**

* **`content` keyword:** This is the primary keyword for looking at the payload of a packet.
  * `content:"SELECT"; nocase;`: Looks for the string "SELECT" (case-insensitive) within the HTTP URI.
  * `content:"malicious_string"; nocase;`: Checks the HTTP User-Agent header for a specific string.
  * `content:"PRIVMSG #botnet :!command"; nocase;`: Examines the content of TCP traffic on port 6667 (often used for IRC) for a potential bot command.
  * `content:"/upload.php?"; nocase;`: Looks for a specific string in the HTTP request body.
* **`http.uri`, `http.user_agent`, `http.method`, `http.request_body`:** These keywords allow you to specify which part of the HTTP traffic you want to inspect.
* **`nocase`:** Makes the content matching case-insensitive.

**GeoIP Fencing:**

* **`geoip` keyword:** This keyword allows you to match traffic based on the geographical location of the source or destination IP address. It typically relies on a GeoIP database (like MaxMind).
  * **`geoip:src,RU;`**: Matches traffic where the source IP address is located in Russia.
  * **`geoip:dst,KP;`**: Matches traffic where the destination IP address is located in North Korea.
  * **`geoip:any,CN,IR;`**: Matches traffic where either the source or the destination IP address is located in China or Iran.
  * **`geoip:!US,UK;`**: Matches traffic where the source IP address is NOT located in the United States or the United Kingdom (negation using `!`).
* **Direction with `geoip`:** You can specify the direction (`src`, `dst`, `any`, `both`) to apply the GeoIP filter.

**Combining Payload and GeoIP:**

* You can combine `content` matching with `geoip` to create more specific rules that trigger only when traffic matches both criteria (e.g., specific payload from a certain country).

**Stateful GeoIP:**

* You can use the `flow` keyword along with `geoip` to apply geographical filtering to specific connection states (e.g., only block established connections from a certain country).

**Important Considerations for Advanced Rules:**

* **Performance Impact:** Deep packet inspection (payload analysis) can be resource-intensive. Use it judiciously and try to be as specific as possible in your rules to minimize the amount of data being inspected.
* **False Positives:** Rules that look at payload content can sometimes generate false positives if legitimate traffic happens to contain the matched strings. Refine your rules carefully.
* **GeoIP Database:** Suricata (and AWS Network Firewall if it supports GeoIP directly in Suricata rules) needs access to a GeoIP database to function correctly. Ensure this database is configured and updated regularly.
* **HTTPS/TLS:** Inspecting payload within HTTPS traffic is more complex as the content is encrypted. You might need TLS decryption capabilities in your environment to analyze the decrypted payload. Suricata can inspect TLS metadata (like SNI or JA3 hashes) without decryption.
* **Rule Order (Again):** When using GeoIP rules for blocking and allowing, the order is critical. In the example of allowing only US and UK, the `drop` rule for all other countries should come *before* the `pass` rule for US and UK (or you should use `STRICT_ORDER` and ensure the `pass` rule has a higher priority). The `noalert` keyword in the `pass` rule prevents excessive logging of allowed traffic.
* **AWS Network Firewall GeoIP:** When using GeoIP with AWS Network Firewall, refer to their specific documentation on how GeoIP filtering is implemented and which Suricata GeoIP keywords are supported. AWS might have its own way of handling GeoIP lists or might directly support the Suricata `geoip` keyword.

Remember to test all these advanced rules thoroughly in a non-production environment to ensure they function as expected and don't block legitimate traffic.



### Organizing Suricata Rules

Below is a **stream‑lined, non‑redundant Suricata rule set** that still illustrates every technique you showed (IP/CIDR filtering, port/service control, stateful flow keywords, payload inspection, GeoIP, allowlists, blocklists, alert‑only rules).
It is ordered the way AWS Network Firewall evaluates traffic when you enable **STRICT\_ORDER**:

1. **Pass (allow) rules**
2. **Drop (block) rules**
3. **Alert / detect rules**

> **Tip for AWS NFW**
> • Put Sections 1–2 into *separate* rule‑groups so an allowlist can sit in a higher‑priority “allow” group, followed by a “block” group, then a “monitor” group.
> • Everything that uses `flow:` or L7 keywords must live in a **STATEFUL** rule‑group; the rest can be **STATELESS**.

---

```suricata
###############################################################################
# VARIABLES – define these in suricata.yaml
# (examples shown for illustration only)
#
#   HOME_NET:       your internal CIDRs
#   EXTERNAL_NET:   !$HOME_NET
###############################################################################

###############################################################################
# 1. EXPLICIT ALLOW LIST  (PASS)  – traffic you *must* permit
###############################################################################

# Allow SMTP to approved relays
pass tcp $HOME_NET any -> 198.51.100.25 25  (msg:"Allow SMTP to relay1"; sid:10000001; rev:1; noalert;)
pass tcp $HOME_NET any -> 198.51.100.26 587 (msg:"Allow SMTP to relay2"; sid:10000002; rev:1; noalert;)

# Allow outbound TLS only to .gov / .mil
pass tls $HOME_NET any -> $EXTERNAL_NET any \
     (msg:"Allow TLS to .gov"; tls_sni; content:".gov"; nocase; endswith; \
      flow:to_server,established; sid:10000003; rev:1; noalert;)
pass tls $HOME_NET any -> $EXTERNAL_NET any \
     (msg:"Allow TLS to .mil"; tls_sni; content:".mil"; nocase; endswith; \
      flow:to_server,established; sid:10000004; rev:1; noalert;)

# GeoIP allow‑only US & UK for inbound traffic
pass ip $EXTERNAL_NET any -> $HOME_NET any \
     (msg:"Allow inbound from US/UK"; geoip:src,US,UK; sid:10000005; rev:1; noalert;)

###############################################################################
# 2. BLOCK LIST  (DROP)  – enforced policy
###############################################################################

## 2.1  Source‑based blocks
# Drop entire internal host
drop ip 192.168.1.5 any -> $EXTERNAL_NET any \
     (msg:"Blocked host 192.168.1.5"; sid:10000101; rev:1;)

# Drop traffic from multiple subnets
drop ip [10.0.1.0/24,10.0.2.0/24,172.16.0.0/20] any -> $EXTERNAL_NET any \
     (msg:"Blocked internal CIDRs"; sid:10000102; rev:1;)

# GeoIP blocklists
drop ip $EXTERNAL_NET any -> $HOME_NET any \
     (msg:"Block inbound from Russia";  geoip:src,RU; sid:10000103; rev:1;)
drop ip $EXTERNAL_NET any -> $HOME_NET any \
     (msg:"Block inbound NOT US/UK";   geoip:src,!US,UK; sid:10000104; rev:1;)

## 2.2  Destination‑based blocks
# Block specific server & ports
drop ip any any -> 203.0.113.5 [80,443,8080] \
     (msg:"Block traffic to 203.0.113.5"; sid:10000110; rev:1;)

## 2.3  Service / port blocks
# Insecure or high‑risk outbound services
drop tcp $HOME_NET any -> $EXTERNAL_NET [21,22,23,445] \
     (msg:"Block outbound high‑risk TCP"; sid:10000120; rev:1;)
drop udp $HOME_NET any -> $EXTERNAL_NET [53,161,162] \
     (msg:"Block outbound DNS/SNMP UDP"; sid:10000121; rev:1;)

# ICMP inbound
drop icmp any any -> $HOME_NET any \
     (msg:"Block inbound ICMP"; sid:10000122; rev:1;)

# Stateful block of established RPC (port 111)
drop tcp $HOME_NET any -> $EXTERNAL_NET 111 \
     (msg:"Block established RPC 111"; flow:to_server,established; \
      sid:10000123; rev:1;)

## 2.4  C2 / Phishing domain blocks (TLS SNI & HTTP Host)
drop tls  $HOME_NET any -> $EXTERNAL_NET any \
     (msg:"Block C2 domain zeus.bad.com"; tls_sni; content:"zeus.bad.com"; \
      nocase; endswith; flow:to_server,established; sid:10000130; rev:1;)
drop http $HOME_NET any -> $EXTERNAL_NET any \
     (msg:"Block phishing domain fakebank.com"; http_host; content:"fakebank.com"; \
      nocase; endswith; flow:to_server,established; sid:10000131; rev:1;)

###############################################################################
# 3. MONITOR / DETECT  (ALERT)  – SOC visibility, no enforcement
###############################################################################

## 3.1  Connection behaviour
alert tcp any any -> 192.168.1.10 80 \
      (msg:"HTTP to web‑server 192.168.1.10"; sid:10000201; rev:1;)
alert tcp $HOME_NET any -> $EXTERNAL_NET 3389 \
      (msg:"New RDP connection"; flow:to_server,not_established; \
       sid:10000202; rev:1;)
alert tcp $EXTERNAL_NET any -> $HOME_NET any \
      (flags:S; msg:"Possible SYN scan"; flow:to_server,stateless; \
       sid:10000203; rev:1;)
alert icmp $EXTERNAL_NET any -> $HOME_NET any \
      (msg:"ICMP probe"; sid:10000204; rev:1;)

## 3.2  Payload inspection
alert http $HOME_NET any -> $EXTERNAL_NET any \
      (msg:"Potential SQLi in URI"; http.uri; content:"SELECT"; nocase; \
       sid:10000210; rev:1;)
alert http $HOME_NET any -> $EXTERNAL_NET any \
      (msg:"Suspicious User‑Agent string"; http.user_agent; \
       content:"malicious_string"; nocase; sid:10000211; rev:1;)
alert dns $HOME_NET any -> $EXTERNAL_NET any \
      (msg:"Long TXT record – possible DNS tunnelling"; dns_query; \
       pcre:"/^[A-Za-z0-9]{50,}/"; sid:10000212; rev:1;)

## 3.3  GeoIP detection
alert ip any any -> any any \
      (msg:"Traffic to/from CN or IR"; geoip:any,CN,IR; \
       sid:10000220; rev:1;)
alert http $HOME_NET any -> $EXTERNAL_NET 80 \
      (msg:"Suspicious POST from Nigeria"; http.method; content:"POST"; \
       http.request_body; content:"/upload.php?"; nocase; \
       geoip:src,NG; flow:to_server,established; sid:10000221; rev:1;)
alert tcp $EXTERNAL_NET any -> $HOME_NET 443 \
      (msg:"Established HTTPS from Syria"; flow:from_server,established; \
       geoip:src,SY; sid:10000222; rev:1;)
```

---


