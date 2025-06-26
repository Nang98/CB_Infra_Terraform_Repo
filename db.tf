# Create Security Group for RDS
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow only EC2 subnet access to RDS"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 3306        
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = []  # Leave empty since security group reference is used below
    security_groups = [aws_security_group.wordpress_app_sg.id]  # Allow access only from App subnet's security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  tags = {
    Name        = "db-sg"
    CreatedBy   = "Terraform"
    
  }
}

# Create Subnet Group for RDS
resource "aws_db_subnet_group" "db_subnet_gp" {
  name       = "db-subnet-group"
  subnet_ids = aws_subnet.db_subnets.*.id

  tags = {
    Name        = "db-subnet-group"
    CreatedBy   = "Terraform"
  }
}

# Create Secret Key for RDS Credential
resource "aws_secretsmanager_secret" "db_credentials" {
  #name = "wordpress-db-secret"
  name = "wordpress-db-secret-4"

  tags = {
    Name        = "wordpress-db-secret"
    CreatedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
  })
}

resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&()*+-.:;<=>?[]^_{|}~"
}

# Create Aurora Cluster
resource "aws_rds_cluster" "db" {
  cluster_identifier        = "wordpress-aurora-db"
  engine                    = "aurora-mysql"
  engine_mode               = "provisioned"
  engine_version            = "8.0.mysql_aurora.3.08.0"
  database_name             = "wordpress"
  availability_zones        = var.availability_zones
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  master_username           = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["username"]
  master_password           = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["password"]
  storage_encrypted         = true
  db_subnet_group_name      = aws_db_subnet_group.db_subnet_gp.name
  skip_final_snapshot       = true
  backup_retention_period   = 7
  preferred_backup_window   = "02:00-03:00"

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.0
    seconds_until_auto_pause = 300
  }

  tags = {
    Name        = "wordpress-db-cluster"
    CreatedBy   = "Terraform"
  }
}

resource "aws_rds_cluster_instance" "write_instance" {
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version
  identifier         = "wordpress-db-instance-primary"

  tags = {
    Name        = "wordpress-db-instance-primary"
    CreatedBy   = "Terraform"
  }
}