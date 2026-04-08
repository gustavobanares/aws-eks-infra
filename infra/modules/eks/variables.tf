variable "vpc_id" {
    type = string
}

variable "subnet_ids" {
    type = list(string)
}

variable "cluster_name" {
    type = string
}

variable "sso_admin_role_arn" {
    type = string
  }

  variable "aws_account_id" {
    type = string
  }