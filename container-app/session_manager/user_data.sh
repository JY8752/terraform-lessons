#!/bin/sh
amazon-linux-extras install -y docker

systemctl start docker
systemctl enabled docker