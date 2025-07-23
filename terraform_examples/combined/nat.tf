resource "aws_nat_gateway" "nat_gw_a" {
 connectivity_type = "private"
 subnet_id         = aws_subnet.egress["nat_a"].id
 private_ip = "140.140.1.10"# this are dummy IP 
#  secondary_private_ip_address_count = 2
#  secondary_private_ip_addresses = "140.140.1.12"
}

resource "aws_nat_gateway" "nat_gw_b" {
 connectivity_type = "private"
 subnet_id         = aws_subnet.egress["nat_b"].id
 private_ip = "140.140.1.135" # This are dummy IP 
#  secondary_private_ip_address_count = 2
#  secondary_private_ip_addresses = "140.140.1.12"
}
