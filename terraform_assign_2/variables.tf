variable "region" {
  default = "us-east-2"
}


variable "vpc_cidr" {
  default = "10.0.0.0/16"
}


variable "az_1" {
  default = "us-east-2a"
}
variable "az_2" {
  default = "us-east-2b"
}



variable "public_subnet_1_cidr" {
  default = "10.0.1.0/24"
}



variable "ami_id" {
  default = "ami-0d9a665f802ae6227"
}
variable "instance_type" {
  default = "t3.micro"
}
variable "key_name" {
  default = "redis-key"
}