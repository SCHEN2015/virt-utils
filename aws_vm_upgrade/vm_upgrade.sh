#!/bin/bash

# Description:
# This script is used to upgarde the RHEL VM to the private compose which can only be
# accessed from the Intranet. So you need to run this script from the Intranet and provide
# the URL of the private compose. In additional, you need to setup the localhost as a
# proxy server which can provide HTTP proxy service on port 3128 (squid).
# 
# More information about an ssh proxy:
# http://blog.csdn.net/sch0120/article/details/73744504
#
# History:
# v1.0  2018-01-23  charles.shih  Initial version.
# v1.1  2018-01-24  charles.shih  Add logic to install additional packages.
# v1.2  2018-02-01  charles.shih  Install kernel-devel RPM package during RHEL update.
# v1.3  2018-02-07  charles.shih  bugfix for missing kernel-devel package check.
# v1.4  2018-02-12  charles.shih  Clean cache before updating.
# v1.5  2018-02-15  charles.shih  Install additional packages: cryptsetup and lvm2.
# v1.6  2018-03-28  charles.shih  Allocate a tty for the connection.
# v1.7  2018-04-14  charles.shih  Disable requiretty if applicable.
# v1.8  2018-04-14  charles.shih  Exit if encountered a critical failure.
# v2.0  2018-06-28  charles.shih  Copy this script from Cloud_Test project and rename
#                                 this script from rhel_upgrade.sh to vm_upgrade.sh.
# v2.1  2018-07-04  charles.shih  Refactory vm_upgrade.sh and add do_setup_repo.sh.
# v2.2  2018-07-23  charles.shih  Refactory vm_upgrade.sh and add do_upgrade.sh.
# v2.3  2018-07-24  charles.shih  Refactory vm_upgrade.sh and do_config_repo.sh.
# v2.4  2018-07-24  charles.shih  Some bugfix in vm_upgrade.sh and do_upgrade.sh.
# v2.5  2018-07-24  charles.shih  Refactory vm_upgrade.sh and add do_setup_package.sh.
# v2.6  2018-07-24  charles.shih  Move save kernel version to do_upgrade.sh.
# v2.7  2018-07-25  charles.shih  Add reboot vm and waiting for ssh online logic.

die() { echo "$@"; exit 1; }

if [ $# -lt 3 ]; then
    echo -e "\nUsage: $0 <pem file> <instance ip / hostname> <the baseurl to be placed in repo file>\n"
    exit 1
fi

# The scripts used in the VM:
# - do_configure_repo.sh   The script to configure the repo.
# - do_upgrade.sh          The script to do system upgrade.
# - do_workaround.sh       The script to do workaround and other configuration.
# - do_setup_package.sh    The script to install specified packages.
# - do_clean_up.sh         The script to do clean up before creating the AMI.

pem=$1
instname=$2
baseurl=$3

# upload the scripts
scp -i $pem ./do_*.sh ec2-user@$instname:~
ssh -i $pem ec2-user@$instname -t "chmod 755 ~/do_*.sh"

# enable the repo
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_configure_repo.sh --setup $baseurl"
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_configure_repo.sh --enable"
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_configure_repo.sh --clean"

# upgrade the system
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_upgrade.sh 2>&1 | tee -a ~/vm_upgrade.log"
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_setup_package.sh 2>&1 | tee -a ~/vm_upgrade.log"

# disable the repo
ssh -R 8080:127.0.0.1:3128 -i $pem ec2-user@$instname -t "~/do_configure_repo.sh --disable"

# reboot the system
echo -e "\nRebooting the system..."
ssh -i $pem ec2-user@$instname -t "sudo reboot"

# waiting ssh online
while [ "$ping_state" != "OK" ] || [ "$ssh_state" != "OK" ]; do
	ping $instname -c 1 -W 2 &>/dev/null && ping_state="OK" || ping_state="FAIL"
	ssh -i $pem -o "ConnectTimeout 8" ec2-user@$instname -t "echo" &>/dev/null && ssh_state="OK" || ssh_state="FAIL"
	echo -e "\nCurrent Time: $(date +"%Y-%m-%d %H:%M:%S") | PING State: $ping_state | SSH State: $ssh_state"
done

exit 0