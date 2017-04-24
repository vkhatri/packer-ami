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

sudo yum -q clean all
sudo rm /root/.ssh/authorized_keys
sudo rm /home/ec2-user/.ssh/authorized_keys
