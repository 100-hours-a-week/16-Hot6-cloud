# dev outputs.tf

output "k8s_master_private_ip" {
  value = module.k8s_master.private_ip
}
