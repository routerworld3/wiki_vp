A healthy TCP session in Wireshark follows a predictable three-phase structure: connection establishment, bidirectional data transfer, and connection termination.

---

**1. Connection Setup (Three-Way Handshake)**

Before any application data flows, the client and server negotiate parameters like window size and MSS (Maximum Segment Size):

* **`[SYN]`** (Client $\rightarrow$ Server): Client requests a connection, sending an Initial Sequence Number (`Seq=0`).
* **`[SYN, ACK]`** (Server $\rightarrow$ Client): Server acknowledges the client's sequence number (`Ack=1`) and sends its own (`Seq=0`).
* **`[ACK]`** (Client $\rightarrow$ Server): Client acknowledges the server (`Ack=1`). The connection is now established.

---

**2. Data Transfer Phase**

Once connected, data flows using relative sequence numbers (`Seq`) and acknowledgment numbers (`Ack`) to track byte counts.

* **Data Segment (`PSH, ACK` or `ACK` with Len > 0):**
* **Info field:** `[ACK] Seq=1 Ack=1 Len=1460`
* `Len=1460` means 1,460 bytes of application payload are being transmitted in this single packet.


* **Acknowledgment (`ACK` with Len = 0):**
* **Info field:** `[ACK] Seq=1 Ack=1461`
* The receiver acknowledges receipt up to byte 1460 by setting `Ack = 1461` (expecting byte 1461 next).


* **Sliding Window:**
* You will see the `Win=` value in the Info column (e.g., `Win=64240`). This tells the sender how many unacknowledged bytes the receiver's buffer can handle.



---

**3. Connection Teardown (Four-Way Handshake or Reset)**

When the data transfer completes, either side gracefully closes the socket:

| Frame | Direction | Flags / Info | Description |
| --- | --- | --- | --- |
| **1** | Client $\rightarrow$ Server | `[FIN, ACK]` | Client indicates it has finished sending data. |
| **2** | Server $\rightarrow$ Client | `[ACK]` | Server acknowledges the client's `FIN`. |
| **3** | Server $\rightarrow$ Client | `[FIN, ACK]` | Server closes its side of the connection. |
| **4** | Client $\rightarrow$ Server | `[ACK]` | Client acknowledges the server's `FIN`. |

*(Note: An abrupt termination will show a single **`[RST]`** or **`[RST, ACK]`** frame instead).*

---

**Visual Indicators of "Healthy" vs. "Unhealthy" Traffic**

* **Normal Traffic (Light Green):** Wireshark color-codes standard TCP traffic in light green. Sequences increment smoothly, ACKs match sent lengths, and window sizes stay stable.
* **Problem Signals (Black / Red text):**
* **`TCP Retransmission`:** A segment wasn't acknowledged in time and had to be resent.
* **`TCP Dup ACK`:** The receiver received out-of-order packets and is repeatedly asking for a missing segment.
* **`TCP ZeroWindow`:** The receiver's buffer is completely full; sender must pause transmission.
