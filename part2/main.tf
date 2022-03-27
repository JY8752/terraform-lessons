#これでprofile指定できているのか？？
provider "aws" {
  profile = "terraform"
}

# Amazon Linux2のAMIをベースにEC2インスタンスを作成
resource "aws_instance" "example" {
  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
  #タグを追加
  tags = {
    Name = "example"
  }
  #user_data 作成時にApacheをインストール
  user_data = <<EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd.service
	EOF
}
