Below is a concise Wireshark cheat sheet focused on diagnosing slow network connections and potential host issues. The cheat sheet includes multiple tables covering common display filters, performance-related filters, and some frequently used commands to narrow down potential root causes.

---

## Table 1: Common Basic Wireshark Filters

| **Filter Expression**        | **Description/Usage**                                                                                 |
|------------------------------|--------------------------------------------------------------------------------------------------------|
| `ip.addr == 192.168.1.10`    | Show all traffic to or from a specific IP address.                                                    |
| `ip.src == 192.168.1.10`     | Show traffic originating from a specific IP.                                                          |
| `ip.dst == 192.168.1.10`     | Show traffic going to a specific IP.                                                                  |
| `tcp.port == 80`             | Show all TCP traffic on port 80.                                                                      |
| `udp.port == 53`             | Show all UDP traffic on port 53 (DNS).                                                                |
| `tcp && !(arp || icmp || dns)` | Show only TCP traffic while excluding ARP, ICMP, DNS, etc.                                           |
| `!(broadcast || multicast)`  | Exclude broadcast and multicast traffic (focus on unicast traffic).                                   |
| `eth.addr == AA:BB:CC:DD:EE:FF` | Filter by a specific MAC address.                                                                   |
| `tcp.flags.syn == 1 && tcp.flags.ack == 0` | Show only the first SYN packets (useful to see new TCP connection attempts).            |
| `frame.number == 100`        | Display only the 100th captured packet (useful for referencing a specific frame).                     |

**Tip**: When diagnosing a slow connection or host issue, you typically start by isolating traffic from the affected host(s) to see the transactions and latencies more clearly.

---

## Table 2: Filters for Diagnosing Slow Connections / Performance Issues

| **Filter Expression**                          | **Description/Usage**                                                                                              |
|------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `tcp.analysis.flags`                           | Shows packets with TCP analysis flags set (e.g., retransmissions, zero window, etc.).                              |
| `tcp.analysis.retransmission`                  | Display only retransmitted TCP packets (potential sign of congestion or packet loss).                               |
| `tcp.analysis.fast_retransmission`             | Display only fast retransmissions (often triggered by multiple ACKs indicating loss).                               |
| `tcp.analysis.zero_window`                     | Filter on Zero Window conditions, which means the receiver’s buffer is full and not reading data quickly enough.    |
| `tcp.analysis.duplicate_ack_frame`             | Shows frames with duplicate acknowledgments (sign of lost packets or network delays).                               |
| `tcp.len > 0`                                  | Show only TCP data packets (filter out pure ACKs).                                                                  |
| `tcp.window_size_value < 2000`                 | Detect small TCP window sizes that might be causing slow throughput (adjust threshold as needed).                   |
| `tcp.seq < tcp.ack`                            | Helpful for checking abnormal sequences (rare usage, but can indicate out-of-order or strange sequence anomalies).   |
| `tcp.time_delta > 0.2`                         | Show TCP packets with time deltas over 200ms between packets (useful to spot large gaps in conversation).           |
| `icmp`                                         | Useful if you suspect ping or path MTU issues—check ICMP errors (e.g., ‘Destination Unreachable’).                  |

---

## Table 3: Filters for Host and Application-Level Issues

| **Filter Expression**           | **Description/Usage**                                                                                     |
|---------------------------------|----------------------------------------------------------------------------------------------------------|
| `dns && ip.addr == <host IP>`   | Check if there are DNS issues (e.g., timeouts, repeated queries).                                        |
| `dns.time > 1`                  | Show DNS queries that took more than 1 second (change threshold if needed).                              |
| `http.request && ip.addr == X`  | Show HTTP requests from a specific host. Useful for analyzing slow web application performance.          |
| `http.response.code >= 400`     | Show HTTP error responses (client/server errors).                                                        |
| `tcp.port == 443`               | Focus on HTTPS traffic for performance or certificate/handshake issues.                                  |
| `ssl.record.content_type == 22` | TLS handshake traffic – helpful to diagnose slow or failing TLS handshakes.                              |
| `tcp.analysis.bytes_in_flight > 100000` | Shows packets where a large amount of unacknowledged data is in flight, possibly hitting a throughput limit. |

---

## Table 4: Useful Wireshark Display/Analysis Tips & Commands

| **Command / Function**                 | **Usage & Notes**                                                                                                                                    |
|---------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Follow TCP/UDP Stream**             | Right-click any packet in a conversation → **Follow** → **TCP Stream** (or UDP) to see a conversation in a dedicated window.                         |
| **Statistics → Conversations**         | Get an overview of all conversations and their volume. Great for identifying top talkers and heavy connections that might cause network slowness.   |
| **Statistics → IO Graph**             | Plot throughput, packet rates, or specific filters over time to visualize spikes or slowdowns.                                                       |
| **Statistics → TCP Stream Graph → Round Trip Time Graph** | Analyze TCP RTT to see if there’s excessive latency.                                                                                                  |
| **Statistics → TCP Stream Graph → Throughput** | Visualize throughput for a selected stream.                                                                                                         |
| **Expert Information**                | Go to **Analyze → Expert Information** for a summary of anomalies (retransmissions, zero window, etc.) across your capture.                         |
| **Coloring Rules**                    | Configure custom coloring to highlight slow or problematic traffic (e.g., highlight “tcp.analysis.retransmission”).                                  |
| **Filter Out External Noise**         | Use `!(broadcast || multicast || arp || icmp)` to reduce chatty broadcast and ARP traffic, making it easier to see relevant data.                    |

---

### Additional Recommendations for Slow Network/Host Diagnosis

- **Check DNS Resolution**: Slow DNS lookups can appear as delayed responses. Use `dns.time > 1` or look at the time between query and response in the packet details.
- **Monitor Window Size**: A receiver with a consistently small or zero window can be a bottleneck. Examine `tcp.window_size_value` and `tcp.analysis.zero_window`.
- **Look for Retransmissions**: High retransmission rates often indicate network congestion or poor signal quality (if wireless). Filters like `tcp.analysis.retransmission` and `tcp.analysis.fast_retransmission` are key.
- **Measure Delays**: Track time deltas with `tcp.time_delta > 0.2` (or a custom threshold) to pinpoint intervals where the communication stalls.
- **Use Expert Info**: Wireshark’s Expert Info flags many performance-related issues automatically; a quick review can speed up troubleshooting.

---

### How to Use These Filters Effectively

1. **Start Broad**: Apply general host or port filters to home in on the target traffic, e.g., `ip.addr == <host>` or `tcp.port == <port>`.
2. **Apply Narrowing Filters**: Once you see the relevant conversations, use performance-related filters (like retransmissions, zero windows, or high time deltas) to expose issues.
3. **Check Round-Trip Times (RTT)**: Use the **TCP Stream Graph** feature to visualize if the RTT is unusually high.
4. **Correlate with Other Layers**: If a slow network is suspected but not confirmed at the IP/TCP layers, look at DNS or application-layer (HTTP/TLS) interactions.

---

This collection of tables and notes should help you quickly filter and identify common causes for slow network connections or host issues in Wireshark. Adjust thresholds (like `0.2` seconds for delays or `1` second for DNS queries) based on your actual environment.
