resource "aws_vpc" "aditya_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc_addi" 
    }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aditya_vpc.id
  tags = {
    Name = "tf-igw" 
    }
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az_1
  tags = {
    Name = "public-subnet-1" 
    }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az_2
  tags = {
    Name = "public-subnet-2" 
    }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az_1
  tags = {
    Name = "application_private-subnet-1" 
    }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.aditya_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az_2
  tags = {
    Name = "application_private-subnet-2" 
    }
}


# ---------------- NAT Gateway ----------------
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
  tags = {
    Name = "tf-natgw"
  }
}


# ---------------- Route Tables ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aditya_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "tf-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.aditya_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "tf-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}