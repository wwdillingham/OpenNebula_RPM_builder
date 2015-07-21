#!/bin/bash
#HOME is not set on init and it is needed by rpmbuild in the OpenNebula_RPM_builder script
export HOME=/tmp/launch 
env > /tmp/i_ran
source /mnt/context.sh
yum install -y epel-release
yum install -y git wget rpm-build gcc make yum-utils scons
git clone https://github.com/wwdillingham/OpenNebula_RPM_builder $HOME
cd $HOME
bash open_nebula_rpm_roller.sh 2>&1 > /tmp/build.log
