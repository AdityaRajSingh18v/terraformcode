provider "aws" {
  region = var.region
}

module "network" {
  source   = "./modules/network"
  vpc_cidr = var.vpc_cidr
  az_1     = var.az_1
  az_2     = var.az_2
}

module "security" {
  source               = "./modules/security"
  vpc_id               = module.network.vpc_id
  vpc_cidr             = var.vpc_cidr
  public_subnet_1_cidr = var.public_subnet_1_cidr
  private_subnet_ids   = module.network.private_subnet_ids
}

module "compute" {
  source           = "./modules/compute"
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_1_id
  ami_id           = var.ami_id
  instance_type    = var.instance_type
  key_name         = var.key_name
  bastion_sg_id    = module.security.bastion_sg_id
}

module "alb_asg" {
  source          = "./modules/alb_asg"
  vpc_id          = module.network.vpc_id
  public_subnets  = module.network.public_subnet_ids
  private_subnets = module.network.private_subnet_ids
  app_sg_id       = module.security.app_sg_id
  alb_sg_id       = module.security.alb_sg_id
  ami_id          = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_name
}