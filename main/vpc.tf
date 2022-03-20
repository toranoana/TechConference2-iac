# 現リージョンで使用できるすべてのAZ
data "aws_availability_zones" "az" {
  state = "available"
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = local.cidr_block

  tags = {
    Name = "sample-${terraform.workspace}"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "my-igw-${terraform.workspace}"
  }
}

# ルートテーブルpublic
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-${terraform.workspace}"
  }
}

# ルートテーブルdb
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "db-${terraform.workspace}"
  }
}

# サブネット public
resource "aws_subnet" "public" {
  for_each = {
    "public-01" = {
      az     = data.aws_availability_zones.az.names[0]
      netnum = 0
    }
    "public-02" = {
      az     = data.aws_availability_zones.az.names[1]
      netnum = 1
    }
  }

  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.value.az
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, each.value.netnum)

  tags = {
    Name = "sample-${terraform.workspace}/${each.key}"
  }
}

# サブネット app
resource "aws_subnet" "app" {
  for_each = {
    "app-01" = {
      az     = data.aws_availability_zones.az.names[0]
      netnum = 50
    }
    "app-02" = {
      az     = data.aws_availability_zones.az.names[1]
      netnum = 51
    }
  }

  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.value.az
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, each.value.netnum)

  tags = {
    Name = "sample-${terraform.workspace}/${each.key}"
  }
}

# サブネット db
resource "aws_subnet" "db" {
  for_each = {
    "db-01" = {
      az     = data.aws_availability_zones.az.names[0]
      netnum = 100
    }
    "db-02" = {
      az     = data.aws_availability_zones.az.names[1]
      netnum = 101
    }
  }

  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.value.az
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, each.value.netnum)

  tags = {
    Name = "sample-${terraform.workspace}/${each.key}"
  }
}

# ルートテーブルpublicとサブネット紐付け
resource "aws_route_table_association" "public" {
  for_each = merge(aws_subnet.public, aws_subnet.app)

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ルートテーブルdbとサブネット紐付け
resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}
