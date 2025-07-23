resource "aws_lb" "nipr_alb_test" {
  name               = "nipr-alb-test"
  internal           = true
  load_balancer_type = "application"
  #subnets            = tolist(aws_subnet.w_egress_internet_public[*].id)

  subnets = [
    aws_subnet.ingress["alb_a"].id,
    aws_subnet.ingress["alb_b"].id,
  ]
  #subnets                                     = [aws_subnet.w_egress_internet_public[*].id]
  security_groups                             = [aws_security_group.alb_sg.id]
  desync_mitigation_mode                      = "defensive"
  drop_invalid_header_fields                  = true
  enable_cross_zone_load_balancing            = true
  enable_deletion_protection                  = false
  enable_http2                                = true
  enable_tls_version_and_cipher_suite_headers = true
  enable_waf_fail_open                        = false
  enable_xff_client_port                      = true
  idle_timeout                                = 60
  ip_address_type                             = "ipv4"
  preserve_host_header                        = false
  xff_header_processing_mode                  = "append"
  depends_on        = [aws_vpc_ipv4_cidr_block_association.ingress_secondary]

}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.ingress.id
   name        = "allow_tls"
}





resource "aws_lb" "nipr_nlb_test" {
  name               = "nipr-nlb-test"
  internal           = true
  load_balancer_type = "network"
  #subnets            = tolist(aws_subnet.w_egress_internet_public[*].id)
  subnet_mapping {
    subnet_id            =   aws_subnet.ingress["alb_a"].id
    private_ipv4_address = "10.0.1.15"
  }

  subnet_mapping {
    subnet_id            =     aws_subnet.ingress["alb_b"].id
    private_ipv4_address = "10.0.2.15"
  }

  #subnets                                     = [aws_subnet.w_egress_internet_public[*].id]
  security_groups                             = [aws_security_group.alb_sg.id]
  desync_mitigation_mode                      = "defensive"
  drop_invalid_header_fields                  = true
  enable_cross_zone_load_balancing            = true
  enable_deletion_protection                  = true
  enable_http2                                = true
  enable_tls_version_and_cipher_suite_headers = true
  enable_waf_fail_open                        = false
  enable_xff_client_port                      = true
  idle_timeout                                = 60
  ip_address_type                             = "ipv4"
  preserve_host_header                        = false
  xff_header_processing_mode                  = "append"
  depends_on        = [aws_vpc_ipv4_cidr_block_association.ingress_secondary]

}

