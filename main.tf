# Create a VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Ansible VPC"
  }
}

# Create Web Public Subnet
resource "aws_subnet" "web-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Ansible-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "ansible IGW"
  }
}

# Create Web layber route table
resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.my-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ansibleRT"
  }
}

# Create Web Subnet association with Web route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet.id
  route_table_id = aws_route_table.web-rt.id
 }


  # Create Web Security Group
resource "aws_security_group" "web-sg" {
    name        = "Web-SG"
    description = "Allow ssh inbound traffic"
    vpc_id      = aws_vpc.my-vpc.id
  
    ingress {
      description = "ssh from VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    
  
  ingress {
    description = "http port"
    from_port   = 80
    to_port     = 80
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
      Name = "Web-SG"
    }
}
  
# Generates a secure private k ey and encodes it as PEM
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Create the Key Pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "keypair1"  
  public_key = tls_private_key.ec2_key.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "keypair.pem"
  content  = tls_private_key.ec2_key.private_key_pem
}

#data for amazon linux

data "aws_ami" "amazon-2" {
    most_recent = true
  
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-ebs"]
    }
    owners = ["amazon"]
  }
 
#create ec2 instances 

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = ">= 3.0"
  
  for_each = {
    "master"    = { instance_type = "t3.micro", name = "master-instance",user_data=file("${path.module}/install.sh") },
    "dev" = { instance_type = "t3.micro", name = "dev-instance", user_data="" },
    "qa"  = { instance_type = "t3.small", name = "qa-instance", user_data="" }
  }

  ##for_each = toset(["ansible-master", "target-node1", "target-node2"])

  name = "${each.value.name}"

  ami                    = "${data.aws_ami.amazon-2.id}"
  instance_type          = "${each.value.instance_type}"
  key_name               = aws_key_pair.ec2_key.key_name
  monitoring             = true
  user_data            = "${each.value.user_data}"
  vpc_security_group_ids = ["${aws_security_group.web-sg.id}"]
  subnet_id              = aws_subnet.web-subnet.id

  tags = {
    Terraform   = "true"
    Environment = "${each.key}"
  }
}
# here we are using the Null resource to copy our ssh key into the master server.
resource "null_resource" "copy_ssh_key" {
    depends_on = [module.ec2_instance["master"]]

    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = tls_private_key.ec2_key.private_key_pem
      host = module.ec2_instance["master"].public_ip
    }

    provisioner "file" {
      source = "keypair.pem"
      destination = "/home/ec2-user/keypair.pem"
    }
    provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ec2-user/keypair.pem",
    ]
  }
}