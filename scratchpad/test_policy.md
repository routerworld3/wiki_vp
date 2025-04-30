{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OAMPermissions",
      "Effect": "Allow",
      "Action": [
        "oam:GetSink",
        "oam:ListSinks",
        "oam:GetLink",
        "oam:ListLinks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:GetLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }
  ]
}
