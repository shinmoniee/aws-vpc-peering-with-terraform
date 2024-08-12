output "test_instructions" {
  description = "Instructions for testing the setup"
  value = <<EOT

1. SSH into Server-AB or Server-AC using their public IPs.
   Server-AB Public IP: ${aws_instance.servers["ab"].public_ip}
   Server-AC Public IP: ${aws_instance.servers["ac"].public_ip}

2. From Server-AB, try to ping Server-B:
   Server-B Private IP: ${aws_instance.servers["b"].private_ip}

3. To test connectivity with Server-C:
   a. Go to the AWS VPC Console
   b. Find the route table for VPC-A
   c. Edit the route for 192.168.0.0/16
   d. Change the target to the peering connection with VPC-C

4. After changing the route, from Server-AC, try to ping Server-C:
   Server-C Private IP: ${aws_instance.servers["c"].private_ip}

5. Remember to switch the route back to the peering connection with VPC-B if you want to test connectivity with Server-B again.

EOT
}