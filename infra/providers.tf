terraform {
  required_version = ">= 1.6.0"

  required_providers {
    fly = {
      source  = "fly-apps/fly"
      version = "~> 0.1"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "fly" {
  # Authenticates via FLY_API_TOKEN environment variable
}

provider "aws" {
  region = "us-east-1"
}
