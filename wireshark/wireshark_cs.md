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

Below is a concise cheat sheet for using **PktMon** (Windows) and **tcpdump** (Linux/Unix-like systems) to capture, stop, convert, and filter network traffic. You can convert or open captures in Wireshark, allowing deeper analysis of network issues.

---

## 1. PktMon (Windows)

PktMon is a built-in Windows packet monitoring tool introduced in Windows 10 (version 2004). It captures network traffic at the OS level and outputs an .etl file, which can be converted to pcapng or text for Wireshark or other tools.

### 1.1 Basic Capture Workflow

| **Action**                     | **Command**                                                                                                                                                             | **Notes**                                                                                 |
|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| **Start Capture**              | `pktmon start --capture --comp nics --flags 0x10 --file capture.etl`                                                                                                   | - `--comp nics` targets NIC-level components.<br>- `--flags 0x10` captures all packets.  |
| **Stop Capture**               | `pktmon stop`                                                                                                                                                           | Halts the capture and finalizes the `.etl` file.                                         |
| **Convert to Text (.txt)**     | `pktmon format capture.etl -o capture.txt`                                                                                                                              | Generates a human-readable text file (limited for deep analysis).                         |
| **Convert to PCAPNG (.pcapng)**| `pktmon pcapng capture.etl -o capture.pcapng`                                                                                                                           | `capture.pcapng` can be opened directly in Wireshark.                                    |

### 1.2 Common Notes & Options

- **Filters**: PktMon filtering is limited compared to tcpdump; typically you capture everything, then rely on Wireshark or other analyzers for specific filters.
- **Administrative Privileges**: You must run `pktmon` from an elevated command prompt (Run as Administrator).

---

## 2. tcpdump (Linux/Unix/macOS)

tcpdump is a powerful command-line packet analyzer. By default it writes output in PCAP format, which is directly compatible with Wireshark.

### 2.1 Basic Capture Workflow

| **Action**                       | **Command**                                                                                           | **Notes**                                                                                               |
|----------------------------------|--------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| **Start Capture to File**        | `tcpdump -i eth0 -w capture.pcap`                                                                     | - Captures on `eth0` interface.<br>- Press **Ctrl + C** to stop capture.                                |
| **Stop Capture**                 | *(Use Ctrl + C)*                                                                                      | tcpdump will finalize and close the capture file.                                                       |
| **Read/Analyze Capture**         | `tcpdump -r capture.pcap`                                                                             | View contents in the terminal (summary of packets).                                                     |
| **Convert to PCAP**             | *(No conversion needed)*                                                                               | tcpdump already outputs PCAP. Wireshark can open `.pcap` files directly.                                |
| **Capture Headers Only**         | `tcpdump -i eth0 -s 100 -w capture_headers.pcap`                                                      | - `-s 100` limits the snapshot length to 100 bytes (enough to get most headers).                         |
| **View in ASCII (on screen)**    | `tcpdump -i eth0 -A`                                                                                  | - Does not save to a file—prints ASCII data of packets to stdout.                                       |

> **Tip**: If you want the full packet, set `-s 0` (no snaplength limit).

### 2.2 Example Filter Syntax

tcpdump uses [BPF (Berkeley Packet Filter)](https://www.tcpdump.org/manpages/pcap-filter.7.html) expressions. Below are some common examples:

| **Filter**                         | **Command**                                                                   | **Description**                                                                     |
|-----------------------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| **Filter by Host**                | `tcpdump -i eth0 host 192.168.1.10 -w host_capture.pcap`                      | Captures traffic to/from a specific IP.                                             |
| **Filter by Port**                | `tcpdump -i eth0 port 80 -w port80.pcap`                                      | Captures traffic on port 80.                                                        |
| **Filter by Multiple Ports**      | `tcpdump -i eth0 'port 80 or port 443' -w web_ports.pcap`                     | Captures HTTP (80) or HTTPS (443) traffic.                                          |
| **Exclude a Port**                | `tcpdump -i eth0 'not port 22' -w no_ssh.pcap`                                 | Captures everything except SSH.                                                     |
| **Combine IP & Port**             | `tcpdump -i eth0 'host 192.168.1.10 and port 80' -w combined.pcap`            | Only captures traffic from 192.168.1.10 on port 80.                                 |
| **TCP Only**                      | `tcpdump -i eth0 tcp -w tcp_only.pcap`                                        | Captures only TCP traffic (excludes UDP, ICMP, etc.).                               |
| **Capture TCP SYN**               | `tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn) != 0' -w syn_only.pcap`           | Only captures TCP SYN packets.                                                      |
| **Capture Specific Traffic Size** | `tcpdump -i eth0 'tcp and greater 1000' -w large_tcp.pcap`                    | Captures TCP packets larger than 1000 bytes.                                        |
| **Capture with Time-based Filter**| `tcpdump -G 60 -W 5 -w capture-%Y%m%d-%H%M%S.pcap`                             | Rotates capture files every 60 seconds, keeping 5 files total (ring buffer).        |

### 2.3 Advanced Options

| **Option**            | **Meaning**                                                                                                             |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------|
| `-i <interface>`      | Specify which interface (e.g., `eth0`, `en0`) to capture from.                                                           |
| `-w <filename>`       | Write the raw packets to file in PCAP format (Wireshark-compatible).                                                     |
| `-r <filename>`       | Read packets from file (offline analysis).                                                                              |
| `-s <snaplen>`        | Maximum bytes captured per packet (default often 96 or 65535, `-s 0` for the whole packet).                             |
| `-v`, `-vv`, `-vvv`   | Increase verbosity (shows more header details).                                                                          |
| `-G <seconds>`        | Rotate capture files every N seconds (when used with `-w`).                                                              |
| `-C <MB>`             | Rotate capture files when they reach a size of `<MB>` megabytes.                                                         |
| `-W <count>`          | Used with `-C` or `-G` to limit the number of files in a ring buffer.                                                    |
| `-A` or `-X`          | Print packet data in ASCII (`-A`) or Hex/ASCII (`-X`) to stdout (doesn’t write pcap).                                    |
| `-nn`                 | Do not convert addresses or ports to names (faster output, raw numbers only).                                            |

---

## 3. Putting It All Together

1. **Windows**:  
   - Use **PktMon** to capture network traffic if you cannot install other tools.  
   - Convert the `.etl` file to `.pcapng` (`pktmon pcapng capture.etl -o capture.pcapng`), then open it in Wireshark for deeper analysis.

2. **Linux/Unix/macOS**:  
   - Use **tcpdump** to capture `.pcap` files directly.  
   - Apply BPF filters to narrow down traffic (e.g., specific ports, hosts, protocols).  
   - Load `.pcap` files in Wireshark for graphical analysis.

3. **Combining Filters**:  
   - For performance or slow-network investigations, focus on retransmissions, handshake failures, or large latencies.  
   - You can apply advanced Wireshark filters (from the [Wireshark Cheat Sheet](https://www.wireshark.org/docs/dfref/) or your own custom ones) after converting or opening captures.

---

### Quick Reference Summary

**PktMon Quick Start**  
```
pktmon start --capture --comp nics --flags 0x10 --file capture.etl
pktmon stop
pktmon pcapng capture.etl -o capture.pcapng   # Convert to Wireshark-friendly format
pktmon format capture.etl -o capture.txt      # Optional text summary
```

**tcpdump Quick Start**  
```
tcpdump -i eth0 -w capture.pcap           # Start capturing on eth0
# Ctrl + C to stop
tcpdump -r capture.pcap                   # Read pcap in terminal
tcpdump -i eth0 host 192.168.1.10 -w host.pcap  # Filter by host
tcpdump -i eth0 'port 80 or port 443' -w web.pcap  # Filter by multiple ports
```

Use these commands and filters to quickly start and stop captures, convert (where needed), and apply basic or advanced filters for diagnosing slow network connections or host issues. Once you have the capture file, open it in Wireshark (or any compatible analyzer) to apply more granular display filters and visualize packet flows.
