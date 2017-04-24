#!/bin/bash
set -x

# install epel repo
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
/usr/bin/yum-config-manager --disable epel

# yup update
sudo yum -y update
sudo yum install -y python-devel python-setuptools python-virtualenv libffi-devel openssl-devel gcc
sudo yum install -y --enablerepo=epel jq

# disable root login
sudo /bin/sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sudo /sbin/service sshd restart

# install packages/pip
sudo easy_install pip
sudo pip install ansible==2.2.2.0

sudo yum -q clean all
sudo rm /root/.ssh/authorized_keys
sudo rm /home/centos/.ssh/authorized_keys
