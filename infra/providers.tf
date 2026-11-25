terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }

  # The state bucket was made by hand (versioned, encrypted, public access
  # blocked); see README.md. use_lockfile locks state with an S3 object.
  backend "s3" {
    bucket       = "oaks-terraform-state"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
