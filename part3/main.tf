# #明示的にAWSプロバイダを指定 
# provider "aws" {
#   region = "ap-northeast-1"
# }

# #データソースの定義
# data "aws_ami" "recent_amazon_linux_2" {
#   most_recent = true #最新のAMIを取得
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
#   }
#   filter {
#     name   = "state"
#     values = ["available"]
#   }
# }

# #ec2
# resource "aws_instance" "example" {
#   ami           = data.aws_ami.recent_amazon_linux_2.image_id
#   instance_type = "t3.micro"
#   #セキュリティーグループ
#   vpc_security_group_ids = [aws_security_group.example_ec2.id]
#   user_data              = <<EOF
# 	#!/bin/bash
# 	yum install -y httpd
# 	systemctl start httpd.service
# 	EOF
# }

# #sg
# resource "aws_security_group" "example_ec2" {
#   name = "example-ec2"
#   ingress = [{
#     description      = "http"
#     from_port        = 80
#     to_port          = 80
#     protocol         = "tcp"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     security_groups  = []
#     self             = false
#   }]
#   egress = [{
#     description      = ""
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = []
#     prefix_list_ids  = []
#     security_groups  = []
#     self             = false
#   }]
# }

# output "example_public_dns" {
#   value = aws_instance.example.public_dns
# }

module "web_server" {
  source        = "./http_server"
  instance_type = "t3.micro"
}

output "public_dns" {
  value = module.web_server.public_dns
}
