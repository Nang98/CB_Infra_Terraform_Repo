variable "availability_zones" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b"] 
}

variable "app_ami" {
  type = string
  default = "ami-0166fe664262f664c"
}