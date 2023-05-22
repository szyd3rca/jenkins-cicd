provider "aws" {
  region = "eu-central-1"
  #access_key = var.access_key
  #secret_key = var.secret_key
  profile                 = "terraform"
  shared_credentials_file = "~/.aws/credentials"
}

