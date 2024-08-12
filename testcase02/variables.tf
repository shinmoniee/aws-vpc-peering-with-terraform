variable "region" {
  description = "AWS region"
  default     = "ap-southeast-1"
}

variable "vpcs" {
  description = "VPC configurations"
  type = map(object({
    cidr_block = string
    subnets = map(string)
  }))
  default = {
    a = {
      cidr_block = "10.1.0.0/16"
      subnets = {
        subnet1 = "10.1.1.0/24"
        subnet2 = "10.1.2.0/24"
      }
    },
    b = {
      cidr_block = "192.168.0.0/16"
      subnets = {
        subnet1 = "192.168.1.0/24"
      }
    },
    c = {
      cidr_block = "192.168.0.0/16"
      subnets = {
        subnet1 = "192.168.2.0/24"
      }
    }
  }
}

locals {
  vpc_names = keys(var.vpcs)
}