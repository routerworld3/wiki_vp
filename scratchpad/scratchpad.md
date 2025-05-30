# ─── In the member / workload account ─────────────────────────────
resource "aws_iam_role" "cwl_org_subscription" {
  name               = "CWLOrgSubscription"
  description        = "Role CWL assumes when sending logs to central destination"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.${var.region}.amazonaws.com" }   # GovCloud still uses amazonaws.com
      Action    = "sts:AssumeRole"
    }]
  })
}

# The permission doesn’t matter much—CWL only checks that **some**
# policy is present.  The example from AWS docs uses PutLogEvents:
resource "aws_iam_role_policy" "cwl_org_subscription" {
  role   = aws_iam_role.cwl_org_subscription.id
  name   = "AllowPutLogEvents"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:PutLogEvents"]
      Resource = "arn:aws-us-gov:logs:${var.region}:${data.aws_caller_identity.self.account_id}:log-group:*"
    }]
  })
}
