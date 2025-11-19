output "vpc_id" {
  value = module.network.vpc_id
}

output "bastion_public_ip" {
  value = module.compute.bastion_public_ip
}

output "alb_dns_name" {
  value = module.alb_asg.alb_dns_name
}
