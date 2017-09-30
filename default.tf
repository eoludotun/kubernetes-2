# The main variables you should need to change.
# general vars are in variables.tf

# default network bootstrap for us-east-1

variable "nametag" {
    default = "beta-us-east-1"
}

variable "vpc_cidr" {
    default = "172.30.0.0/16"
}

variable "region" {
    default = "us-east-1"
}

provider "aws" {
   region = "${var.region}"
   profile                  = "beta-us-east-1"
}

# create the vpc
resource "aws_vpc" "beta-us-east-1" {
   cidr_block = "${var.vpc_cidr}"
   enable_dns_support = true
   enable_dns_hostnames = true
   tags {
     Name = "${var.nametag}"
   }
}

# create DNS zone
resource "aws_route53_zone" "primary" {
  name = "${var.nametag}.local"
  vpc_id = "${aws_vpc.beta-us-east-1.id}"
}

# dhcp options
resource "aws_vpc_dhcp_options" "beta-us-east-1" {
   domain_name = "${var.nametag}.local"
   domain_name_servers = ["AmazonProvidedDNS"]
   tags {
       Name = "${var.nametag}"
   }
}


resource "aws_vpc_dhcp_options_association" "dns_resolver" {
   vpc_id = "${aws_vpc.beta-us-east-1.id}"
   dhcp_options_id = "${aws_vpc_dhcp_options.beta-us-east-1.id}"
}

# # the default is a /26, we'll give the public subnets less IPs
# data "external" "pub_subnets" {
#   program = ["${path.module}/aws-cidr-cli.py"]
#   query = {
#     label = "beta-us-east-1-public"
#     vpc = "${lookup(var.vpc_cidr, var.region)}"
#     prefix = "27"
#   }
# }
#
# # the default is a /26, we'll give the public subnets less IPs
# data "external" "priv_subnets" {
#   program = ["${path.module}/aws-cidr-cli.py"]
#   query = {
#     label = "beta-us-east-1-private"
#     vpc = "${lookup(var.vpc_cidr, var.region)}"
#   }
# }
#
# # create subnets and routes
# resource "aws_subnet" "beta-us-east-1-public" {
#    vpc_id = "${aws_vpc.beta-us-east-1.id}"
#    availability_zone = "us-east-1b"
#    map_public_ip_on_launch = true
#    cidr_block = "${data.external.pub_subnets.result.beta-us-east-1-public}"
#    tags {
#       Name = "${var.nametag}-us-east-1b-public"
#    }
# }
#
# # create subnets and routes
# resource "aws_subnet" "beta-us-east-1-private" {
#    vpc_id = "${aws_vpc.beta-us-east-1.id}"
#    availability_zone = "us-east-1b"
#    map_public_ip_on_launch = true
#    cidr_block = "${data.external.priv_subnets.result.beta-us-east-1-private}"
#    tags {
#       Name = "${var.nametag}-us-east-1b-private"
#    }
# }
#
# resource "aws_route_table_association" "beta-us-east-1-public" {
#   subnet_id      = "${aws_subnet.beta-us-east-1-public.id}"
#   route_table_id = "${aws_route_table.public.id}"
# }
#
# resource "aws_route_table_association" "beta-us-east-1-private" {
#   subnet_id      = "${aws_subnet.beta-us-east-1-private.id}"
#   route_table_id = "${aws_route_table.private.id}"
# }

# create a gateway for public systems
resource "aws_internet_gateway" "beta-us-east-1" {
   vpc_id = "${aws_vpc.beta-us-east-1.id}"
   tags {
      Name = "${var.nametag}-gw"
   }
}


# the nat for private systems needs an elastic IP
resource "aws_eip" "nat" {
  vpc = true
}

# create the NAT for the private systems
# resource "aws_nat_gateway" "beta-us-east-1" {
#   allocation_id = "${aws_eip.nat.id}"
#   subnet_id     = "${aws_subnet.beta-us-east-1-public.id}"
# }

# create public route table
resource "aws_route_table" "public" {
   vpc_id = "${aws_vpc.beta-us-east-1.id}"
   route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.beta-us-east-1.id}"
   }
   tags {
      Name = "${var.nametag}-public-routes"
   }
}

# resource "aws_route_table" "private" {
#    vpc_id = "${aws_vpc.beta-us-east-1.id}"
#    route {
#       cidr_block = "0.0.0.0/0"
#       gateway_id = "${aws_nat_gateway.beta-us-east-1.id}"
#    }
#    tags {
#       Name = "${var.nametag}-private"
#    }
# }

# use the public route table for the default VPC
resource "aws_main_route_table_association" "beta-us-east-1" {
   vpc_id = "${aws_vpc.beta-us-east-1.id}"
   route_table_id = "${aws_route_table.public.id}"
}

# we also won't create  load balancer, but this is what it'd look like..

# # Create a new load balancer
# resource "aws_elb" "beta-us-east-1" {
#   name = "${var.nametag}"
#   security_groups = ["${aws_security_group.beta-us-east-1.id}"]
#   subnets = ["${aws_subnet.beta-us-east-1.id}"]
#   listener {
#     instance_port = 6443
#     instance_protocol = "tcp"
#     lb_port = 6443
#     lb_protocol = "tcp"
#   }
#   tags {
#     Name = "${var.nametag}"
#   }
# }
