resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [var.bastion_sg_id]
  associate_public_ip_address = true
  tags = {
    Name = "bastion-host" 
    }
}

#-------------- Generate key -------------
resource "tls_private_key" "redis_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "redis_keypair" {
  key_name   = "redis-key"
  public_key = tls_private_key.redis_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.redis_key.private_key_pem
  filename = "${path.module}/redis-key.pem"
}