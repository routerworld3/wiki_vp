variable "azs" {
  description = "List of Availability Zones to use for subnet placement"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

# -----------------------
# EGRESS VPC VARIABLES
# -----------------------

variable "egress_name" {
  description = "Name prefix for Egress VPC and resources"
  type        = string
}

variable "egress_cidr_blocks" {
  description = "List of primary and secondary CIDR blocks for Egress VPC"
  type        = list(string)
}

variable "egress_nat_subnet_cidrs" {
  description = "List of subnet CIDRs for NAT Gateway in Egress VPC (one per AZ)"
  type        = list(string)
}

variable "egress_tgw_vdss_subnet_cidrs" {
  description = "List of subnet CIDRs for VDSS TGW attachment in Egress VPC"
  type        = list(string)
}

variable "egress_tgw_edge_subnet_cidrs" {
  description = "List of subnet CIDRs for EDGE TGW attachment in Egress VPC"
  type        = list(string)
}

# -----------------------
# INGRESS VPC VARIABLES
# -----------------------

variable "ingress_name" {
  description = "Name prefix for Ingress VPC and resources"
  type        = string
}

variable "ingress_cidr_blocks" {
  description = "List of primary and secondary CIDR blocks for Ingress VPC"
  type        = list(string)
}

variable "ingress_alb_subnet_cidrs" {
  description = "List of subnet CIDRs for ALB subnets in Ingress VPC (one per AZ)"
  type        = list(string)
}

variable "ingress_tgw_vdss_subnet_cidrs" {
  description = "List of subnet CIDRs for VDSS TGW attachment in Ingress VPC"
  type        = list(string)
}

variable "ingress_tgw_edge_subnet_cidrs" {
  description = "List of subnet CIDRs for EDGE TGW attachment in Ingress VPC"
  type        = list(string)
}

# -----------------------
# SHARED TGW VARIABLES
# -----------------------

variable "tgw_vdss_id" {
  description = "Transit Gateway ID for VDSS"
  type        = string
}

variable "tgw_edge_id" {
  description = "Transit Gateway ID for EDGE"
  type        = string
}

variable "private_rfc_1918_cidr" {
  description = "CIDR block (e.g., 10.0.0.0/8) for private traffic routed via VDSS TGW"
  type        = string
}

variable "vdss_cidr" {
  description = "CIDR block for VDSS-protected resources"
  type        = string
}

variable "edge_cidr" {
  description = "CIDR block for internet traffic routed via EDGE TGW"
  type        = string
}
