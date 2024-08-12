variable "region" {
    description = "AWS region"
    default = "ap-southeast-1"
}

variable "vpcs" {
    description = "VPC configurations"
    type = map(object({
      cidr_block = string
      subnet_cidr = string 
    }))
    default = {
      a = { cidr_block = "10.1.0.0/16", subnet_cidr = "10.1.1.0/24" },
      b = { cidr_block = "192.168.0.0/16", subnet_cidr = "192.168.1.0/24" },
      c = { cidr_block = "192.168.0.0/16", subnet_cidr = "192.168.2.0/24" }
    }
}