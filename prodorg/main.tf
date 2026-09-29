terraform {
  required_version = ">= 1.12.0"

  backend "local" {}

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "probe" {
  triggers = {
    env = "prodorg"
    rev = "1"
  }
}
