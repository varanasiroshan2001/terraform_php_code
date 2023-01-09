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



resource "tls_private_key" "key-pair" {
  algorithm = "RSA"
  rsa_bits = 4096
}


//FOR SAVING THE KEY GENERATED IN .PEM EXTENSION
resource "local_file" "private-key" {
 content = tls_private_key.key-pair.private_key_pem
 filename = "${var.ssh_key_name}.pem"
 file_permission = "0400"
}



resource "aws_key_pair" "deployer" {
 key_name   = var.ssh_key_name
 public_key = tls_private_key.key-pair.public_key_openssh
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



resource "null_resource" "nullremote1" {
 connection {
  type = "ssh"
  user = "ec2-user"
  private_key = file("${var.ssh_key_name}.pem")
  host = aws_instance.myosweb.public_ip  
   }


 provisioner "remote-exec" {
  inline = [
   "sudo yum install httpd php git -y",
   "sudo service httpd restart",
   "sudo chkconfig  httpd  on",
   
    ]
  }
}





//FOR LAUNCHING AN EBS VOLUME SO THAT WE CAN LATER ON RETRIEVE THE DATA BY MOUNT AND UNMOUNT
resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.myosweb.availability_zone
  size              = 1

  tags = {
    Name = "myvolume"
  }
}






//FOR ATTACHING THE VOLUME TO OUR INSTANCE LAUNCHED ABOVE
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.myebs.id}"
  instance_id = "${aws_instance.myosweb.id}"
  force_detach = true
  depends_on = [ 
      aws_ebs_volume.myebs, 
      aws_instance.myosweb ]


}



resource "null_resource" "nullremote21" {

  depends_on = [
      aws_volume_attachment.ebs_att,	 ]
  connection {
   type = "ssh"
   user = "ec2-user"
   private_key = file("${var.ssh_key_name}.pem")
   host = aws_instance.myosweb.public_ip  
      }

  provisioner "remote-exec" {
   inline = [
   "sudo mkfs.ext4 /dev/xvdd",
   "sudo mount /dev/xvdd /var/www/html",
   "sudo rm -rf /var/www/html/*",
   "sudo git clone https://github.com/varanasiroshan2001/terraform_php_code.git   /var/www/html/",
   "sudo service httpd restart",
   "sudo set selinux 0"
         ]
   }
}




//FOR CREATING A S3 BUCKET TO UPLOAD IMAGES AND VIDEOS ON CLOUD
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-tf-test-bucket-roshan"
  acl    = "public-read"

  tags = {
    Name  = "1234Myimgbucket9668033104"
  }
}


//FOR PUTTING THE OBJECTS IN s3
resource "aws_s3_bucket_object" "object" {
  depends_on = [
    aws_s3_bucket.my_bucket,
         ]

  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ROSHAN.jpeg"
  source = "C:/Users/V Roshan/Downloads/ROSHAN.jpeg"
  acl    = "public-read"
  
}

resource "aws_s3_bucket_object" "object1" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "videoplayback.mp4"
  source = "C:/Users/V Roshan/Downloads/videoplayback.mp4"
  acl    = "public-read"
  depends_on = [
    aws_s3_bucket.my_bucket,
  ]
}




locals { 
  s3_origin_id = "S3-${aws_s3_bucket.my_bucket.bucket}"
}






// CREATING ORIGIN ACCESS IDENTITY FOR CLOUDFRONT
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "roshan-bucket"
}



//FOR CREATING CLOUDFRONT DISTRIBUTIONS FOR EASY ACCESS FROM EDGE LOCATIONS 
resource "aws_cloudfront_distribution" "ros_cloudfront" {
  origin {
  domain_name = "${aws_s3_bucket.my_bucket.bucket_regional_domain_name}"
  origin_id = "${local.s3_origin_id}"
  
  s3_origin_config {
  origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
}
}

  enabled = true
  is_ipv6_enabled = true
  comment = "ros-access"


 default_cache_behavior {
  allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  cached_methods = ["GET", "HEAD"]
  target_origin_id = "${local.s3_origin_id}"


  forwarded_values {
    query_string = false
      cookies {
        forward = "none"
      }
  }
  viewer_protocol_policy = "allow-all"
  min_ttl = 0
  default_ttl = 3600
  max_ttl = 86400
  }
  
 //Cache behavior with precedence 0
 ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  //Cache behavior with precedence 1
 ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

 price_class = "PriceClass_200"

 restrictions {
  geo_restriction {
    restriction_type = "none"
 }
 }

 tags = {
    Environment = "production_withroshanon2023headsup"
  }

 viewer_certificate {
    cloudfront_default_certificate = true
  }
}






