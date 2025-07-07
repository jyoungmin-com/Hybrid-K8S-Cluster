data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = "bootstrap-tf-state-central"
    key = "bootstrap/terraform.tfstate"
    region = var.aws_region
    dynamodb_table = "tfstate-locks-global"
  }
}

locals {
  cluster_uuid = data.terraform_remote_state.bootstrap.outputs.cluster_uuid
  state_bucket = data.terraform_remote_state.bootstrap.outputs.state_bucket
  lock_table = data.terraform_remote_state.bootstrap.outputs.lock_table
}