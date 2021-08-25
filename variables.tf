variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

variable "region" {
  description = "The name of the region to deploy within"
  type        = string
}

variable "network" {
  description = "The name of the network to deploy within"
  type        = string
}

variable "subnetwork" {
  description = "The name of the sub-network to deploy within; if populated will override the 'network' setting"
  type        = string
  default     = ""
}

variable "ingress_port" {
  description = "The port that the collector will be bound to and expose over HTTP"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "The path to bind for health checks"
  type        = string
  default     = "/health"
}

variable "machine_type" {
  description = "The machine type to use"
  type        = string
  default     = "e2-small"
}

variable "target_size" {
  description = "The number of servers to deploy"
  default     = 1
  type        = number
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance; if false this instance must be behind a Cloud NAT to connect to the internet"
  type        = bool
  default     = true
}

variable "ssh_ip_allowlist" {
  description = "The list of CIDR ranges to allow SSH traffic from"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "ssh_block_project_keys" {
  description = "Whether to block project wide SSH keys"
  type        = bool
  default     = true
}

variable "ssh_key_pairs" {
  description = "The list of SSH key-pairs to add to the servers"
  default     = []
  type = list(object({
    user_name  = string
    public_key = string
  }))
}

variable "ubuntu_20_04_source_image" {
  description = "The source image to use which must be based of of Ubuntu 20.04; by default the latest community version is used"
  default     = ""
  type        = string
}

variable "labels" {
  description = "The labels to append to this resource"
  default     = {}
  type        = map(string)
}

variable "gcp_logs_enabled" {
  description = "Whether application logs should be reported to GCP Logging"
  default     = true
  type        = bool
}

# --- Configuration options

variable "topic_project_id" {
  description = "The project ID in which the topics are deployed"
  type        = string
}

variable "good_topic_name" {
  description = "The name of the good pubsub topic that the collector will insert data into"
  type        = string
}

variable "bad_topic_name" {
  description = "The name of the bad pubsub topic that the collector will insert data into"
  type        = string
}

variable "cookie_domain" {
  description = "Optional first party cookie domain for the collector to set cookies on (e.g. acme.com)"
  default     = ""
  type        = string
}

variable "byte_limit" {
  description = "The amount of bytes to buffer events before pushing them to PubSub"
  default     = 1000000
  type        = number
}

variable "record_limit" {
  description = "The number of events to buffer before pushing them to PubSub"
  default     = 500
  type        = number
}

variable "time_limit_ms" {
  description = "The amount of time to buffer events before pushing them to PubSub"
  default     = 500
  type        = number
}

# --- Telemetry

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}
