data "aws_vpcs" "all" { }

resource "aws_cloudwatch_log_group" "resolver_query_log" {
  name              = "/aws/route53/resolver/query-logs"
  retention_in_days = 90
  }
  
resource "aws_route53_resolver_query_log_config" "query_log_config" {
  name            = "route53-query-logs"
  destination_arn = aws_cloudwatch_log_group.resolver_query_log.arn
}

resource "aws_route53_resolver_query_log_config_association" "query_log_assoc" {
  for_each                     = toset(data.aws_vpcs.all.ids)
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.query_log_config.id
  resource_id                  = each.value
}
