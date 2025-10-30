#############################################
# Variables (tune these per environment)
#############################################

variable "waf_name" {
  type    = string
  default = "Ent_Bus_App"
}

variable "scope" {
  type    = string
  default = "REGIONAL" # or "CLOUDFRONT"
}

variable "cloudwatch_log_name" {
  type    = string
  default = "/aws/wafv2/Ent_Bus_App"
}

# App-owned allow rules (NLB→ALB health check + readiness)
variable "alb_health_user_agent_substring" {
  type    = string
  default = "ELB-HealthChecker"
}

variable "nlb_health_source_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"] # replace with your NLB sources
}

variable "internal_hc_path" {
  type    = string
  default = "/internal-hc" # recommend dedicated path on 4443
}

variable "readiness_regex" {
  type    = string
  default = "^/(health|healthz|ready|live)$"
}

# Enterprise pack inputs (taken from your JSON; override to your ARNs / lists)
variable "ipset_ipv4_allow_arn" {
  type    = string
  default = "arn:aws-us-gov:wafv2:us-gov-west-1:123412341234:regional/ipset/Ent_Bus_App_IPV4_Allow/8e4c9d21-e2a8-4bf7-8d93-199d3e43739f"
}

variable "ipset_ipv6_allow_arn" {
  type    = string
  default = "arn:aws-us-gov:wafv2:us-gov-west-1:123412341234:regional/ipset/Ent_Bus_App_IPV6_Allow/c4f417ad-067f-48cc-8591-27f685fc848b"
}

variable "ipset_ipv4_block_arn" {
  type    = string
  default = "arn:aws-us-gov:wafv2:us-gov-west-1:123412341234:regional/ipset/Ent_Bus_App_IPV4_Block/e8d5fd36-fea9-40c3-9ec2-1b71b920f334"
}

variable "ipset_ipv6_block_arn" {
  type    = string
  default = "arn:aws-us-gov:wafv2:us-gov-west-1:123412341234:regional/ipset/Ent_Bus_App_IPV6_Block/36b2c6cd-f353-42d3-a562-3b582588d567"
}

# Countries to block (GeoRule)
variable "geo_block_countries" {
  type    = list(string)
  default = ["CU", "IR", "KP", "RU", "SY", "VE"]
}

# Rate limits (pack JSON)
variable "rate_limit_global" {
  type    = number
  default = 1000
}

variable "rate_limit_get" {
  type    = number
  default = 500
}

variable "rate_limit_post_put_delete" {
  type    = number
  default = 100
}

# Body size constraint (pack JSON: 16384, oversize MATCH)
variable "body_size_limit_bytes" {
  type    = number
  default = 16384
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Project   = "WAF"
    ManagedBy = "terraform"
  }
}

#############################################
# Logging destination
#############################################

resource "aws_cloudwatch_log_group" "waf" {
  name              = var.cloudwatch_log_name
  retention_in_days = 30
  tags              = var.tags
}

#############################################
# Helper objects: readiness regex, NLB source IP set
#############################################

resource "aws_wafv2_regex_pattern_set" "readiness_paths" {
  name        = "${var.waf_name}-readiness-paths"
  description = "K8s/Istio readiness/health paths"
  scope       = var.scope

  regular_expression {
    regex_string = var.readiness_regex
  }

  tags = var.tags
}

resource "aws_wafv2_ip_set" "nlb_health_sources" {
  name               = "${var.waf_name}-nlb-health-sources"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.nlb_health_source_cidrs
  tags               = var.tags
}

#############################################
# Main Web ACL
#############################################

resource "aws_wafv2_web_acl" "this" {
  name        = var.waf_name
  scope       = var.scope
  description = "Enterprise Business App WAF (pack + app-owned rules)"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.waf_name
    sampled_requests_enabled   = true
  }

  ########################################################
  # ====== App-owned rules (keep low priorities) ======
  ########################################################

  # (5) Allow internal NLB→ALB health checks (port 4443 path)
  rule {
    name     = "AllowInternalNLBHealthChecks"
    priority = 5

    action {
      allow {}
    }

    statement {
      and_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.nlb_health_sources.arn
          }
        }

        statement {
          byte_match_statement {
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = var.alb_health_user_agent_substring

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        # recommend a distinct path for 4443
        statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "EXACTLY"
            search_string         = var.internal_hc_path

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowInternalNLBHealthChecks"
      sampled_requests_enabled   = true
    }
  }

  # (10) Allow readiness paths (K8s/Istio) via regex pattern set
  rule {
    name     = "AllowReadinessPaths"
    priority = 10

    action {
      allow {}
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.readiness_paths.arn

        field_to_match {
          uri_path {}
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowReadinessPaths"
      sampled_requests_enabled   = true
    }
  }

  ########################################################
  # ====== Enterprise Pack rules (mapped from JSON) ======
  # Priorities start at 100 to keep space for app rules
  ########################################################

  # (100) AWSManagedRulesAntiDDoSRuleSet – Count, with client-side Challenge config
  rule {
    name     = "AWS-AWSManagedRulesAntiDDoSRuleSet"
    priority = 100

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAntiDDoSRuleSet"

        # managed_rule_group_configs {
        #   aws_managed_rules_anti_ddos_rule_set {
        #     client_side_action_config {
        #       challenge {
        #         sensitivity      = "HIGH"
        #         usage_of_action  = "ENABLED"

        #         exempt_uri_regex {
        #           regex_string = "\\/api\\/|\\.(acc|avi|css|gif|ico|jpe?g|js|json|mp[34]|ogg|otf|pdf|png|tiff?|ttf|webm|webp|woff2?|xml)$"
        #         }
        #       }
        #     }

        #     # sensitivity_to_block = "LOW"
        #   }
        # }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAntiDDoSRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # (101) IPv4 Allow list
  rule {
    name     = "Ent_Bus_App_IPV4_Allow"
    priority = 101

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = var.ipset_ipv4_allow_arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Ent_Bus_App_IPV4_Allow"
      sampled_requests_enabled   = true
    }
  }

  # (102) IPv6 Allow list
  rule {
    name     = "Ent_Bus_App_IPV6_Allow"
    priority = 102

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = var.ipset_ipv6_allow_arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Ent_Bus_App_IPV6_Allow"
      sampled_requests_enabled   = true
    }
  }

  # (103) IPv4 Block list
  rule {
    name     = "Ent_Bus_App_IPV4_Block"
    priority = 103

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = var.ipset_ipv4_block_arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Ent_Bus_App_IPV4_Block"
      sampled_requests_enabled   = true
    }
  }

  # (104) IPv6 Block list
  rule {
    name     = "Ent_Bus_App_IPV6_Block"
    priority = 104

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = var.ipset_ipv6_block_arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Ent_Bus_App_IPV6_Block"
      sampled_requests_enabled   = true
    }
  }

  # (105) Geo block
  rule {
    name     = "GeoRule"
    priority = 105

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = var.geo_block_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoRule"
      sampled_requests_enabled   = true
    }
  }

  # (106) Global rate-based rule – Count (window 300s, limit var.rate_limit_global)
  rule {
    name     = "GlobalRateBasedRule"
    priority = 106

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
        limit                 = var.rate_limit_global
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GlobalRateBasedRule"
      sampled_requests_enabled   = true
    }
  }

  # (107) GET rate-based rule – Count (limit var.rate_limit_get), scope-down Method == GET
  rule {
    name     = "RateBasedRuleGET"
    priority = 107

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
        limit                 = var.rate_limit_get

        scope_down_statement {
          byte_match_statement {
            field_to_match {
              method {}
            }
            positional_constraint = "EXACTLY"
            search_string         = "GET"

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRuleGET"
      sampled_requests_enabled   = true
    }
  }

  # (108) POST/PUT/DELETE rate-based rule – Count (limit var.rate_limit_post_put_delete)
  rule {
    name     = "RateBasedRulePOST"
    priority = 108

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
        limit                 = var.rate_limit_post_put_delete

        scope_down_statement {
          or_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "POST"

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }

            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "PUT"

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }

            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "DELETE"

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRulePOST"
      sampled_requests_enabled   = true
    }
  }

  # (109) Body size restriction > var.body_size_limit_bytes, oversize_handling = MATCH
  rule {
    name     = "BodySizeRestrictionRule"
    priority = 109

    statement {
      size_constraint_statement {
        comparison_operator = "GT"
        size                = var.body_size_limit_bytes

        field_to_match {
          body {
            oversize_handling = "MATCH"
          }
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BodySizeRestrictionRule"
      sampled_requests_enabled   = true
    }
  }

  # (110) Amazon IP Reputation – enforce with RuleActionOverrides
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 110

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"

        rule_action_override {
          name = "AWSManagedReconnaissanceList"

          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "AWSManagedIPDDoSList"

          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # (111) Managed IP DDoS RateLimit – Count (label scope-down)
  rule {
    name     = "ManagedIPDDoSRateLimit"
    priority = 111

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
        limit                 = var.rate_limit_global

        scope_down_statement {
          label_match_statement {
            scope = "LABEL"
            key   = "awswaf:managed:aws:amazon-ip-list:AWSManagedIPDDoSList"
          }
        }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ManagedIPDDoSRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # (112) Anonymous IP list – enforce
  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 112

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAnonymousIpList"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # (113) CommonRuleSet – enforce (flip to count {} if tuning)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 113

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # (114) KnownBadInputs – enforce
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 114

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # (115) SQLi – enforce
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 115

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # (116) Linux – enforce
  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 116

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesLinuxRuleSet"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # (117) Bot Control – Count; InspectionLevel COMMON
  rule {
    name     = "AWS-AWSManagedRulesBotControlRuleSet"
    priority = 117

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesBotControlRuleSet"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesBotControlRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags

  # If you will also attach additional groups via *_association resources,
  # uncomment the lifecycle block to avoid drift:
  # lifecycle {
  #   ignore_changes = [rule]
  # }

  # Optional (provider/account support required)
  # on_source_ddos_protection_config {
  #   alb_low_reputation_mode = "ACTIVE_UNDER_DDOS"
  # }
}

#############################################
# Logging
#############################################

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

