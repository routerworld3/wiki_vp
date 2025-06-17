To set up **SNS alerts for GuardDuty findings at the Organization Level** in a **central security account**, follow this architecture and implementation logic:

---

## 🔍 **High-Level Logic**

1. **GuardDuty is enabled at the Org level**:

   * The central account is the delegated admin.
   * All member accounts send their findings to the central account.

2. **Enable CloudWatch Event rule** (now Amazon EventBridge):

   * Trigger on any new GuardDuty findings (`guardduty:Finding` event pattern).
   * Filter based on severity or type, if desired.

3. **Send notifications via SNS**:

   * EventBridge rule sends matching findings to an SNS topic.
   * SNS topic delivers notifications (e.g., email, Lambda, or ticketing system).

---

## 🧠 **Implementation Steps**

### 1. **SNS Topic and Subscription**

```hcl
resource "aws_sns_topic" "guardduty_alerts" {
  name = "guardduty-findings-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = "security-team@example.com"
}
```

---

### 2. **EventBridge Rule for GuardDuty Findings**

```hcl
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings-rule"
  description = "Trigger on GuardDuty Findings"
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"]
  })
}
```

---

### 3. **EventBridge Target to SNS**

```hcl
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.guardduty_alerts.arn
}
```

---

### 4. **Allow EventBridge to Publish to SNS**

```hcl
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn    = aws_sns_topic.guardduty_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowEventBridge",
        Effect    = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action    = "sns:Publish",
        Resource  = aws_sns_topic.guardduty_alerts.arn
      }
    ]
  })
}
```

---

## 🧪 (Optional) **Filter for High Severity Only**

If you only want **high severity** alerts:

```hcl
event_pattern = jsonencode({
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"],
  "detail": {
    "severity": [{
      "numeric": [">=", 7.0]
    }]
  }
})
```

---

## ✅ **Verification Checklist**

* ✅ GuardDuty delegated admin is enabled in central account.
* ✅ EventBridge rule triggers on findings.
* ✅ SNS topic created and subscribed (e.g., email confirmed).
* ✅ IAM policies allow EventBridge to publish to SNS.

---

Let me know if you'd like to **filter by specific finding types**, or **forward to Lambda or Security Hub instead of SNS**.
