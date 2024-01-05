resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  // Spécifiez les sous-réseaux ici
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr
}ç

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"  # Choose a non-conflicting CIDR block
  availability_zone       = "us-west-2a"
}


resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-groupp"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

resource "aws_route_table_association" "my_rta" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_security_group" "my_sg" {
  name   = "allow_http"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "my_instance1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.my_subnet.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  key_name               = aws_key_pair.deployer.key_name
  tags = {
    Name = "VM1"
  }
}

resource "aws_instance" "my_instance2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.my_subnet.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  key_name               = aws_key_pair.deployer.key_name
  tags = {
    Name = "VM2"
  }
}

resource "aws_elb" "my_elb" {
  name = "my-elb"

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  subnets   = [aws_subnet.my_subnet.id]
  instances = [aws_instance.my_instance1.id, aws_instance.my_instance2.id]
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsiOiHTf9zeaVMU+x80z5Cc0s+xiJchYkyq4BqHJrjJ2B3b4ra9yx4mkGcK/wAgirsOg1uSE32lHw1qWrS575bzyz9oh2VQlfqD1cqOWKwolEhTcEXjESPn/BbnGyaBODwE3OfkGhwMA80ucFXKhx8BOu77LjRYRJ/C3W0N8HotxoQB+ezBJJgaOe3T9dzyTtWI6d057m8SAsvKuxuuW8PFxgbBfX5KbmapbDUeApnmW9NDKTnOw1q76rVBchxGOtduFQ2bV3gsTf2ANTSRjqqSzQd2vjS20aeYdOaTFEhdw7Viqb0N5SLasF/NscNoLTD2f4jeUQJw2tujrwgQCk5iSQJjRPSb5i7PDUlfavNVh6+CO039RrDhEXH4xVAFyZJcosXDTHQYk/x6kLbCPsXmnuZLU+Yf0SKrf/wDIeL7bMzZa0aQb+ZU0jpW1Z3gSgW2gHtkqrLuKf9cIhXjfBavW4UhSLxNrODKwV8OLgoI4hY8PAMdLXW/5AVm4lD9Sk="
}

