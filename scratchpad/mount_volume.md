

# 🧾 Full fstab entry explained

```bash
UUID=<uuid> /opt/sc xfs defaults,nofail,_netdev,x-systemd.automount 0 2
```

### 1️⃣ `UUID=<uuid>`

* Identifies the disk (instead of `/dev/xvdf`, which can change in AWS)
* Must match exactly from `blkid`

---

### 2️⃣ `/opt/sc`

* Mount point (directory where filesystem is attached)

---

### 3️⃣ `xfs`

* Filesystem type

---

### 4️⃣ `defaults,nofail,_netdev,x-systemd.automount`

This is where most of the behavior is controlled:

#### ✅ `defaults`

Equivalent to:

```bash
rw,suid,dev,exec,auto,nouser,async
```

---

#### ✅ `nofail`

* **Do NOT fail boot if mount fails**
* BUT… important nuance (explained below)

---

#### ✅ `_netdev`

* Tells systemd: *“this device may not be ready immediately”*
* Very important for:

  * AWS EBS
  * iSCSI
  * network-backed storage

---

#### ✅ `x-systemd.automount`

* Creates a systemd automount unit
* Mount happens **only when accessed**, not during boot

👉 This is the safest option in cloud environments

---

# 🔢 What does `0 2` mean?

These are the **last two fstab fields**:

---

## 5️⃣ First number → `dump` (backup flag)

```bash
0
```

* Used by old `dump` backup utility
* Almost always:

  * `0` = ignore (modern standard)

---

## 6️⃣ Second number → `fsck order`

```bash
2
```

Controls filesystem check order at boot:

| Value | Meaning                        |
| ----- | ------------------------------ |
| 0     | Do NOT check                   |
| 1     | Check first (usually root `/`) |
| 2     | Check after root               |

👉 For XFS:

* fsck is basically a no-op
* `2` is fine (or even `0`)

---

# ❗ Why `nofail` did NOT prevent boot failure

This is the part that trips up even experienced engineers.

---

## 🔴 Key point:

👉 `nofail` only prevents **hard failure**, NOT **blocking/timeouts**

---

### What likely happened:

At boot:

1. systemd tries to mount `/opt/sc`
2. EBS device is **not ready yet**
3. systemd **waits for device**
4. timeout or dependency failure occurs
5. system drops into **emergency mode**
6. root login appears “locked”

---

### ⚠️ Why `nofail` didn’t help:

Because:

* `nofail` ≠ “skip immediately”
* systemd still tries to mount
* it can still **wait and hang**

---

# 🧠 Think of it like this

| Option      | Behavior                                   |
| ----------- | ------------------------------------------ |
| `nofail`    | “If it fails, don’t panic”                 |
| `_netdev`   | “This might not be ready yet”              |
| `automount` | “Don’t mount now, mount later when needed” |

👉 You only used the first one.

---

# ✅ Why `automount` fixes everything

With:

```bash
x-systemd.automount
```

### Boot behavior:

* system does NOT mount `/opt/sc` immediately
* boot continues normally
* when something accesses `/opt/sc` → THEN mount happens

👉 No blocking
👉 No timeout
👉 No emergency mode

---

# 🛠️ Recommended production-safe entry (AWS)

```bash
UUID=<uuid> /opt/sc xfs defaults,nofail,_netdev,x-systemd.automount,x-systemd.device-timeout=30 0 2
```

---

# 🔍 Quick validation before reboot (important)

Run:

```bash
mount -a
systemctl daemon-reexec
systemctl restart local-fs.target
```

If no errors → safe to reboot

---

# 🎯 Bottom line

* `0` → ignore dump backup
* `2` → fsck order (after root)
* `nofail` alone is NOT enough in AWS
* You need:

  * `_netdev` (device timing)
  * OR `automount` (best option)

---

