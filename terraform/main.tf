locals {
  name = "TGW-Single-Exit"
  region = "eu-central-1"

  vpc_cidr_source = "10.0.0.0/16"
  subnet_cidr_source_1 = "10.0.0.0/24"
  vpc_cidr_intermediary = "192.168.0.0/16"
  subnet_cidr_intermediary_1 = "192.168.0.0/24"
  subnet_cidr_intermediary_2 = "192.168.1.0/24"
  subnet_cidr_intermediary_3 = "192.168.2.0/24"
  subnet_cidr_intermediary_4 = "192.168.3.0/24"
  vpc_cidr_destination = "10.1.0.0/16"
  subnet_cidr_destination_1 = "10.1.0.0/24"
  vpc_cidr_source_overlap = "10.0.0.0/16"
  subnet_cidr_overlap_1 = "10.0.0.0/24"

  vpc_cidr_blackhole_1 = local.vpc_cidr_intermediary
  vpc_cidr_blackhole_2 = "172.16.0.0/12"
  vpc_cidr_blackhole_3 = "10.0.0.0/8"

  azs = flatten(data.aws_availability_zones.available[*].names)
}

data "aws_availability_zones" "available" {}

# ----------------------- VPC & Subnets --------------------------

resource "aws_vpc" "source" {
  cidr_block = local.vpc_cidr_source
  tags = {
    Name = "source"
    App = local.name
  }
}

resource "aws_subnet" "source_az1" {
  vpc_id = aws_vpc.source.id
  availability_zone = local.azs[0]
  cidr_block = local.subnet_cidr_source_1
  tags = {
    Name = "source-az1"
    App = local.name
  }
}

resource "aws_vpc" "intermediary" {
  cidr_block = local.vpc_cidr_intermediary
  tags = {
    Name = "intermediary"
    App = local.name
  }
}

resource "aws_subnet" "intermediary_tgw_attach_az1" {
  vpc_id = aws_vpc.intermediary.id
  availability_zone = local.azs[0]
  cidr_block = local.subnet_cidr_intermediary_1
  tags = {
    Name = "inter-tgw-az1"
    App = local.name
  }
}

resource "aws_subnet" "intermediary_nat_az1" {
  vpc_id = aws_vpc.intermediary.id
  availability_zone = local.azs[0]
  cidr_block = local.subnet_cidr_intermediary_2
  tags = {
    Name = "inter-nat-az1"
    App = local.name
  }
}

resource "aws_subnet" "intermediary_tgw_attach_az2" {
  vpc_id = aws_vpc.intermediary.id
  availability_zone = local.azs[1]
  cidr_block = local.subnet_cidr_intermediary_3
  tags = {
    Name = "inter-tgw-az2"
    App = local.name
  }
}

resource "aws_subnet" "intermediary_nat_az2" {
  vpc_id = aws_vpc.intermediary.id
  availability_zone = local.azs[1]
  cidr_block = local.subnet_cidr_intermediary_4
  tags = {
    Name = "inter-nat-az2"
    App = local.name
  }
}

resource "aws_vpc" "destination" {
  cidr_block = local.vpc_cidr_destination
  tags = {
    Name = "destination"
    App = local.name
  }
}

resource "aws_subnet" "destination_az1" {
  vpc_id = aws_vpc.destination.id
  availability_zone = local.azs[0]
  cidr_block = local.subnet_cidr_destination_1
  tags = {
    Name = "dest-az1"
    App = local.name
  }
}

resource "aws_vpc" "overlap" {
  cidr_block = local.vpc_cidr_source_overlap
  tags = {
    Name = "overlap"
    App = local.name
  }
}

resource "aws_subnet" "overlap_az1" {
  vpc_id = aws_vpc.overlap.id
  availability_zone = local.azs[0]
  cidr_block = local.subnet_cidr_overlap_1
  tags = {
    Name = "overlap-az1"
    App = local.name
  }
}

# ----------------------- NAT GW --------------------------

resource "aws_nat_gateway" "nat_az1" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.intermediary_nat_az1.id
  tags = {
    App = local.name
    Name = "NGW-AZ1"
  }
}

resource "aws_nat_gateway" "nat_az2" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.intermediary_nat_az2.id
  tags = {
    App = local.name
    Name = "NGW-AZ2"
  }
}

# ----------------------- Transit GW --------------------------

resource "aws_ec2_transit_gateway" "tgw" {
  default_route_table_association = "disable"
  tags = {
    App = local.name
    Name = "TWG-Single-Exit"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  subnet_ids         = [aws_subnet.source_az1.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.source.id
  transit_gateway_default_route_table_association = false
  tags = {
    App = local.name
    Name = "App-RT-Att"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  subnet_ids         = [aws_subnet.intermediary_tgw_attach_az1.id, aws_subnet.intermediary_tgw_attach_az2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.intermediary.id
  transit_gateway_default_route_table_association = false
  tags = {
    App = local.name
    Name = "Egress-RT-Att"
  }
}

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    App = local.name
    Name = "Egress-RT"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

resource "aws_ec2_transit_gateway_route" "egress" {
  destination_cidr_block         = local.vpc_cidr_source
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}

resource "aws_ec2_transit_gateway_route_table" "app" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    App = local.name
    Name = "App-RT"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

resource "aws_ec2_transit_gateway_route" "app" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# uncomment for production
#resource "aws_ec2_transit_gateway_route" "blackhole_1" {
#  destination_cidr_block         = local.vpc_cidr_blackhole_1
#  blackhole                      = true
#  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
#}

resource "aws_ec2_transit_gateway_route" "blackhole_2" {
  destination_cidr_block         = local.vpc_cidr_blackhole_2
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

resource "aws_ec2_transit_gateway_route" "blackhole_3" {
  destination_cidr_block         = local.vpc_cidr_blackhole_3
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# ------------------------ Routes and Route Tables --------------------------

resource "aws_route" "source_tgw" {
  route_table_id            = aws_vpc.source.main_route_table_id
  destination_cidr_block    = local.vpc_cidr_destination
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route_table" "intermediary_nat_az1" {
  vpc_id = aws_vpc.intermediary.id

  route {
    cidr_block = local.vpc_cidr_destination
    nat_gateway_id = aws_nat_gateway.nat_az1.id
  }

  tags = {
    Name = "RT-NAT-AZ1"
  }
}

resource "aws_route_table_association" "nat_az1" {
  subnet_id      = aws_subnet.intermediary_tgw_attach_az1.id
  route_table_id = aws_route_table.intermediary_nat_az1.id
}

resource "aws_route_table" "intermediary_nat_az2" {
  vpc_id = aws_vpc.intermediary.id

  route {
    cidr_block = local.vpc_cidr_destination
    nat_gateway_id = aws_nat_gateway.nat_az2.id
  }

  tags = {
    Name = "RT-NAT-AZ2"
  }
}

resource "aws_route_table_association" "nat_az2" {
  subnet_id      = aws_subnet.intermediary_tgw_attach_az2.id
  route_table_id = aws_route_table.intermediary_nat_az2.id
}

resource "aws_route_table" "intermediary_egress" {
  vpc_id = aws_vpc.intermediary.id

  route {
    cidr_block = local.vpc_cidr_source
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "RT-Egress"
  }
}

resource "aws_route_table_association" "egress_az1" {
  subnet_id      = aws_subnet.intermediary_nat_az1.id
  route_table_id = aws_route_table.intermediary_egress.id
}

resource "aws_route_table_association" "egress_az2" {
  subnet_id      = aws_subnet.intermediary_nat_az2.id
  route_table_id = aws_route_table.intermediary_egress.id
}

