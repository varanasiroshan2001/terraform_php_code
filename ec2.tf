provider "aws" {
  region  = "ap-south-1"
  profile = "roshan1"
}

//FOR CREATION OF SECURITY GROUP WITH OUR OWN INBOUND RULES SUPPORTING SSH,HTTP SERVER
resource "aws_security_group" "roshan_grp_r" {
  name         = "roshan_grp_r"
  description  = "allow ssh and httpd"
 
  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPD Port"
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
    Name = "roshan_sec_grp_r"
  }
}


//FOR CREATING KEY-PAIRS
variable ssh_key_name {
  default = "keyroshan"
}

//FOR LAUNCHING INSTANCE THROUGH EC2
resource "aws_instance" "myosweb" {
  ami           = "ami-005956c5f0f757d37"
  instance_type = "t2.micro"
  key_name = "${var.ssh_key_name}"
  security_groups = [ "roshan_grp_r" ]
  
  tags = {
    Name = "Hello-web-env"
    env = "website"
  }
}







