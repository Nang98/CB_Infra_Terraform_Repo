# Create Main VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "main-vpc"
    CreatedBy   = "Terraform"
  }
}

# Create Subnets for Web Tier
resource "aws_subnet" "web_subnets" {
  count = 2
  vpc_id                   = aws_vpc.main_vpc.id
  cidr_block               = cidrsubnet(aws_vpc.main_vpc.cidr_block, 4, count.index)
  map_public_ip_on_launch  = true
  availability_zone        = var.availability_zones[count.index]

  tags = {
    Name        = "web-public-subnet-${var.availability_zones[count.index]}"
    CreatedBy   = "Terraform"
  }
}

# Private subnets for Application Tier
resource "aws_subnet" "app_subnets" {
  count = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.main_vpc.cidr_block, 4, count.index + 2)
  availability_zone =  var.availability_zones[count.index]

  tags = {
    Name        = "app-private-subnet-${var.availability_zones[count.index]}"
    CreatedBy   = "Terraform"
  }
}

# Private subnets for Database Tier
resource "aws_subnet" "db_subnets" {
  count = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.main_vpc.cidr_block, 4, count.index + 4)
  availability_zone =  var.availability_zones[count.index]

  tags = {
    Name        = "db-private-subnet-${var.availability_zones[count.index]}"
    CreatedBy   = "Terraform"
  }
}

# Create Main IGW 
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name        = "main-igw"
    CreatedBy   = "Terraform"
  }
}

# Create NAT Gateway
resource "aws_eip" "main_nat_gw" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main_igw]
}

resource "aws_nat_gateway" "main_nat_gw" {
  allocation_id = aws_eip.main_nat_gw.id
  subnet_id     = aws_subnet.web_subnets[0].id
  tags = {
    Name        = "main-nat-gw"
    CreatedBy   = "Terraform"
  }
}

# Create Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name        = "public-route-table"
    CreatedBy   = "Terraform"
  }
}

# Associate Public Route Table with Web Subnets
resource "aws_route_table_association" "web" {
  count           = 2
  subnet_id       = aws_subnet.web_subnets[count.index].id
  route_table_id  = aws_route_table.public_rt.id
}

# Create Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat_gw.id
  }

  tags = {
    Name        = "private-route-table"
    CreatedBy   = "Terraform"
  }
}

# Associate Private Route Table with App and DB Subnets
resource "aws_route_table_association" "app" {
  count         = 2
  subnet_id     = aws_subnet.app_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db" {
  count         = 2
  subnet_id     = aws_subnet.db_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}
