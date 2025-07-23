# Common AZs and Tags
azs = ["us-gov-west-1a", "us-gov-west-1b"]

tags = {
  Environment = "test"
  Project     = "scca-niprnet"
  Owner       = "network-team"
}

# TGW and CIDR Routing
tgw_vdss_id = "tgw-0vdss123example"
tgw_edge_id = "tgw-0edge456example"

private_rfc_1918_cidr = "10.0.0.0/8"
vdss_cidr             = "10.10.0.0/16"
edge_cidr             = "0.0.0.0/0"

# -----------------------
# EGRESS VPC Configuration
# -----------------------
egress_name         = "egress-nipr"
egress_cidr_blocks  = ["10.50.0.0/16", "140.140.1.0/24"]

egress_nat_subnet_cidrs = [
  "140.140.1.0/25", # AZ-a
  "140.140.1.128/25"  # AZ-b
]

egress_tgw_vdss_subnet_cidrs = [
  "10.50.10.0/24", # AZ-a
  "10.50.11.0/24"  # AZ-b
]

egress_tgw_edge_subnet_cidrs = [
  "10.50.20.0/24", # AZ-a
  "10.50.21.0/24"  # AZ-b
]

# -----------------------
# INGRESS VPC Configuration
# -----------------------
ingress_name         = "ingress-nipr"
ingress_cidr_blocks  = ["10.60.0.0/16", "140.140.2.0/24"]

ingress_alb_subnet_cidrs = [
  "140.140.2.0/25", # AZ-a
  "140.140.2.128/25"  # AZ-b
]

ingress_tgw_vdss_subnet_cidrs = [
  "10.60.10.0/24", # AZ-a
  "10.60.11.0/24"  # AZ-b
]

ingress_tgw_edge_subnet_cidrs = [
  "10.60.20.0/24", # AZ-a
  "10.60.21.0/24"  # AZ-b
]
