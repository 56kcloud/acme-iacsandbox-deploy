# engorg

Sandbox environment.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.12.0 |
| null | ~> 3.2 |

## Providers

| Name | Version |
| ---- | ------- |
| null | ~> 3.2 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| label | git::https://github.com/56kcloud/acme-iacsandbox-infra.git//modules/label | v0.1.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [null_resource.probe](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Outputs

| Name | Description |
| ---- | ----------- |
| label\_id | Proves the module resolved. |
<!-- END_TF_DOCS -->
