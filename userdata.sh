#!/bin/bash
#sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

### Add the Required Repositories.
sudo tee /etc/yum.repos.d/pritunl.repo <<EOF
[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/amazonlinux/2/
gpgcheck=1
enabled=1
EOF

### Add the EPEL repository to provide other packages required
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

### Add the MongoDB repository on Amazon Linux 2
sudo tee /etc/yum.repos.d/mongodb-org-5.repo <<EOF
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc
EOF

#Proceed to import the GPG key signing.
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A
sudo gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A >key.tmp
sudo rpm --import key.tmp
sudo rm -f key.tmp

### Install Pritunl VPN server on Amazon Linux 2
sudo yum install pritunl mongodb-org -y
sudo systemctl enable --now mongod pritunl

### Generate Data access server
sudo pritunl setup-key >/tmp/pritunl_setup_key.log
