terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.26.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "postgresql" {
  alias    = "bootstrap"
  host     = aws_db_instance.ai_agent.address
  port     = 5432
  database = "postgres"
  username = var.db_username
  password = var.db_password
  sslmode  = "require" # or "disable" if testing
}

data "aws_availability_zones" "available" {}

resource "random_pet" "random" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.4.0"

  name                 = "${random_pet.random.id}-ai-agent"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway = false
  enable_vpn_gateway = false
}

resource "aws_db_subnet_group" "ai_agent" {
  name       = "${random_pet.random.id}-ai-agent"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "${random_pet.random.id}-ai-agent"
  }
  depends_on = [module.vpc]
}

resource "aws_security_group" "rds" {
  name   = "${random_pet.random.id}-ai-agent-rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${random_pet.random.id}-ai-agent-rds"
  }
}

resource "aws_db_parameter_group" "ai_agent" {
  name   = "${random_pet.random.id}-ai-agent-rds"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "ai_agent" {
  identifier             = var.db_name
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "16.8"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.ai_agent.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.ai_agent.name
  publicly_accessible    = true
  skip_final_snapshot    = true
  depends_on = [
    aws_db_subnet_group.ai_agent,
    aws_security_group.rds
  ]
}

# Fake Terraform backend for demo (fake Terraform state)
resource "postgresql_database" "ai_agent_db" {
  provider = postgresql.bootstrap
  name                   = var.db_name
  owner                  = var.db_username
  lc_collate = "en_US.UTF-8"
  lc_ctype   = "en_US.UTF-8"
  allow_connections      = true
  alter_object_ownership = true
}

provider "postgresql" {
  alias    = "ai_agent"
  host     = aws_db_instance.ai_agent.address
  port     = 5432
  database = var.db_name
  username = var.db_username
  password = var.db_password
  sslmode  = "require"
}

resource "postgresql_schema" "terraform_remote_state" {
  provider = postgresql.ai_agent
  name     = "terraform_remote_state"
  depends_on = [postgresql_database.ai_agent_db]
}

resource "null_resource" "create_table_and_load_fake_data" {
  depends_on = [postgresql_schema.terraform_remote_state]

  provisioner "local-exec" {
    command = <<EOT
bash -c 'psql "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.ai_agent.address}:5432/${var.db_name}" \
-c "CREATE TABLE IF NOT EXISTS terraform_remote_state.states(id SERIAL PRIMARY KEY, name TEXT, data TEXT);" \
  -c "\\copy terraform_remote_state.states(id, name, data) FROM '\''${path.module}/fake_db_data.csv'\'' CSV HEADER;"'
EOT
  }
}