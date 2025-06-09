# shared outputs.tf

output "vpn_public_ip" {
  value = aws_eip.vpn_eip.public_ip
  description = "고정된 VPN 서버의 퍼블릭 IP"
}
