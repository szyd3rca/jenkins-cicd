resource "aws_key_pair" "jenkins-key" {
  key_name   = "jenkins_master"
  public_key = var.ssh_key
}

resource "aws_vpc" "jenkins-prod" { #define VPC
  cidr_block = "10.0.0.0/16"


}
resource "aws_network_acl" "jenkins-vpc-acl" {
  vpc_id = aws_vpc.jenkins-prod.id

  # Ingress rule allowing all traffic
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0

  }

  # Egress rule allowing all traffic
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0

  }
}

resource "aws_default_subnet" "jenkins-default-subnet" {
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "jenkins-default-subnet"
  }
}

resource "aws_subnet" "jenkins-master-subnet" { #define master-subnet
  vpc_id                  = aws_vpc.jenkins-prod.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true


  tags = {
    Name = "jenkins-master-subnet"

  }
}
resource "aws_subnet" "jenkins-slave-subnet" { #define slave-subnet
  vpc_id            = aws_vpc.jenkins-prod.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "jenkins-slave-subnet"
  }
}
resource "aws_internet_gateway" "jenkins_igw" { #define IGW for master-subnet
  vpc_id = aws_vpc.jenkins-prod.id
  tags = {
    Name = "JenkinsIGW"
  }
}
resource "aws_route_table" "jenkins_route_table" { #define RT for VPC
  vpc_id = aws_vpc.jenkins-prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }

  tags = {
    Name = "JenkinsRouteTable"
  }
}
resource "aws_security_group" "jenkins-master-sg" {
  name        = "jenkins-master-sg"
  description = "jenkins-master-sg"
  vpc_id      = aws_vpc.jenkins-prod.id

  ingress {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 22
  }
  ingress {
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 8080
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 8080
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }
}

resource "aws_security_group" "jenkins-slave-sg" {
  name   = "jenkins-slave-sg"
  vpc_id = aws_vpc.jenkins-prod.id

  ingress {
    security_groups  = [aws_security_group.jenkins-master-sg.id]
    description      = "Allow only connection comming from the master"
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    self             = false
    to_port          = 22
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

}

resource "aws_instance" "jenkins-master" {
  ami               = "ami-004359656ecac6a95"
  instance_type     = "t2.micro"
  availability_zone = "eu-central-1a"
  key_name          = aws_key_pair.jenkins-key.id
  subnet_id         = aws_subnet.jenkins-master-subnet.id

  provisioner "file" {
    source      = "install_jenkins.sh"
    destination = "/tmp/install_jenkins.sh"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = aws_instance.jenkins-master.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_jenkins.sh",
      "sh /tmp/install_jenkins.sh",
    ]
  }

  depends_on = [aws_instance.jenkins-master]
}


resource "aws_instance" "jenkins-slave" {
  ami               = "ami-004359656ecac6a95"
  instance_type     = "t2.micro"
  availability_zone = "eu-central-1a"
  subnet_id         = aws_subnet.jenkins-slave-subnet.id
}
output "instance_ip_addr" {
  value = aws_instance.jenkins-master.public_ip
}
