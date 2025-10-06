# database/outputs.tf

output "db_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.postgres.port
}