variable "region" {
  default = "us-west-2"
}

variable "profile" {
  default = "storetheindex"
}

variable "deploy_priv_key_path" {
  default = "~/.ssh/marco-storetheindex-deployment"
}
variable "deploy_pub_key_path" {
  default = "~/.ssh/marco-storetheindex-deployment.pub"
}
