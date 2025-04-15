> var.app_config

> var.app_config["dev"]["region"]

> var.app_config["prod"]["tags"]

> var.app_config["prod"]["tags"]["team"]

> length(var.app_config["prod"]["ports"])

> join(",", var.app_config["dev"]["ports"])


Yes! While Terraform’s console isn’t as dynamic as Python’s, it **does support listing keys, values, and key-value pairs** for maps and nested structures using built-in functions like:

- `keys(map)`
- `values(map)`
- `for k, v in map : ...`
- `lookup(map, key, default)`

---

## ✅ Example: Listing Keys, Values, and Key-Value Pairs

Given the following structure (from your test):

```hcl
var.app_config = {
  dev = {
    region = "us-west-1"
    tags = {
      env  = "dev"
      team = "app-team"
    }
    ports = [8080, 8081]
  },
  prod = {
    region = "us-east-1"
    tags = {
      env  = "prod"
      team = "infra"
    }
    ports = [80, 443]
  }
}
```

---

### 🔑 Get Top-Level Keys

```hcl
> keys(var.app_config)
[
  "dev",
  "prod",
]
```

---

### 📦 Get Nested Keys (e.g., `tags` under `prod`)

```hcl
> keys(var.app_config["prod"]["tags"])
[
  "env",
  "team",
]
```

---

### 📄 Get Values

```hcl
> values(var.app_config["dev"]["tags"])
[
  "dev",
  "app-team",
]
```

---

### 🗂 Iterate Key-Value Pairs

```hcl
> [for k, v in var.app_config["dev"]["tags"] : "${k} = ${v}"]
[
  "env = dev",
  "team = app-team",
]
```

You can also get a full nested list:

```hcl
> [for env, config in var.app_config : "${env} uses region ${config.region}"]
[
  "dev uses region us-west-1",
  "prod uses region us-east-1",
]
```

---

### ❗ Bonus: Safe Lookup

```hcl
> lookup(var.app_config["dev"]["tags"], "owner", "n/a")
"n/a"
```

---
