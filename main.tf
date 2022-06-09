# access your aws account
provider "aws" {
  region     = "eu-west-1"
  access_key = "AKIAQVY46PFJCHDDVV5X"
  secret_key = "MyP3YoRDnYU4ZBAgb45pAzmpBJdrp2ix/iVqozHM"
}
# create your vpc
resource "aws_vpc" "firstvpc" {
  #   vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/16"
  # add a name to it
  tags = {
    Name = "production"
  }
}
# create internet gateway 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.firstvpc.id
}

# create route table
resource "aws_route_table" "firstroute" {
  vpc_id = aws_vpc.firstvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "firstroute"
  }
}
# create subnet
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.firstvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Main"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.firstroute.id
}
# create a security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.firstvpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# create a network interface
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
# assign an elastic ip to the network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}
output "server_ip" {
  value = aws_eip.one.public_ip
}

# create ubuntu server
resource "aws_instance" "web-server-instance" {
  ami               = "ami-07d8796a2b0f8d29c"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-1a"
  key_name          = "webkey"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install apache2 -y
                
                
                sudo systemctl start apache2
                sudo bash -c 'echo "Hello World from first web server" > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web_server"
  }
}



  