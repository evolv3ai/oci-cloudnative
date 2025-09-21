# Frequently asked questions

**What region should I deploy in?**

Always Free resources are only guaranteed in your home region. When in doubt, deploy the stack in the region that you selected during account signup.

**What happens if Terraform reports a capacity error?**

Ampere A1 capacity is limited per availability domain. If you receive an `out of host capacity` error, set the `availability_domain` variable to the AD that currently offers free-tier A1 capacity for your tenancy or retry later.

**Can I deploy this stack without public IP addresses?**

Yes. Set `assign_public_ip = false` and reach the servers over a private network connection such as VPN or Bastion. Remember to open the required ports on your private network appliance.

**How do I remove the resources?**

Run `terraform destroy` from `deploy/basic/terraform` to delete all resources created by the stack.
