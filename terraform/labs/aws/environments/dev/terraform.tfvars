aws_region  = "us-east-1"
bucket_name = "expense-tracker-dev-terraform-2026"

vpc_cidr = "10.0.0.0/16"

vpc_name = "expense-tracker-dev-vpc"

subnet_cidr      = "10.0.1.0/24"
subnet_name      = "expense-tracker-dev-subnet"
route_table_name = "expense-tracker-dev-route-table"

ami_id        = "ami-0db1c5c6dc64eb019"
instance_type = "t3.micro"
instance_name = "expense-tracker-dev-ec2"

key_name = "expense-tracker-dev"
