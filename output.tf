output "web_alb_dns_name" {
  description = "DNS name of the Web Application Load Balancer"
  value       = aws_alb.web_alb.dns_name
}

output "web_alb_arn" {
  description = "The ARN of the Web Application Load Balancer"
  value       = aws_alb.web_alb.arn
}

output "app_asg_name" {
  description = "Name of the App Auto Scaling Group"
  value       = aws_autoscaling_group.wordpress_asg.name
}

output "db_instance_endpoint" {
  description = "Endpoint of the DB instance"
  value       = aws_rds_cluster_instance.write_instance.endpoint
}