terraform {
    backend "s3" {
        bucket = "tptech-onboarding-tfstate"
        key    = "infra/terraform.tfstate"
        region = "us-east-2"
    }
}