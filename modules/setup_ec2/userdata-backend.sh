#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y ca-certificates docker git wget

systemctl enable --now docker
usermod -aG docker ec2-user

dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm
dnf -qy module disable postgresql
dnf install -y postgresql18 postgresql18-server
/usr/pgsql-18/bin/postgresql-18-setup initdb
systemctl enable --now postgresql-18

dnf install -y https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm
dnf install -y mysql-community-server mysql-community-client
systemctl enable --now mysqld