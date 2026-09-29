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
    env = "engorg"
    rev = "1"
  }
}

module "label" {
  source = "git::https://github.com/56kcloud/acme-iacsandbox-infra.git//modules/label?ref=v0.1.0"

  namespace   = "acme"
  environment = "engorg"
  name        = "probe"
}

output "label_id" {
  description = "Proves the module resolved."
  value       = module.label.id
}
