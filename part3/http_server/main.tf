#Apacheサーバーを起動して、ポート80でリッスン
variable "instance_type" {

}

#ec2
resource "aws_instance" "default" {
  ami                    = "ami-0c3fd0f5d33134a76"
  vpc_security_group_ids = [aws_security_group.default.id]
  instance_type          = var.instance_type
  user_data              = <<EOF
	#!/bin/bash
	yum install -y httpd
	systemctl start httpd.service
	EOF
}

#sg
resource "aws_security_group" "default" {
  name = "ec2"
  ingress = [{
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
  egress = [{
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
}

#出力
output "public_dns" {
  value = aws_instance.default.public_dns
}
