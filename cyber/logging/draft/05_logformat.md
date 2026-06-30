# Log Format 

A set of diagrams derived from the architecture document. Each captures one distinct
idea rather than cramming everything into a single chart.

---

## 0. Three Axes of a Log — Format, Schema, Structure

Before anything else: a single log record is described by **three independent axes**.
Confusing them is the most common source of architecture mistakes.

| Axis | Question it answers | Examples | What changes it |
|------|---------------------|----------|-----------------|
| **Format** (encoding) | *How are the bytes serialized?* | JSON, XML, CSV, Parquet, Avro, Syslog | How you parse/serialize |
| **Schema** (data model) | *What do the fields mean and what are they named?* | OCSF, CIM, ASIM, ECS, UDM | How you normalize/correlate |
| **Structure** (parsing cost) | *How much extraction work remains?* | Structured → semi → unstructured | How far "left" structure was pushed |

```mermaid
flowchart TB
    LOG["A single log record"]:::log

    LOG --> AX1["AXIS 1 — FORMAT (encoding)<br/>how bytes are serialized<br/><br/>JSON · XML · CSV · Parquet · Syslog"]:::fmt
    LOG --> AX2["AXIS 2 — SCHEMA (meaning)<br/>what fields mean & are named<br/><br/>OCSF · CIM · ASIM · ECS · UDM"]:::sch
    LOG --> AX3["AXIS 3 — STRUCTURE (parsing cost)<br/>how much extraction remains<br/><br/>structured → semi → unstructured"]:::str

    KEY["KEY INSIGHT: the three are INDEPENDENT.<br/>An OCSF event (schema) is commonly stored AS Parquet or JSON (format),<br/>and may arrive already-structured or as a text blob (structure)."]:::key

    AX1 -.-> KEY
    AX2 -.-> KEY
    AX3 -.-> KEY

    classDef log fill:#E0E0E0,stroke:#757575,color:#333
    classDef fmt fill:#DEECF9,stroke:#0078D4,color:#063B6E
    classDef sch fill:#FCE8D5,stroke:#E8821E,color:#7A3E00
    classDef str fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
    classDef key fill:#FFF4CE,stroke:#D9B300,color:#5A4A00
```

> **Format vs. Schema in one line:** *Format* is the container (how it's encoded);
> *Schema* is the contents' meaning (what the fields are). They are orthogonal — you
> pick each independently. An OCSF event is a **schema**, most often stored **as** JSON
> or Parquet (the **format**).

---

## 1. The Two Layers (Foundations)

Encoding format vs. security schema — these are independent choices.

```mermaid
flowchart TB
    subgraph L1["LAYER 1 — Encoding / File Format"]
        direction LR
        F1[JSON]
        F2[XML]
        F3[CSV / Plain text]
        F4[Syslog]
        F5[Parquet]
    end

    subgraph L2["LAYER 2 — Security Schema / Data Model"]
        direction LR
        S1[OCSF]
        S2[CIM]
        S3[ASIM]
        S4[CEF / LEEF]
        S5[Elastic ECS]
    end

    L1 -->|"data is stored AS a format,<br/>then normalized INTO a schema"| L2

    note["Example: an OCSF event is a SCHEMA,<br/>commonly stored AS JSON or Parquet —<br/>the two choices are independent"]:::noteStyle
    L2 -.-> note

    classDef noteStyle fill:#FFF4CE,stroke:#D9B300,color:#5A4A00
```

---

## 2. Structured vs. Unstructured — the parsing-cost spectrum

```mermaid
flowchart LR
    subgraph SP[" "]
        direction LR
        A["STRUCTURED<br/><br/>JSON, Parquet,<br/>Windows Event XML,<br/>CloudTrail<br/><br/>fields already named"]:::low
        B["SEMI-STRUCTURED<br/><br/>VPC Flow Logs,<br/>CEF, most syslog<br/><br/>predictable, needs<br/>light extraction"]:::med
        C["UNSTRUCTURED<br/><br/>raw app stdout,<br/>legacy appliance text<br/><br/>timestamp + free-text blob"]:::high
    end

    A -->|increasing parsing cost| B -->|increasing parsing cost| C

    G["DESIGN GOAL:<br/>push structure as far LEFT (toward the source) as possible"]:::goal
    C -.-> G

    classDef low fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
    classDef med fill:#FFEB9C,stroke:#B7950B,color:#7D6608
    classDef high fill:#FFC7CE,stroke:#C0392B,color:#922B21
    classDef goal fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
```

---

## 3. Observability vs. Security — Two Domains, One Shared Substrate

The single most useful mental model: telemetry splits into an **observability** world
and a **security** world. They use different signals, schemas, and consumers — but they
**overlap at logs**. Metrics and traces are almost purely observability; security events
are purely security; **logs are read by both**.

```mermaid
flowchart TB
    subgraph OBS["OBSERVABILITY — 'Is the system healthy / why is it slow?'"]
        direction LR
        M["METRICS<br/>counters, gauges<br/>(CPU, latency, error rate)"]:::obs
        TR["TRACES<br/>request spans across services"]:::obs
        LO["LOGS<br/>event lines"]:::shared
    end

    subgraph SEC["SECURITY — 'Is something malicious happening?'"]
        direction LR
        LO2["LOGS<br/>auth, network, process, API"]:::shared
        EV["SECURITY EVENTS<br/>alerts, detections, IOCs"]:::sec
    end

    LO -.->|"same log lines feed both worlds"| LO2

    M --> OCONS["Consumers: SRE / DevOps / Platform<br/>Schema: OpenTelemetry semantic conventions<br/>Horizon: now → hours"]:::oconsumer
    TR --> OCONS
    LO --> OCONS

    LO2 --> SCONS["Consumers: SOC / Threat Hunting / IR<br/>Schema: OCSF / CIM / ASIM / UDM<br/>Horizon: months → years (forensics, compliance)"]:::sconsumer
    EV --> SCONS

    classDef obs fill:#DEECF9,stroke:#0078D4,color:#063B6E
    classDef sec fill:#FCE8D5,stroke:#E8821E,color:#7A3E00
    classDef shared fill:#FFF4CE,stroke:#D9B300,color:#5A4A00
    classDef oconsumer fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    classDef sconsumer fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
    style OBS fill:#FAFAFA,stroke:#0078D4
    style SEC fill:#FAFAFA,stroke:#E8821E
```

> **Takeaway:** Metrics and traces answer *health* questions; security events answer
> *threat* questions; **logs are the shared substrate** that both pipelines consume.
> That overlap is exactly why OpenTelemetry (which collects all three observability
> signals) ends up as a feeder into security schemas — see diagram 5.

---

## 4. Normalization Models by Platform

```mermaid
flowchart TB
    RAW["Raw vendor logs<br/>(different field names everywhere)"]:::raw

    RAW --> CIM["Splunk CIM<br/>search-time normalization<br/>raw data preserved"]:::splunk
    RAW --> ASIM["Microsoft ASIM<br/>parser-based,<br/>at query time"]:::ms
    RAW --> OCSF["OCSF<br/>ingestion-time,<br/>stored as Parquet"]:::aws
    RAW --> ECS["Elastic ECS<br/>ingestion-time,<br/>stored in indices"]:::other
    RAW --> UDM["Google UDM<br/>ingestion-time,<br/>normalized on arrival"]:::other

    CIM --> DET["Detections, dashboards,<br/>hunting, correlation"]:::det
    ASIM --> DET
    OCSF --> DET
    ECS --> DET
    UDM --> DET

    classDef raw fill:#E0E0E0,stroke:#757575,color:#333
    classDef splunk fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    classDef ms fill:#DEECF9,stroke:#0078D4,color:#063B6E
    classDef aws fill:#FCE8D5,stroke:#E8821E,color:#7A3E00
    classDef other fill:#F2F2F2,stroke:#999,color:#444
    classDef det fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
```

### What "when normalization happens" actually means

The five models above differ on **one critical axis: *when* raw data gets mapped into
the common schema** — at write time (ingestion) or at read time (query). This decision
drives storage cost, query speed, and how much you can change your mind later.

| Model | Platform | **When** normalization happens | How it works | Trade-off |
|-------|----------|-------------------------------|--------------|-----------|
| **CIM** | Splunk | **Search-time** | Raw events are stored verbatim. *Knowledge objects* — field extractions, aliases, tags, and event types — map raw fields onto the Common Information Model **only when a search runs**. | Maximum flexibility (re-map anytime, raw never lost), but the normalization work is paid on **every query**, and depends on correct tagging/CIM-compliant TAs. |
| **ASIM** | Microsoft Sentinel | **Query-time (parser-based)** | Data lands in tables in its native shape. ASIM **parsers** (KQL functions) translate native columns into the normalized ASIM schema **when the parser is invoked at query time**. Optionally pre-parsed for speed. | Like CIM: source data untouched, schema can evolve, but parsing cost is paid per query unless materialized. |
| **OCSF** | Amazon Security Lake & others | **Ingestion-time** | Data is transformed into the OCSF schema **as it is written**, then persisted as **Parquet** (columnar) in S3. What's stored on disk is *already normalized*. | Fast, cheap columnar queries (Athena) and a vendor-neutral schema, but normalization is committed at write — re-mapping means re-processing. |
| **ECS** | Elastic | **Ingestion-time** | Beats/Elastic Agent/ingest pipelines map fields to the Elastic Common Schema **before/at indexing**; documents are stored already conformed to ECS. | Consistent fields across all data at search time; mapping mistakes require reindexing to fix. |
| **UDM** | Google SecOps (Chronicle) | **Ingestion-time** | Parsers normalize raw logs into the Unified Data Model **on arrival**; UDM is what gets stored and searched. | Uniform, normalized events optimized for Chronicle's analytics, but you rely on (and sometimes must author) parsers for each source. |

**The pattern to remember:**

- **Search-time / query-time (CIM, ASIM)** → store raw, normalize on read. *Flexible, but pays the cost every query.*
- **Ingestion-time (OCSF, ECS, UDM)** → normalize on write, store conformed. *Fast and cheap to query, but committed — re-mapping means reprocessing.*

```mermaid
flowchart LR
    subgraph READTIME["NORMALIZE ON READ (schema-on-read)"]
        direction TB
        R1["Splunk CIM<br/>search-time"]:::splunk
        R2["Microsoft ASIM<br/>query-time parsers"]:::ms
        RN["✓ raw preserved, re-map anytime<br/>✗ cost paid on every query"]:::rnote
    end

    subgraph WRITETIME["NORMALIZE ON WRITE (schema-on-write)"]
        direction TB
        W1["OCSF → Parquet"]:::aws
        W2["Elastic ECS"]:::other
        W3["Google UDM"]:::other
        WN["✓ fast, cheap columnar queries<br/>✗ committed at write; re-map = reprocess"]:::wnote
    end

    classDef splunk fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    classDef ms fill:#DEECF9,stroke:#0078D4,color:#063B6E
    classDef aws fill:#FCE8D5,stroke:#E8821E,color:#7A3E00
    classDef other fill:#F2F2F2,stroke:#999,color:#444
    classDef rnote fill:#FFF4CE,stroke:#D9B300,color:#5A4A00
    classDef wnote fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
    style READTIME fill:#FAFAFA,stroke:#2E75B6
    style WRITETIME fill:#FAFAFA,stroke:#2E7D32
```

---

## 5. OCSF vs. OpenTelemetry — different problems, one bridge

OpenTelemetry is **both** a wire format (OTLP) **and** a set of semantic conventions —
so it sits awkwardly next to OCSF. It is *not just transport*, but it is also *not a
SIEM schema*. It collects the three observability signals (metrics, traces, logs);
you then normalize the **security-relevant subset** into OCSF/CIM/ASIM downstream.

```mermaid
flowchart TB
    subgraph OCSF_BOX["OCSF — Cybersecurity domain"]
        O1["Users: SOC, SIEM, threat hunting"]
        O2["Data: security events"]
        O3["Example:<br/>User X performed API action Y<br/>from IP Z — denied"]
        O4["Can serve as SIEM schema"]
    end

    subgraph OTEL_BOX["OpenTelemetry — Observability domain"]
        T1["Users: SRE, DevOps, platform"]
        T2["Data: logs, metrics, traces"]
        T0["Dual nature:<br/>OTLP wire format + semantic conventions<br/>(transport AND a schema-ish model)"]
        T3["Example:<br/>Service A called Service B,<br/>latency 2.5s"]
        T4["NOT a SIEM schema by itself"]
    end

    BRIDGE["Practical pattern:<br/>OTel Collector collects & transports telemetry →<br/>normalize the security-relevant subset<br/>into OCSF / CIM / ASIM downstream<br/><br/>(this is the same OTel Collector that appears<br/>in Tier 1 of the reference architecture, diagram 8)"]:::bridge

    OTEL_BOX -.-> BRIDGE
    BRIDGE -.-> OCSF_BOX

    classDef bridge fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    style OCSF_BOX fill:#FCE8D5,stroke:#E8821E
    style OTEL_BOX fill:#DEECF9,stroke:#0078D4
```

---

## 6. Source Inventory → Ingestion Paths

```mermaid
flowchart LR
    subgraph SRC["Data Sources"]
        CT["AWS CloudTrail<br/>(JSON)"]
        VPC["VPC Flow Logs<br/>(semi-structured / Parquet)"]
        WAF["WAF / Network Firewall<br/>(JSON)"]
        RDS["RDS logs<br/>(unstructured text)"]
        LNX["EC2 Linux<br/>(syslog)"]
        WIN["EC2 Windows<br/>(Event Log XML)"]
        K8S["Container / EKS<br/>(JSON lines or text)"]
        APP["Application logs<br/>(varies)"]
        MDE["MS Defender XDR<br/>(structured)"]
        ENT["Entra ID<br/>(JSON / Graph)"]
    end

    SPL["SPLUNK<br/>(CIM)"]:::splunk
    SEN["MICROSOFT SENTINEL<br/>(ASIM)"]:::ms

    CT --> SPL & SEN
    VPC --> SPL & SEN
    WAF --> SPL & SEN
    RDS -->|"CloudWatch → Firehose → HEC"| SPL
    RDS -->|"CloudWatch → Event Hub"| SEN
    LNX -->|"Universal Forwarder"| SPL
    LNX -->|"AMA → Syslog/CEF"| SEN
    WIN -->|"Universal Forwarder"| SPL
    WIN -->|"AMA → SecurityEvent"| SEN
    K8S -->|"OTel / Fluent Bit → HEC"| SPL
    K8S -->|"OTel / Fluent Bit → Event Hub"| SEN
    APP --> SPL & SEN
    MDE -->|"Defender Add-on / API"| SPL
    MDE -->|"native connector"| SEN
    ENT --> SPL & SEN

    classDef splunk fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    classDef ms fill:#DEECF9,stroke:#0078D4,color:#063B6E
```

---

## 7. The Key Decision — Where Normalization Happens

```mermaid
flowchart TB
    START{"Where is your<br/>center of gravity?"}:::decision

    START -->|"One SIEM,<br/>lowest upfront complexity"| A
    START -->|"Multi-vendor estate<br/>(AWS + Microsoft)"| B
    START -->|"Need volume reduction<br/>+ feed both SIEMs"| C

    A["OPTION A — SIEM-native<br/><br/>Logs → SIEM, normalize<br/>with CIM or ASIM<br/><br/>⚠ full volume hits expensive<br/>tier; vendor lock-in"]:::opt
    B["OPTION B — Lake-first ★ RECOMMENDED<br/><br/>Everything → OCSF (Parquet/S3),<br/>forward subset to SIEM<br/><br/>✓ cheap retention, neutral schema"]:::rec
    C["OPTION C — Pipeline / broker<br/><br/>Cribl / Kinesis / Event Hub<br/>parses, drops noise, fans out<br/><br/>✓ often combined with B"]:::opt

    classDef decision fill:#FFF4CE,stroke:#D9B300,color:#5A4A00
    classDef opt fill:#F2F2F2,stroke:#999,color:#333
    classDef rec fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
```

---

## 8. Tiered Reference Architecture (recommended)

```mermaid
flowchart TB
    subgraph T1["TIER 1 — COLLECTION (push structure left)"]
        direction LR
        C1["Linux / Windows EC2<br/>Universal Forwarder + AMA"]
        C2["Containers / apps<br/>OTel Collector / Fluent Bit<br/>(emit JSON)"]
        C3["AWS services<br/>native → S3 / CloudWatch"]
        C4["RDS<br/>CloudWatch Logs"]
    end

    subgraph T2["TIER 2 — AGGREGATION / TRANSPORT"]
        direction LR
        A1["AWS: CloudWatch → Kinesis Firehose<br/>S3 service logs"]
        A2["MS: Diagnostic settings → Event Hub"]
        A3["(optional broker:<br/>Cribl Stream — filter / route / reduce)"]
    end

    subgraph T3["TIER 3 — NORMALIZATION + STORAGE"]
        direction LR
        N1["Amazon Security Lake<br/>OCSF / Parquet / S3<br/>(long-term, cheap)"]:::aws
        N2["Sentinel Log Analytics<br/>ASIM<br/>(Microsoft estate)"]:::ms
    end

    subgraph T4["TIER 4 — DETECTION & ANALYTICS"]
        direction LR
        D1["Splunk (CIM)"]:::splunk
        D2["Sentinel (ASIM analytics)"]:::ms
        D3["Athena / lake queries<br/>(hunting & cold retention)"]:::aws
    end

    T1 --> T2 --> T3 --> T4

    classDef aws fill:#FCE8D5,stroke:#E8821E,color:#7A3E00
    classDef ms fill:#DEECF9,stroke:#0078D4,color:#063B6E
    classDef splunk fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
    style T1 fill:#FAFAFA,stroke:#BDBDBD
    style T2 fill:#FAFAFA,stroke:#BDBDBD
    style T3 fill:#FAFAFA,stroke:#BDBDBD
    style T4 fill:#FAFAFA,stroke:#BDBDBD
```

---

## 9. Cost & Retention Tiering

```mermaid
flowchart TB
    HOT["HOT / DETECTION<br/>real-time correlation & alerting<br/>Splunk index / Sentinel analytics<br/><b>Days to weeks</b>"]:::hot
    WARM["WARM / INVESTIGATION<br/>hunting, recent forensics<br/>Sentinel basic/aux logs; Splunk<br/><b>Weeks to months</b>"]:::warm
    COLD["COLD / ARCHIVE<br/>compliance, long-term forensics<br/>Security Lake (Parquet/S3), Sentinel archive<br/><b>Months to years</b>"]:::cold

    HOT --> WARM --> COLD

    RULE["Route only detection-relevant data to hot tiers.<br/>Keep full-fidelity copies in cheap object storage,<br/>query on demand (Athena over Parquet)."]:::rule

    COLD -.-> RULE

    classDef hot fill:#FFC7CE,stroke:#C0392B,color:#922B21
    classDef warm fill:#FFEB9C,stroke:#B7950B,color:#7D6608
    classDef cold fill:#C6EFCE,stroke:#2E7D32,color:#1B5E20
    classDef rule fill:#D5E8F0,stroke:#2E75B6,color:#1F3864
```
