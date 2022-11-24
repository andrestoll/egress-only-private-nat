# ----------------------- VPC Peering --------------------

resource "aws_vpc_peering_connection" "destination_source_overlap" {
  peer_vpc_id   = aws_vpc.destination.id
  vpc_id        = aws_vpc.overlap.id
  auto_accept = true
}

# ---------------------- Test TGW -----------------------
resource "aws_ec2_transit_gateway" "tgw_test" {
  default_route_table_association = "disable"
  tags = {
    App = local.name
    Name = "TWG-Test-Dest"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "intermediary_test" {
  subnet_ids         = [aws_subnet.intermediary_nat_az1.id, aws_subnet.intermediary_nat_az2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
  vpc_id             = aws_vpc.intermediary.id
  transit_gateway_default_route_table_association = false
  tags = {
    App = local.name
    Name = "Egress-RT-Att-Test"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dest_test" {
  subnet_ids         = [aws_subnet.destination_az1.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
  vpc_id             = aws_vpc.destination.id
  transit_gateway_default_route_table_association = false
  tags = {
    App = local.name
    Name = "Dest-RT-Att-Test"
  }
}

resource "aws_ec2_transit_gateway_route_table" "egress_test" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
  tags = {
    App = local.name
    Name = "Egress-RT-Test"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "intermediary_test" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.intermediary_test.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress_test.id
}

resource "aws_ec2_transit_gateway_route" "egress_test" {
  destination_cidr_block         = local.vpc_cidr_destination
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dest_test.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress_test.id
}

resource "aws_ec2_transit_gateway_route_table" "app_test" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
  tags = {
    App = local.name
    Name = "App-RT-Test"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "app_test" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dest_test.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app_test.id
}

resource "aws_ec2_transit_gateway_route" "app_test" {
  destination_cidr_block         = local.vpc_cidr_destination
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.intermediary_test.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app_test.id
}

resource "aws_route" "intermediary_tgw_test" {
  route_table_id            = aws_vpc.destination.main_route_table_id
  destination_cidr_block    = local.vpc_cidr_intermediary
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
}

resource "aws_route" "dest_tgw_test" {
  route_table_id            = aws_route_table.intermediary_egress.id
  destination_cidr_block    = local.vpc_cidr_destination
  transit_gateway_id = aws_ec2_transit_gateway.tgw_test.id
}