# Create Instance Profile for EC2
resource "aws_iam_role" "ec2_role" {
  name = "wordpress-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "wordpress-app-role"
    CreatedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ])
  role       = aws_iam_role.ec2_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "wordpress-app-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Create a security group for the EC2 instances
resource "aws_security_group" "wordpress_app_sg" {
  name        = "wordpress-sg"
  description = "Allow HTTP, HTTPS, and SSH traffic"
  vpc_id      = aws_vpc.main_vpc.id
  
    dynamic "ingress" {
    for_each = [80, 443, 22]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "wordpress-sg"
    CreatedBy   = "Terraform"
  }
}

# Generate key Pair for App
resource "tls_private_key" "custom_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "app_key" {
  key_name   = "wordpress-app-key"
  public_key = tls_private_key.custom_key.public_key_openssh

  provisioner "local-exec" {
    command = <<EOT
      echo "${tls_private_key.custom_key.private_key_pem}" > "wordpress-app-key.pem"
      move "wordpress-app-key.pem" $env:USERPROFILE\.ssh\
    EOT

    interpreter = ["PowerShell", "-Command"]
  }
}

# Define EC2 instance launch template
resource "aws_launch_template" "wordpress_template" {
  name_prefix               = "wordpress-asg-template"
  image_id                  = var.app_ami
  instance_type             = "t2.micro"
  vpc_security_group_ids    = [aws_security_group.wordpress_app_sg.id]
  key_name                  = aws_key_pair.app_key.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash

              cd /home/ec2-user
              sudo yum update -y
              sudo yum install -y jq
              sudo yum install -y httpd
              sudo service httpd start
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              cd wordpress
              cp wp-config-sample.php wp-config.php
              SECRET_NAME="wordpress-db-secret-4"
              REGION="us-east-1"
              DB_SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region $REGION --query SecretString --output text)
              DB_USER=$(echo $DB_SECRET | jq -r '.username')
              DB_PASSWORD=$(echo $DB_SECRET | jq -r '.password')
              DB_HOST=$(aws rds describe-db-instances --query 'DBInstances[0].Endpoint.Address' --output text --region $REGION)
              DB_NAME="wordpress"
              sudo sed -i "s/'DB_NAME', 'database_name_here'/'DB_NAME', '$DB_NAME'/g" wp-config.php
              sudo sed -i "s/'DB_USER', 'username_here'/'DB_USER', '$DB_USER'/g" wp-config.php
              sudo sed -i "s/'DB_PASSWORD', 'password_here'/'DB_PASSWORD', '$DB_PASSWORD'/g" wp-config.php
              sudo sed -i "s/'DB_HOST', 'localhost'/'DB_HOST', '$DB_HOST'/g" wp-config.php
              cd /home/ec2-user
              sudo amazon-linux-extras install -y mariadb10.5 php8.2
              sudo cp -r wordpress/* /var/www/html/
              sudo service httpd restart
              
              EOF
            )
  tags = {
    Name        = "wordpress-asg-template"
    CreatedBy   = "Terraform"
  }

  depends_on = [aws_rds_cluster_instance.write_instance]
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile-for-wordpress"
  role = aws_iam_role.ec2_role.name
}

# Create Auto Scaling Group with EC2 instances in different AZs
resource "aws_autoscaling_group" "wordpress_asg" {
  name                 = "wordpress-app-asg"
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier  = aws_subnet.app_subnets.*.id
  launch_template {
    id                 = aws_launch_template.wordpress_template.id
    version            = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "wordpress-instance"
    propagate_at_launch = true
  }

  health_check_type          = "EC2"
  health_check_grace_period = 300
  force_delete               = true
  wait_for_capacity_timeout   = "0"
}

# Attach Load Balancer to Autoscaling Gp
resource "aws_autoscaling_attachment" "wordpress-alb-attachment" {
  autoscaling_group_name = aws_autoscaling_group.wordpress_asg.id
  lb_target_group_arn    = aws_alb_target_group.web_alb_tg.arn
}