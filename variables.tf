variable "ssh_key" {
  description = "SSh key to deploy on AWS instance"
  type        = string
  default     = ""
}
variable "secret_key" {
  description = "secret_key to aws"
  type        = string
  default     = ""
}
variable "access_key" {
  description = "access_key to aws"
  type        = string
  default     = ""

}