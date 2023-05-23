resource "tls_private_key" "rsa-master" {#generate the RSA key for master
  algorithm = "RSA"
  rsa_bits = 4096 
}
resource "aws_key_pair" "jenkins-master-key" { #import the RSA Key 
  key_name   = "jenkins-master-key"
  public_key = tls_private_key.rsa-master.public_key_openssh
  depends_on = [ tls_private_key.rsa-master ]
}

resource "local_file" "jenkins-master-key" {#write private .pem file to local_file on executor's machine
  content = tls_private_key.rsa-master.private_key_pem
  filename = "tfkey-master"
  depends_on = [ tls_private_key.rsa-master ]
}

resource "tls_private_key" "rsa-slave" {#generate the RSA key for slave
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins-slave-key" {
  key_name   = "jenkins-slave-key"
  public_key = tls_private_key.rsa-slave.public_key_openssh
  depends_on = [tls_private_key.rsa-slave]
}

resource "local_file" "jenkins-slave-key" {
  content     = tls_private_key.rsa-slave.private_key_pem
  filename    = "tfkey-slave"
  depends_on  = [tls_private_key.rsa-slave]
}


resource "aws_vpc" "jenkins-prod" { #define VPC
  cidr_block = "10.0.0.0/16"
    tags = {
    Name = "jenkins-prod-vpc"

  }
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
  
  tags = {
    Name = "jenkins-acl"
  }
}
resource "aws_subnet" "jenkins-master-subnet" {
  vpc_id                  = aws_vpc.jenkins-prod.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  
  
  tags = {
    Name = "jenkins-master-subnet"
  }
}
resource "aws_subnet" "jenkins-slave-subnet" {
  vpc_id            = aws_vpc.jenkins-prod.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1a"
  
  tags = {
    Name = "jenkins-slave-subnet"
  }
}
resource "aws_network_acl_association" "jenkins-master-subnet-acl" {
  subnet_id          = aws_subnet.jenkins-master-subnet.id
  network_acl_id     = aws_network_acl.jenkins-vpc-acl.id
}
resource "aws_network_acl_association" "jenkins-slave-subnet-acl" {
  subnet_id          = aws_subnet.jenkins-slave-subnet.id
  network_acl_id     = aws_network_acl.jenkins-vpc-acl.id
}
resource "aws_internet_gateway" "jenkins_igw" { #define IGW for master-subnet
  vpc_id = "${aws_vpc.jenkins-prod.id}"
  tags = {
    Name = "JenkinsIGW"
  }
}
resource "aws_route_table" "jenkins_route_table" { #define RT for VPC
  vpc_id = "${aws_vpc.jenkins-prod.id}"
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }

  tags = {
    Name = "JenkinsRouteTable"
  }
}
resource "aws_route_table_association" "jenkins-master-association" {
  subnet_id      = aws_subnet.jenkins-master-subnet.id
  route_table_id = aws_route_table.jenkins_route_table.id
}
resource "aws_route_table_association" "jenkins-slave-association" {
  subnet_id      = aws_subnet.jenkins-slave-subnet.id
  route_table_id = aws_route_table.jenkins_route_table.id
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
  ami               = "ami-047decd705ef4b0eb"
  instance_type     = "t2.micro"
  availability_zone = "eu-central-1a"
  subnet_id = aws_subnet.jenkins-master-subnet.id
  key_name          = "jenkins-master-key"
  associate_public_ip_address = true
 } 
  
/*
  connection {
    host = self.public_ip
		user = "ec2-user"
		private_key = file("~/Desktop/jenkins-cicd/jenkins-cicd/tfkey")
	}

  provisioner "remote-exec" {
		inline = ["sudo apt-get update & sudo apt install -y python3"]
  }
  
}
*/
resource "aws_network_interface_sg_attachment" "master-attachment" {
  security_group_id = aws_security_group.jenkins-master-sg.id
  network_interface_id = aws_instance.jenkins-master.primary_network_interface_id
}

resource "aws_instance" "jenkins-slave" {
  ami               = "ami-004359656ecac6a95"
  instance_type     = "t2.micro"
  availability_zone = "eu-central-1a"
  key_name = "jenkins-slave-key"
  subnet_id         = aws_subnet.jenkins-slave-subnet.id
  
}

resource "aws_network_interface_sg_attachment" "slave-attachment" {
  security_group_id = aws_security_group.jenkins-slave-sg.id
  network_interface_id = aws_instance.jenkins-slave.primary_network_interface_id
}

output "instance_ip_addr" {
  value = aws_instance.jenkins-master.public_ip
}

#git checkout add_button <- by wygenerować 
#git push < wrzuca sie branch do repo 
#git merge < po sprawdzeniu kodu moze przekształcić 
#git remote update 

#0 git clone (https lub ssh)
#1 git pull --rebase origin {nazwa branch}
#2 git checkout -b {nazwa nowego brancha np. data, funkcjonalność, fix}
# wprowadzasz modyfikacje kodu
#3 git add .  {nazwa pliku po spacji, spacja jako separator lub kropka dla wszystkich plikow} << tworzy lokalnego snapshota
#4 git commit -m "nazwa zmiany" << zapisuje w/w snapshota
#5 git pull --rebase origin {nazwa brancha} <<upewniasz sie czy masz najnowsza wersje by uniknac konfliktow 
#6 git push origin {nazwa brancha} -f <<  flaga force w przypadku problemow << wypycha branch do gita 

#7 mozesz zmergowac branch do maina z poziomu