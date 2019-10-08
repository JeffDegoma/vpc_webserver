
resource "aws_vpc" "onica_vpc" {
  cidr_block        =    "${var.vpc_cidr}"

  tags {
    "Environment"   =  "${var.environment}"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id          =    "${aws_vpc.onica_vpc.id}"
}

//subnets
resource "aws_subnet" "public" {
    count           =   "${length(var.subnet_cidr)}"
    vpc_id          =   "${aws_vpc.onica_vpc.id}"
    cidr_block      =   "${element(var.subnet_cidr,count.index)}"
    availability_zone   =  "${element(var.az, count.index)}"
}


//route tables
resource "aws_route_table" "public_route" {
  vpc_id            =   "${aws_vpc.onica_vpc.id}"

  route {
      cidr_block    =   "0.0.0.0/0"
      gateway_id    =   "${aws_internet_gateway.igw.id}"
  }
  tags {
      Name          =   "public_route_table"
  }
}

//route table association
resource "aws_route_table_association" "a" {
  count             =   "${length(var.subnet_cidr)}"
  subnet_id         =   "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id    =   "${aws_route_table.public_route.id}"
}


##############################################################################################################
##############################################################################################################
#WEBSERVER
##############################################################################################################
##############################################################################################################

data "template_file" "nginx" {
  template        =   "${file("${path.module}/cloud.cfg")}"
}

data "template_file" "script" {
  template        =   "${file("${path.module}/userdata.sh")}"
}


# Launch Configuration
resource "aws_launch_configuration" "onica_launch" {
    name                    =   "config"
    image_id                =   "ami-0b69ea66ff7391e80"
    instance_type           =   "t2.micro"
    security_groups         =   ["${aws_security_group.instance_sg.id}"]
    associate_public_ip_address = true
    key_name                =   "prgrmmr_1"

    user_data             =   "${data.template_cloudinit_config.config.rendered}"

    lifecycle {
        create_before_destroy = true #create replacement resource before destroying the original resource
    }
}

resource "aws_autoscaling_group" "onica" {
  launch_configuration      =   "${aws_launch_configuration.onica_launch.name}" #name of launch configuration
  load_balancers            =   ["${aws_elb.onica_elb.id}"]
  vpc_zone_identifier       =   ["${aws_subnet.public.*.id}"]
  

  health_check_type         =   "ELB"

  min_size                  =   2
  max_size                  =   2
  desired_capacity          =   2

  tag {
      key                  =   "Name"
      value                =   "onica_webserver"
      propagate_at_launch  =   true
  }
}


#Security Group for ELB
resource "aws_security_group" "elb_sg" {
    name                    =   "onica-elb-sg"
    vpc_id                  =   "${aws_vpc.onica_vpc.id}"


    ingress {
        from_port           =   "${var.server_port}"
        to_port             =   "${var.server_port}"
        protocol            =   "tcp"
        cidr_blocks         =   "${var.cidr_range}"
    }

    egress {
        from_port           =   0
        to_port             =   0
        protocol            =   "-1"
        cidr_blocks         =   "${var.cidr_range}"
    }

}


resource "aws_elb" "onica_elb" {
    name                    =   "onica-elb"
    security_groups         =   ["${aws_security_group.elb_sg.id}"] 
    subnets                 =   ["${aws_subnet.public.*.id}"]
    cross_zone_load_balancing   = true

    listener {
        lb_port                 =   80
        lb_protocol             =   "http"
        instance_port           =   "${var.server_port}"
        instance_protocol       =   "http"
    }

    health_check {
        healthy_threshold       =   2
        unhealthy_threshold     =   2
        timeout                 =   3
        interval                =   40
        target                  =   "HTTP:${var.server_port}/" #nginx port
    }

}

#Security Group for instance
resource "aws_security_group" "instance_sg" {
    name                      =   "onica-instance-sg"
    vpc_id                  =   "${aws_vpc.onica_vpc.id}"

    ingress {
        from_port           =   "${var.server_port}"
        to_port             =   "${var.server_port}"
        protocol            =   "tcp"
        cidr_blocks         =   "${var.cidr_range}"
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = "${var.cidr_range}"
    }

    egress {
        from_port           =   0
        to_port             =   0
        protocol            =   "-1"
        cidr_blocks         =   "${var.cidr_range}"
    }
    lifecycle   {
        create_before_destroy   =   true
    }
}

data "template_cloudinit_config" "config" {
    part {
        content_type        =  "text/x-shellscript"
        content             =   "${data.template_file.script.rendered}"
    }
    part {
        content_type        =  "text/cloud-config"
        content             =  "${data.template_file.nginx.rendered}"
    }
}

