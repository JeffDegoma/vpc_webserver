#!/bin/bash
    sudo yum update
    sudo amazon-linux-extras install epel -y
    sudo yum -y install nginx

    wait 10s

    sudo service nginx start
# ≥ /
