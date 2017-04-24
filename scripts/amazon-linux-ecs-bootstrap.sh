#!/bin/bash
set -x

# yup update
sudo yum -y update
sudo yum -y install python27-devel python27-pip python27-virtualenv libffi-devel openssl-devel jq gcc

# disable root login
sudo /bin/sed -i 's/PermitRootLogin forced-commands-only/PermitRootLogin no/g' /etc/ssh/sshd_config
sudo /sbin/service sshd restart

# install packages/pip
sudo pip install --upgrade pip
sudo alternatives --install /usr/bin/pip pip /usr/local/bin/pip2.7 100
sudo pip install ansible==2.2.2.0

# cleanup
sudo yum -q clean all
sudo stop ecs || true
sudo docker rm ecs-agent 2> /dev/null || true
sudo rm -rf /var/log/ecs/* /var/lib/ecs/data/*
sudo rm /root/.ssh/authorized_keys
sudo rm /home/ec2-user/.ssh/authorized_keys
