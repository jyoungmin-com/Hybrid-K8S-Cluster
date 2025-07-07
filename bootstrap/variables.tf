variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
    description = "AWS Region (eg. us-east-1)"
    type = string
    default = "us-east-1"
}