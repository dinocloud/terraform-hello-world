#Requiring a minimum Terraform version to execute a configuration
terraform {
  required_version = "> 0.11.13"

  backend "s3" {
    bucket  = "terraform-hello-world"
    key     = "devops/terraform.tfstate"
    region  = "us-east-1"
    encrypt = "true"
  }
}

#The provider variables for used the services
provider "aws" {
  version = "~> 2.0.0 "
  region  = "us-east-1"
}


resource "aws_subnet" "public-1a" {
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.10.0/24"
  vpc_id            = "${aws_vpc.main.id}"
}
resource "aws_subnet" "private-1a" {
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.20.0/24"
  vpc_id            = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public-1a" {
  vpc_id           = "${aws_vpc.main.id}"
}

resource "aws_route_table" "private-1a" {
  vpc_id           = "${aws_vpc.main.id}"
}

resource "aws_route_table_association" "route_private_ngw" {
  subnet_id      = "${aws_subnet.private-1a.id}"
  route_table_id = "${aws_route_table.private-1a.id}"
}

resource "aws_route_table_association" "route_public_igw" {
  subnet_id      = "${aws_subnet.public-1a.id}"
  route_table_id = "${aws_route_table.public-1a.id}"
}

resource "aws_route" "gw" {
  route_table_id         = "${aws_route_table.public-1a.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_route" "ngw" {
  route_table_id         = "${aws_route_table.private-1a.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.ngw.id}"
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = "${aws_subnet.public-1a.id}"
  allocation_id = "${aws_eip.main.id}"
}

resource "aws_eip" "main" {
  vpc   = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_vpc" "main" {
  cidr_block                       = "10.0.0.0/16"
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = "false"
  enable_classiclink               = "false"
  enable_dns_hostnames             = "false"
  enable_classiclink_dns_support   = "false"
}

resource "aws_instance" "web" {
  ami           = "ami-0abcb9f9190e867ab"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  subnet_id = "${aws_subnet.private-1a.id}"
  user_data_base64 = "${base64encode(data.template_file.userdata.rendered)}"

  tags = {
    Name = "terraform-hello-world"
  }
}

data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.sh.tpl")}"
}
