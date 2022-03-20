# publicセキュリティグループ - ロードバランサなど一般HTTPアクセス
resource "aws_security_group" "public" {
  name        = "sample-${terraform.workspace}/public"
  description = "public access"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "sample-${terraform.workspace}/public"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# appセキュリティグループ - アプリケーション部分
resource "aws_security_group" "app" {
  name        = "sample-${terraform.workspace}/app"
  description = "app"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "sample-${terraform.workspace}/app"
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    self      = true
    security_groups = [
      aws_security_group.public.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# dbセキュリティグループ - RDS,ElastiCache用のセキュリティグループ
resource "aws_security_group" "db" {
  name        = "sample-${terraform.workspace}/db"
  description = "db"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "sample-${terraform.workspace}/db"
  }

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app.id,
    ]
  }

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    security_groups = [
      aws_security_group.app.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
