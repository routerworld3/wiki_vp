
0000  0d 0a 0d 0a 00 0d 0a 51 55 49 54 0a   # 12-byte PPv2 magic
000c  21                                     # ver/cmd = 0x21 (v2, PROXY)
000d  11                                     # fam/proto = 0x11 (IPv4 + TCP)
000e  00 54                                  # length = 0x0054 = 84 bytes (addr + TLVs)
0010  ac 1f 10 24                            # src IP   = 172.31.16.36
0014  64 58 58 20                            # dst IP   = 100.88.88.32
0018  c4 0c                                  # src port = 0xC40C = 50188
001a  00 16                                  # dst port = 0x0016 = 22 (SSH)

# TLVs (84 - 12 addr = 72 bytes of TLVs follow)

001c  03 00 04 99 86 dd a1                   # TLV: type=0x03 (CRC32C), len=4, value=99 86 DD A1

0023  ea 00 17 01                            # TLV: type=0xEA (AWS), len=0x0017 (23)
0027  76 70 63 65 2d 30 35 38 31 37 64 61    #  'vpce-05817da'
0033  63 63 65 33 34 31 39 65 30 63          #  'cce3419e0c'  (22-byte value)
                                             #  subtype=0x01 + "vpce-05817dacce3419e0c"

003d  04 00 24                               # TLV: type=0x04, len=0x0024 (36)
0040  00 ... (36 zero bytes) ... 00          # TLV value (all zeros)














tcp contains 0d:0a:0d:0a:00:0d:0a:51:55:49:54:0a
tcp contains 0d:0a:0d:0a:00:0d:0a:51:55:49:54:0a  && tcp matches "(?s)\x21\x11"

---

### 1) Detect **any** Proxy Protocol v2 (magic anywhere)

```suricata
alert tcp any any -> any any (msg:"PPv2 detected (magic)"; flow:to_server,established; content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A|"; fast_pattern; classtype:not-suspicious; sid:420020001; rev:1;)
```

---

### 2) Detect **PROXY + IPv4/TCP** (0x21 0x11) after magic

```suricata
alert tcp any any -> any any (msg:"PPv2 PROXY IPv4/TCP header"; flow:to_server,established; content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A|"; fast_pattern; content:"|21 11|"; distance:0; within:2; classtype:not-suspicious; sid:420020002; rev:1;)
```

> `distance:0; within:2` makes the `|21 11|` immediately follow the magic (i.e., ver/cmd + fam/proto).

---

### 3) **DROP** if PPv2 claims src IP = `172.31.16.36` to ports **80/443/22**

(Works even if the PPv2 header isn’t at packet offset 0)

```suricata
drop tcp any any -> $HOME_NET [80,443,22] (msg:"DROP PPv2 src=172.31.16.36 (IPv4/TCP)"; flow:to_server,established; content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A|"; fast_pattern; content:"|21 11|"; distance:0; within:2; content:"|AC 1F 10 24|"; distance:4; within:4; classtype:not-suspicious; sid:420020003; rev:1;)
```

**Why those distances?**

* After magic (12 bytes), we matched `|21 11|` (2 bytes).
* Next are **2 bytes length**, then the **address block** starts.
* The first 4 bytes of the address block are **source IPv4**. So from the end of `|21 11|`, we `distance:4` (skip length + first 0 bytes into addr) and match the 4-byte source IP `AC 1F 10 24` (172.31.16.36).

*(Alternative form mirroring the spec more literally: use `distance:2; within:4` to first skip the 2-byte length, then match the 4-byte src IP. If you prefer that, swap `distance:4` with `distance:2; within:4`.)*

---

### 4) Detect **LOCAL** command (no client IP/ports carried)

```suricata
alert tcp any any -> any any (msg:"PPv2 LOCAL (no proxied address block)"; flow:to_server,established; content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A|"; fast_pattern; content:"|20 00|"; distance:0; within:2; classtype:not-suspicious; sid:420020004; rev:1;)
```

---

### 5) (Optional) Detect **AWS VPC Endpoint ID TLV** (`type 0xEA`, subtype `0x01`, value starts `"vpce-"`)

```suricata
alert tcp any any -> any any (msg:"PPv2 AWS VPC Endpoint TLV (vpce-...)"; flow:to_server,established; content:"|0D 0A 0D 0A 00 0D 0A 51 55 49 54 0A|"; fast_pattern; content:"|EA|"; distance:0; within:64; content:"|01|"; distance:1; within:1; content:"vpce-"; nocase; distance:0; within:64; classtype:policy; sid:420020005; rev:1;)
```

* This is a heuristic that looks for TLV type `EA`, then subtype `01`, then ASCII `vpce-` nearby. It’s tolerant to varying TLV lengths.

---

#### Notes & Tips

* These rules assume **stateful inline** (for `drop`) and that your sensor is **before** the backend parses PPv2.
* If `$HOME_NET` isn’t defined in AWS Network Firewall, replace it with explicit CIDRs.
* Keep rule performance healthy by leaving the **magic** as the `fast_pattern` anchor (as above).

Want me to tailor #3 for **multiple source IPs** (e.g., a small list) without duplicating rules? I can convert that match into a compact `pcre` or chained `content` set.
