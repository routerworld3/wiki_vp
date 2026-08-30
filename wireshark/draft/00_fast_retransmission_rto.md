Exactly. The key is that **Wireshark distinguishes retransmission types by reconstructing TCP state**—sequence numbers, ACKs, timing, and what it previously saw. There is no TCP header bit saying “this is an RTO.”

According to Wireshark’s current TCP analysis documentation, a normal `TCP Retransmission` is suspected when a segment overlaps sequence space Wireshark has already seen. A `TCP Fast Retransmission` gets a more specific classification when duplicate ACK/recovery conditions are also present. Wireshark also exposes `tcp.analysis.rto` and `tcp.analysis.rto_frame`, which let you see the elapsed retransmission time and the earlier frame it measured from. ([Wireshark][1])

## Think of it this way

```text
                  Same TCP sequence sent again
                            |
                            v
                       Retransmission
                            |
             +--------------+---------------+
             |                              |
      Duplicate ACKs seen?             No useful Dup ACK
             |                              |
            YES                             |
             |                              |
     Fast Retransmission                 time passes
                                            |
                                            v
                                      TCP Retransmission
                                      with RTO timing
```

The important practical difference is:

```text
Fast Retransmission
    = receiver told sender:
      "I'm missing something"

RTO-style Retransmission
    = sender effectively heard:
      "nothing useful"
      and waited before resending
```

---

# 1. Wireshark example: Fast Retransmission

Imagine Server → Client is downloading data.

```text
Server                                      Client

Frame 100
Seq=10000 Len=1460 ------------------------>

Frame 101
Seq=11460 Len=1460 -------- X
                         LOST

Frame 102
Seq=12920 Len=1460 ------------------------>
                                      <---- ACK=11460

Frame 103
Seq=14380 Len=1460 ------------------------>
                                      <---- ACK=11460 DUP ACK

Frame 104
Seq=15840 Len=1460 ------------------------>
                                      <---- ACK=11460 DUP ACK

                                                |
                                                |
                         "Still waiting for 11460"
                                                |
                                                v

Frame 110
Seq=11460 Len=1460 ------------------------>
       TCP Fast Retransmission
```

The ACK number is the critical clue:

```text
ACK=11460
ACK=11460
ACK=11460
```

The receiver keeps saying:

> I received later data, but I am still missing the data beginning at sequence 11460.

Wireshark tracks that reverse-direction ACK behavior.

The current Wireshark algorithm considers several conditions for Fast Retransmission, including that sequence space is being repeated, duplicate ACK evidence exists, and the relevant ACK was seen recently. ([Wireshark][1])

Your filter:

```wireshark
tcp.analysis.fast_retransmission
```

Or for one connection:

```wireshark
tcp.stream eq 7 && tcp.analysis.fast_retransmission
```

---

# 2. What it looks like in the packet list

You might see:

```text
No.   Time       Source     Destination   Info

100   1.000000   Server     Client        Seq=10000 Len=1460
101   1.001000   Server     Client        Seq=11460 Len=1460
102   1.002000   Server     Client        Seq=12920 Len=1460

105   1.012000   Client     Server        ACK=11460
106   1.014000   Client     Server        [TCP Dup ACK] Ack=11460
107   1.016000   Client     Server        [TCP Dup ACK] Ack=11460

110   1.018000   Server     Client        [TCP Fast Retransmission]
                                            Seq=11460 Len=1460
```

This pattern is quite strong:

```text
missing SEQ
   ↓
Dup ACK
Dup ACK
Dup ACK
   ↓
Fast Retransmission
```

---

# 3. RTO looks very different

Now imagine this:

```text
Server                                      Client

Frame 200
Seq=50000 Len=1460 -------------------- X
                                        lost

                nothing

                nothing

                nothing

        sender keeps waiting...

                ~200 ms

Frame 220
Seq=50000 Len=1460 ------------------------>
       TCP Retransmission
```

There aren't several useful duplicate ACKs telling the sender exactly what disappeared.

Instead:

```text
Original transmission
       |
       | no ACK
       |
       | wait
       |
       | timeout
       v
Retransmission
```

That is timeout-based recovery.

---

# 4. What you should inspect in Wireshark

Suppose frame **220** says:

```text
[TCP Retransmission]
```

Click frame 220.

Expand:

```text
Transmission Control Protocol
   └── SEQ/ACK analysis
```

You may see something similar to:

```text
[SEQ/ACK analysis]
    [This frame is a (suspected) retransmission]
    [The RTO for this segment was: 0.205000 seconds]
    [RTO based on delta from frame: 200]
```

Wireshark officially exposes these fields:

```text
tcp.analysis.rto
tcp.analysis.rto_frame
```

where `tcp.analysis.rto_frame` identifies the earlier frame used for the timing comparison. ([Wireshark][2])

This is extremely useful.

You can now say:

```text
Frame 200
    original transmission
        |
        | 205 ms
        v
Frame 220
    retransmission
```

---

# 5. Filter specifically for retransmissions with RTO information

Try:

```wireshark
tcp.analysis.rto
```

Then restrict it to the TCP stream:

```wireshark
tcp.stream eq 7 && tcp.analysis.rto
```

Also useful:

```wireshark
tcp.analysis.rto_frame
```

And regular retransmissions:

```wireshark
tcp.analysis.retransmission
```

Fast retransmissions:

```wireshark
tcp.analysis.fast_retransmission
```

---

# 6. Put all of them together

For troubleshooting, I like:

```wireshark
tcp.stream eq 7 &&
(
 tcp.analysis.retransmission ||
 tcp.analysis.fast_retransmission ||
 tcp.analysis.duplicate_ack
)
```

Now the noise disappears and you may see something like:

```text
100  Server → Client   Seq=10000

110  Client → Server   Dup ACK=11460
111  Client → Server   Dup ACK=11460
112  Client → Server   Dup ACK=11460
113  Server → Client   TCP Fast Retransmission Seq=11460


200  Server → Client   Seq=50000

             <<< 0.205 second gap >>>

220  Server → Client   TCP Retransmission Seq=50000
                       RTO = 205 ms
                       RTO Frame = 200
```

Now you have **two completely different loss-recovery events**.

---

# 7. Add these columns to Wireshark

This makes troubleshooting much easier.

Right-click fields in Packet Details and select:

**Apply as Column**

I would add:

| Column                       | Purpose                              |
| ---------------------------- | ------------------------------------ |
| `frame.time_relative`        | When packet occurred                 |
| `frame.time_delta_displayed` | Time since previous displayed packet |
| `tcp.stream`                 | Connection                           |
| `tcp.seq`                    | Sequence number                      |
| `tcp.ack`                    | ACK number                           |
| `tcp.len`                    | Payload length                       |
| `tcp.analysis.ack_rtt`       | Measured ACK RTT                     |
| `tcp.analysis.rto`           | Retransmission timing                |
| `tcp.analysis.rto_frame`     | Original/reference frame             |

Your screen becomes much more useful:

```text
No. Time     ΔTime    Seq     Ack     Len    RTO       RTO Frame

100 1.000    .001     10000   5000    1460

101 1.001    .001     11460   5000    1460

102 1.002    .001     12920   5000    1460

...

110 1.018    .002     11460   5000    1460
    TCP Fast Retransmission


200 5.000             50000   7000    1460

220 5.205    .205     50000   7000    1460   .205      200
    TCP Retransmission
```

Frame 220 is the one I would investigate.

---

# 8. Very important distinction: RTO is calculated by the sender, not Wireshark

There is a subtle but important point.

The actual TCP host maintains something conceptually like:

```text
RTT measurements
      ↓
Smoothed RTT
      ↓
RTT variation
      ↓
Calculated RTO
```

Conceptually:

```text
RTO ≈ SRTT + 4 × RTTVAR
```

The **server operating system** determines when its retransmission timer expires.

Wireshark is an outside observer.

It sees:

```text
12:00:00.000 Seq=50000

            no ACK

12:00:00.205 Seq=50000 again
```

and reconstructs the event from the packets it observed.

So don't interpret:

```text
tcp.analysis.rto = 0.205
```

as:

> Wireshark knows the exact internal Linux/Windows TCP timer.

It's better interpreted as:

> Wireshark measured approximately 205 ms between the relevant original transmission and retransmission.

The field itself is described by Wireshark as how long transmission was delayed before the segment was retransmitted. ([Wireshark][2])

---

# 9. Why a "regular TCP Retransmission" often means timeout recovery

Wireshark has several classifications.

A repeated sequence number initially makes Wireshark think:

```text
"This sequence space has already been sent."
```

Then it tries more specific explanations.

### Case A — duplicate ACK evidence

```text
Original packet

later packet
later packet
later packet

Dup ACK
Dup ACK
Dup ACK

same sequence resent
```

Wireshark:

```text
TCP Fast Retransmission
```

### Case B — packet arrives very quickly

It could instead be:

```text
TCP Out-Of-Order
```

Wireshark uses timing and sequence relationships to help distinguish reordering from retransmission. ([Wireshark][1])

### Case C — already acknowledged data resent

Wireshark can classify:

```text
TCP Spurious Retransmission
```

### Case D — sequence is repeated without the more specific conditions

Wireshark:

```text
TCP Retransmission
```

The generic retransmission rule is essentially based on Wireshark observing previously seen sequence space again. ([Wireshark][1])

---

# 10. Here's the workflow I'd actually use on your capture

Suppose your RHUI download is slow.

First isolate it:

```wireshark
tcp.stream eq 24
```

Then:

```wireshark
tcp.stream eq 24 &&
(
 tcp.analysis.retransmission ||
 tcp.analysis.fast_retransmission ||
 tcp.analysis.duplicate_ack
)
```

Now find one event.

Suppose you see:

```text
Frame 15550
Server → Client
TCP Retransmission
Seq=3876021
RTO=.204 sec
RTO Frame=15120
```

Click:

```text
RTO Frame: 15120
```

Go to frame 15120.

You should find something like:

```text
Frame 15120

Server → Client
Seq=3876021
Len=1448
```

Now you have:

```text
15120
Server sends
Seq=3876021
       |
       | ~204 ms
       |
       | no successful ACK observed
       v
15550
Server sends
Seq=3876021 again
```

That's the packet pair you want to track.

---

# 11. Now determine whether the DATA or ACK was lost

This is the next critical step.

From a middle-box capture, you may see:

```text
Server → Client
Seq=3876021
        |
        |
        X
        |
       ???

200 ms

Server → Client
Seq=3876021
Retransmission
```

But you still don't know:

```text
Was DATA lost?

Server ---- X ----> Client
```

or:

```text
Did Client receive DATA,
but its ACK was lost?

Server ----------> Client
Server <---- X ---- Client
                 ACK
```

Both can cause retransmission.

This is why sequence/ACK analysis and, ideally, captures at two locations are so powerful.

---

# The mental model I want you to keep

```text
                    SAME SEQ SEEN AGAIN
                            |
                            v
                      Retransmission
                            |
             +--------------+--------------+
             |                             |
        Dup ACK evidence                No Dup ACK
             |                             |
             v                             v
       FAST RETRANSMIT               Timer expires
                                           |
                                           v
                                      RTO recovery
```

So when you are looking at a real capture, **don't just search for `[TCP Retransmission]`**. Look at the 10–20 packets immediately before it.

If you see:

```text
Dup ACK
Dup ACK
Dup ACK
Fast Retransmission
```

think **loss detected by ACK feedback**.

If you see:

```text
Data
...
200 ms silence
...
same Seq
TCP Retransmission
tcp.analysis.rto = 200 ms
```

think **timeout recovery**, which is normally much more damaging to throughput.

One nuance: Wireshark's classification is heuristic, not proof. Capture loss, asymmetric captures, and packet reordering can cause misleading analysis flags. Wireshark explicitly describes these as **“suspected”** retransmissions. ([Wireshark][2])

If you want, I can next show you a **20-packet realistic Wireshark trace for a slow Docker/RHUI download**, and walk packet-by-packet through **packet loss → Dup ACK → Fast Retransmission → RTO → congestion-window collapse**.

[1]: https://www.wireshark.org/docs/wsug_html_chunked/ChAdvTCPAnalysis.html?utm_source=chatgpt.com "7.5. TCP Analysis"
[2]: https://www.wireshark.org/docs/dfref/t/tcp.html?utm_source=chatgpt.com "Wireshark • Go Deep | Display Filter Reference: Transmission Control Protocol"
