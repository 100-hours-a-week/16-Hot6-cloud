# vpc module outputs.tf

output "subnet_id" {
  value = aws_subnet.this.id
}

output "route_table_id" {
  value = aws_route_table.this.id  # 사용 중인 리소스 이름에 맞게 조정
}
