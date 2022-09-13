terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "saks-vpnservice-VPC"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "saks-vpnservice-PrivateSubnet${count.index + 1}"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "saks-vpnservice-PublicSubnet${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "saks-vpnservice-IGW"
  }
}

resource "aws_route_table" "saks-vpnservice-rt-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "saks-vpnservice-rt-public"
  }
}

resource "aws_route_table_association" "saks-vpnservice-rt-public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.saks-vpnservice-rt-public.id
}

#Start section security group
resource "aws_security_group" "saks-vpnservice-SG" {
  name        = "saks-vpnservice-SG"
  description = "Allow traffic VPN Server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10447
    to_port     = 10447
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "saks-vpnservice-SG"
  }
}
#End section security group

#Start section generatre key pair
resource "tls_private_key" "oskey" {
  algorithm = "RSA"
}

resource "local_file" "saks-vpnservice-KEY" {
  content  = tls_private_key.oskey.private_key_pem
  filename = "saks-vpnservice-KEY.pem"
}

resource "aws_key_pair" "saks-vpnservice-KEY" {
  key_name   = "saks-vpnservice-KEY"
  public_key = tls_private_key.oskey.public_key_openssh
}
#End section generatre key pair

#Start section create ssm role for ec2
resource "aws_iam_instance_profile" "saks-resources-iam-profile" {
  name = "ec2_profile"
  role = aws_iam_role.saks-resources-iam-role.name
}

resource "aws_iam_role" "saks-resources-iam-role" {
  name               = "saks-ssm-role"
  description        = "The role for the developer resources EC2"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": {
"Effect": "Allow",
"Principal": {"Service": "ec2.amazonaws.com"},
"Action": "sts:AssumeRole"
}
}
EOF
  tags = {
    stack = "test"
  }
}
resource "aws_iam_role_policy_attachment" "saks-resources-ssm-policy" {
  role       = aws_iam_role.saks-resources-iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# #End section create ssm role for ec2

resource "aws_eip" "saks-vpnservice-EC2" {
  instance = aws_instance.saks-vpnservice-EC2.id
  vpc      = true
  tags = {
    Name = "saks-vpnservice-EIP"
  }
}

resource "aws_instance" "saks-vpnservice-EC2" {
  ami                         = "ami-0cff7528ff583bf9a"
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.saks-vpnservice-KEY.key_name
  vpc_security_group_ids      = [aws_security_group.saks-vpnservice-SG.id]
  iam_instance_profile        = aws_iam_instance_profile.saks-resources-iam-profile.name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets[1].id

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = 20
  }
  user_data = file("userdata.sh")
  tags = {
    Name = "saks-vpnservice-eC2"
  }
}

output "public_ip" {
  value = aws_eip.saks-vpnservice-EC2.public_ip
}
