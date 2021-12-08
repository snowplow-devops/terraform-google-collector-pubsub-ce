[![Release][release-image]][release] [![CI][ci-image]][ci] [![License][license-image]][license] [![Registry][registry-image]][registry] [![Source][source-image]][source]

# terraform-google-collector-pubsub-ce

A Terraform module which deploys the Snowplow Stream Collector on CE.  If you want to use a custom image for this deployment you will need to ensure it is based on top of Ubuntu 20.04.

## Telemetry

This module by default collects and forwards telemetry information to Snowplow to understand how our applications are being used.  No identifying information about your sub-account or account fingerprints are ever forwarded to us - it is very simple information about what modules and applications are deployed and active.

If you wish to subscribe to our mailing list for updates to these modules or security advisories please set the `user_provided_id` variable to include a valid email address which we can reach you at.

### How do I disable it?

To disable telemetry simply set variable `telemetry_enabled = false`.

### What are you collecting?

For details on what information is collected please see this module: https://github.com/snowplow-devops/terraform-snowplow-telemetry

## Usage

A collector requires two output PubSub Topics and a Load Balancer which is deployed upstream.  The Load Balancer ensures we can easily configure TLS termination later in the setup and provides a simple mechanism for setting up DNS.

```hcl
module "raw_topic" {
  source  = "snowplow-devops/pubsub-topic/google"
  version = "0.1.0"

  name = "raw-topic"
}

module "bad_1_topic" {
  source  = "snowplow-devops/pubsub-topic/google"
  version = "0.1.0"

  name = "bad-1-topic"
}

module "collector_pubsub" {
  source  = "snowplow-devops/collector-pubsub-ce/google"

  name = "collector-server"

  network    = var.network
  subnetwork = var.subnetwork
  region     = var.region

  ssh_ip_allowlist = ["0.0.0.0/0"]
  ssh_key_pairs    = []

  topic_project_id = var.project_id
  good_topic_name  = module.raw_topic.name
  bad_topic_name   = module.bad_1_topic.name
}

module "collector_lb" {
  source  = "snowplow-devops/lb/google"
  version = "0.1.0"

  name = "collector-lb"

  instance_group_named_port_http = module.collector_pubsub.named_port_http
  instance_group_url             = module.collector_pubsub.instance_group_url
  health_check_self_link         = module.collector_pubsub.health_check_self_link
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.15 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.44.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 3.44.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_telemetry"></a> [telemetry](#module\_telemetry) | snowplow-devops/telemetry/snowplow | 0.2.0 |

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_health_check.hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.tpl](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_instance_group_manager.grp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_project_iam_member.sa_logging_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_pubsub_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_pubsub_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_compute_image.ubuntu_20_04](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bad_topic_name"></a> [bad\_topic\_name](#input\_bad\_topic\_name) | The name of the bad pubsub topic that the collector will insert data into | `string` | n/a | yes |
| <a name="input_good_topic_name"></a> [good\_topic\_name](#input\_good\_topic\_name) | The name of the good pubsub topic that the collector will insert data into | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | A name which will be pre-pended to the resources created | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | The name of the network to deploy within | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The name of the region to deploy within | `string` | n/a | yes |
| <a name="input_topic_project_id"></a> [topic\_project\_id](#input\_topic\_project\_id) | The project ID in which the topics are deployed | `string` | n/a | yes |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public ip address to this instance; if false this instance must be behind a Cloud NAT to connect to the internet | `bool` | `true` | no |
| <a name="input_byte_limit"></a> [byte\_limit](#input\_byte\_limit) | The amount of bytes to buffer events before pushing them to PubSub | `number` | `1000000` | no |
| <a name="input_custom_paths"></a> [custom\_paths](#input\_custom\_paths) | Optional custom paths that the collector will respond to, refer to [collector docs](https://docs.snowplowanalytics.com/docs/pipeline-components-and-applications/stream-collector/configure/#configuring-custom-paths) for structure | `map(string)` | `{}` | no |
| <a name="input_cookie_domain"></a> [cookie\_domain](#input\_cookie\_domain) | Optional first party cookie domain for the collector to set cookies on (e.g. acme.com) | `string` | `""` | no |
| <a name="input_gcp_logs_enabled"></a> [gcp\_logs\_enabled](#input\_gcp\_logs\_enabled) | Whether application logs should be reported to GCP Logging | `bool` | `true` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | The path to bind for health checks | `string` | `"/health"` | no |
| <a name="input_ingress_port"></a> [ingress\_port](#input\_ingress\_port) | The port that the collector will be bound to and expose over HTTP | `number` | `8080` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | The labels to append to this resource | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use | `string` | `"e2-small"` | no |
| <a name="input_record_limit"></a> [record\_limit](#input\_record\_limit) | The number of events to buffer before pushing them to PubSub | `number` | `500` | no |
| <a name="input_ssh_block_project_keys"></a> [ssh\_block\_project\_keys](#input\_ssh\_block\_project\_keys) | Whether to block project wide SSH keys | `bool` | `true` | no |
| <a name="input_ssh_ip_allowlist"></a> [ssh\_ip\_allowlist](#input\_ssh\_ip\_allowlist) | The list of CIDR ranges to allow SSH traffic from | `list(any)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_ssh_key_pairs"></a> [ssh\_key\_pairs](#input\_ssh\_key\_pairs) | The list of SSH key-pairs to add to the servers | <pre>list(object({<br>    user_name  = string<br>    public_key = string<br>  }))</pre> | `[]` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The name of the sub-network to deploy within; if populated will override the 'network' setting | `string` | `""` | no |
| <a name="input_target_size"></a> [target\_size](#input\_target\_size) | The number of servers to deploy | `number` | `1` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Whether or not to send telemetry information back to Snowplow Analytics Ltd | `bool` | `true` | no |
| <a name="input_time_limit_ms"></a> [time\_limit\_ms](#input\_time\_limit\_ms) | The amount of time to buffer events before pushing them to PubSub | `number` | `500` | no |
| <a name="input_ubuntu_20_04_source_image"></a> [ubuntu\_20\_04\_source\_image](#input\_ubuntu\_20\_04\_source\_image) | The source image to use which must be based of of Ubuntu 20.04; by default the latest community version is used | `string` | `""` | no |
| <a name="input_user_provided_id"></a> [user\_provided\_id](#input\_user\_provided\_id) | An optional unique identifier to identify the telemetry events emitted by this stack | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_check_id"></a> [health\_check\_id](#output\_health\_check\_id) | Identifier for the health check on the instance group |
| <a name="output_health_check_self_link"></a> [health\_check\_self\_link](#output\_health\_check\_self\_link) | The URL for the health check on the instance group |
| <a name="output_instance_group_url"></a> [instance\_group\_url](#output\_instance\_group\_url) | The full URL of the instance group created by the manager |
| <a name="output_manager_id"></a> [manager\_id](#output\_manager\_id) | Identifier for the instance group manager |
| <a name="output_manager_self_link"></a> [manager\_self\_link](#output\_manager\_self\_link) | The URL for the instance group manager |
| <a name="output_named_port_http"></a> [named\_port\_http](#output\_named\_port\_http) | The name of the port exposed by the instance group |
| <a name="output_named_port_value"></a> [named\_port\_value](#output\_named\_port\_value) | The named port value (e.g. 8080) |

# Copyright and license

The Terraform Google Collector PubSub on Compute Engine project is Copyright 2021-2021 Snowplow Analytics Ltd.

Licensed under the [Apache License, Version 2.0][license] (the "License");
you may not use this software except in compliance with the License.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[release]: https://github.com/snowplow-devops/terraform-google-collector-pubsub-ce/releases/latest
[release-image]: https://img.shields.io/github/v/release/snowplow-devops/terraform-google-collector-pubsub-ce

[ci]: https://github.com/snowplow-devops/terraform-google-collector-pubsub-ce/actions?query=workflow%3Aci
[ci-image]: https://github.com/snowplow-devops/terraform-google-collector-pubsub-ce/workflows/ci/badge.svg

[license]: https://www.apache.org/licenses/LICENSE-2.0
[license-image]: https://img.shields.io/badge/license-Apache--2-blue.svg?style=flat

[registry]: https://registry.terraform.io/modules/snowplow-devops/collector-pubsub-ce/google/latest
[registry-image]: https://img.shields.io/static/v1?label=Terraform&message=Registry&color=7B42BC&logo=terraform

[source]: https://github.com/snowplow/stream-collector
[source-image]: https://img.shields.io/static/v1?label=Snowplow&message=Stream%20Collector&color=0E9BA4&logo=GitHub
