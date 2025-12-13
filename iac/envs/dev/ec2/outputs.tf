output "mongo_private_ip" {
  value = aws_instance.mongo.private_ip
}

output "mongo_sg_id" {
  value = aws_security_group.mongo.id
}