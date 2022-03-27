#VPC
resource "aws_vpc" "name" {
  cidr_block           = "10.0.0.0/16" #特にこだわりがなければ/16単位で
  enable_dns_hostnames = true          #パブリックDNSホスト名を自動割り当て
  enable_dns_support   = true          #DNSサーバーによる名前解決を有効
  tags = {
    Name = "example"
  }
}

#サブネット
resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.name.id
  cidr_block              = "10.0.1.0/24" #特にこだわりがなければ/24単位で
  map_public_ip_on_launch = true          #自動でパブリックIPを割り当て
  availability_zone       = "ap-northeast-1a"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.name.id
  cidr_block              = "10.0.2.0/24" #特にこだわりがなければ/24単位で
  map_public_ip_on_launch = true          #自動でパブリックIPを割り当て
  availability_zone       = "ap-northeast-1c"
}

#インターネットゲートウェイ
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.name.id
}

#ルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.name.id
}

#ルート
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0" #VPC以外への通信をゲートウェイ経由で流すためにデフォルトルートを指定
}

#ルートテーブルの関連付け
#どのルートテーブルを使ってルーティングするかをサブネット単位で判断する.
resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

#プライベートサブネット
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.name.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false #パブリックIPは不要
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.name.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false #パブリックIPは不要
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.name.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.name.id
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

#Elastic IP
resource "aws_eip" "nat_gateway_0" {
  vpc = true
  depends_on = [
    aws_internet_gateway.example
  ]
}

resource "aws_eip" "nat_gateway_1" {
  vpc = true
  depends_on = [
    aws_internet_gateway.example
  ]
}

#NATゲートウェイ
resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id #EIP指定
  subnet_id     = aws_subnet.public_0.id   #パブリックサブネット
  depends_on = [
    aws_internet_gateway.example
  ]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id #EIP指定
  subnet_id     = aws_subnet.public_1.id   #パブリックサブネット
  depends_on = [
    aws_internet_gateway.example
  ]
}

#プライベートネットワークからインターネットへ通信するためのルート定義
resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

#sg
resource "aws_security_group" "example" {
  name   = "example"
  vpc_id = aws_vpc.name.id
}

#インバウンドルール(80番許可)
resource "aws_security_group_rule" "ingress_example" {
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

#アウトバウンドルール(全許可)
resource "aws_security_group_rule" "exress_example" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

output "aws_vpc_id" {
  value = aws_vpc.name.id
}

output "aws_vpc_cidr_block" {
  value = aws_vpc.name.cidr_block
}

output "public_subnet_id" {
  value = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id
  ]
}

output "private_subnet_id" {
  value = [
    aws_subnet.private_0.id,
    aws_subnet.private_1.id
  ]
}
