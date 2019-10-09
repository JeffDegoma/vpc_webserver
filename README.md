# vpc_webserver

### Run:
`git clone https://github.com/JeffDegoma/vpc_webserver.git`

### Inside cloned directory, run:
- `terraform init`
- `terraform plan`
- `terraform apply`

### Return ELB endpoint
- `aws elb describe-load-balancers --load-balancer-names=onica-elb`
- output of `DNSName` will be ELB endpoint

### Tear down, run:
- `terraform destroy` 
