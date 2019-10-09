output "elb_dns_name" {
  value = "${aws_elb.onica_elb.dns_name}"
}
