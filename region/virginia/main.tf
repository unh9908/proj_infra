provider "aws" {
  region = local.region
  profile = "default"
}

module "Networking" {
  source                     = "../../module/networking"
  name                       = "comp851-VPC"
  availability_zones         = local.availability_zones
  vpc_cidr_block             = "10.0.0.0/16"
  public_subnets_cidr_block  = ["10.0.32.0/24", "10.0.96.0/24", "10.0.224.0/24"]
  private_subnets_cidr_block = ["10.0.0.0/19", "10.0.64.0/19", "10.0.128.0/19"]
  vpc_tags                   = local.tags
}

module "ec2" {
  source = "../../module/ec2"
  vpc_id = module.Networking.vpc_id
  public_subnets_id = module.Networking.public_subnets_id
  security_group_ids = module.Networking.security_groups_ids

}

# module "Jumpserver" {
#   source = "../../module/jumpserver"
#   vpc_id = module.Networking.vpc_id
#   public_subnets_id = module.Networking.public_subnets_id
#   security_group_ids = module.Networking.security_groups_ids

# }

/*resource "random_string" "password" {
  length  = 32
  special = false
}

resource "aws_db_instance" "staging" {
  db_name             = "staging"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.2"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = module.Networking.security_groups_ids
  username               = "comp851"
  password               = "random_string.password.result"
  storage_encrypted    = true
  storage_type = "gp2"
}
/*
# Create ECS for demo
module "ECS" {
  source                 = "../../module/ecs"
  vpc_id                 = module.Networking.vpc_id
  account_id             = local.account_id
  ecs_cluster_name       = "ecs-cluster"
  ecs_service_name       = "golang-web-service"
  cpu                    = 256
  memory                 = 512out
  max_capacity           = 8
  project_name           = "golang-web"
  image_name             = "golang-web"
  region                 = local.region
  vpc_private_subnets_id = module.Networking.private_subnets_id
  vpc_public_subnets_id  = module.Networking.public_subnets_id
}

# Create pipeline
module "Pipeline" {
  source           = "../../module/pipeline"
  name             = "golang-web"
  image_name       = "golang-web"
  account_id       = local.account_id
  region           = local.region
  pipeline_tags    = local.tags
  ecs_cluster_name = module.ECS.ecs_cluster_name
  ecs_service_name = module.ECS.ecs_service_name
}
*/