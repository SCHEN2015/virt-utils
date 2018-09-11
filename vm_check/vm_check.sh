#!/bin/bash

# Description:
# This script is used to get general information in Linux OS by running varity of
# Linux commands. Some of them require super user permission, so this script should be
# running by root.
#
# History:
# v1.0     2018-06-26  charles.shih  Initial version
# v1.1     2018-07-10  charles.shih  Add commands for cloud-init and others
# v1.2     2018-07-12  charles.shih  Add commands lspci
# v1.3     2018-07-13  charles.shih  Remove command cat /proc/kmsg
# v2.0     2018-07-13  charles.shih  Support running on Non-AWS
# v2.1     2018-07-16  charles.shih  Remove command cat /proc/kpage*
# v2.2     2018-07-16  charles.shih  Add some commands for network and cloud-init
# v2.3     2018-07-20  charles.shih  Add some commands for network
# v2.4     2018-07-20  charles.shih  Add some command journalctl to get system log
# v2.5     2018-08-15  charles.shih  Add message to show where the log is saved to
# v2.6     2018-08-15  charles.shih  Add /usr/local/sbin:/usr/sbin into PATH
# v2.7     2018-08-15  charles.shih  Install package redhat-lsb
# v2.8     2018-08-28  charles.shih  Auto add sudo before commands
# v2.9     2018-08-28  charles.shih  Save error outputs into *.log.err
# v2.10    2018-08-28  charles.shih  Display error messages when command failure
# v2.11    2018-08-28  charles.shih  Modify some commands and do some enhancement
# v2.11.1  2018-09-10  charles.shih  Fix a typo in command

# Notes:
# On AWS the default user is ec2-user and it is an sudoer without needing a password;
# On Azure and Aliyun the default user is root.

show_inst_type() {
	# AWS
	inst_type=$(curl http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null)
	[ ! -z "$inst_type" ] && echo $inst_type && return 0

	# Azure
	inst_type=$(curl http://169.254.169.254/meta-data/instance-type 2>/dev/null)
	[ ! -z "$inst_type" ] && echo $inst_type && return 0

	# To be supported
	return 1
}

function run_cmd(){
	# $1: Command to be executed
	# $2: The filename where log to be saved (optional)

	# If not root, lead the command with 'sudo'
	[ $(whoami) = root ] && cmd="$1" || cmd="sudo $1"

	if [ -z "$2" ]; then
		cmdlog=$base/$(echo $cmd | tr -c "[:alpha:][:digit:]" "_").log
	else
		cmdlog=$base/$2
	fi

	echo -e "\ncmd> $cmd" >> $joblog
	echo -e "log> $cmdlog[.err]" >> $joblog
	eval $cmd > $cmdlog 2> $cmdlog.err
	
	rcode=$?
	if [ $rcode != 0 ]; then
		echo -e "\ncmd> $cmd"
		cat $cmdlog.err
    fi

    return $rcode
}

export PATH=$PATH:/usr/local/sbin:/usr/sbin

# Prepare environment
inst_type=$(show_inst_type)
time_stamp=$(date +%Y%m%d%H%M%S)
base="$HOME/workspace/log/vm_check_${inst_type:=unknown}_${time_stamp=random$$}"
mkdir -p $base
joblog=$base/job.txt

# Waiting for Bootup finished
while [[ "$(sudo systemd-analyze time 2>&1)" =~ "Bootup is not yet finished" ]]; do
	echo "[$(date)] Bootup is not yet finished." >> $joblog
	sleep 2s
done

echo -e "\n\nInstallation:\n===============\n" >> $joblog

# install
sudo yum install sysstat -y &>> $joblog
sudo yum install redhat-lsb -y &>> $joblog

echo -e "\n\nTest Results:\n===============\n" >> $joblog

# Start VM check

# boot
run_cmd 'systemd-analyze time'
run_cmd 'systemd-analyze blame'
run_cmd 'systemd-analyze critical-chain'
run_cmd 'systemd-analyze dot'
run_cmd 'systemctl'

# virtualization
run_cmd 'virt-what'

# system
run_cmd 'cat /proc/version'
run_cmd 'uname -r'
run_cmd 'uname -a'
run_cmd 'lsb_release -a'
run_cmd 'cat /etc/redhat-release'
run_cmd 'cat /etc/issue'

# bios and hardware
run_cmd 'dmidecode -t bios'
run_cmd 'lspci'
run_cmd 'lspci -v'
run_cmd 'lspci -vv'
run_cmd 'lspci -vvv'

# package
run_cmd 'rpm -qa'

# kernel
run_cmd 'lsmod'
run_cmd 'date'
run_cmd 'cat /proc/uptime'
run_cmd 'uptime'
run_cmd 'top -b -n 1'
run_cmd 'bash -c set'
run_cmd 'env'
run_cmd 'systemctl'
run_cmd 'vmstat 3 1'
run_cmd 'vmstat -m'
run_cmd 'vmstat -a'
run_cmd 'w'
run_cmd 'who'
run_cmd 'whoami'
run_cmd 'ps -A'
run_cmd 'ps -Al'
run_cmd 'ps -AlF'
run_cmd 'ps -AlFH'
run_cmd 'ps -AlLm'
run_cmd 'ps -ax'
run_cmd 'ps -axu'
run_cmd 'ps -ejH'
run_cmd 'ps -axjf'
run_cmd 'ps -eo euser,ruser,suser,fuser,f,comm,label'
run_cmd 'ps -axZ'
run_cmd 'ps -eM'
run_cmd 'ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm'
run_cmd 'ps -axo stat,euid,ruid,tty,tpgid,sess,pgrp,ppid,pid,pcpu,comm'
run_cmd 'ps -eo pid,tt,user,fname,tmout,f,wchan'
run_cmd 'free'
run_cmd 'free -k'
run_cmd 'free -m'
run_cmd 'free -h'
run_cmd 'cat /proc/meminfo'
run_cmd 'lscpu'
run_cmd 'cat /proc/cpuinfo'
run_cmd 'mpstat -P ALL'
run_cmd 'sar -n DEV'
run_cmd 'iostat'
run_cmd 'netstat -tulpn'
run_cmd 'netstat -nat'
run_cmd 'ss -t -a'
run_cmd 'ss -u -a'
run_cmd 'ss -t -a -Z'
run_cmd 'cat /proc/zoneinfo'
run_cmd 'cat /proc/mounts'
run_cmd 'cat /proc/interrupts'
run_cmd 'cat /var/log/messages'
run_cmd 'dmesg'
run_cmd 'dmesg -l emerg'
run_cmd 'dmesg -l alert'
run_cmd 'dmesg -l crit'
run_cmd 'dmesg -l err'
run_cmd 'dmesg -l warn'
run_cmd 'dmesg -l notice'
run_cmd 'dmesg -l info'
run_cmd 'dmesg -l debug'
run_cmd 'dmesg -f kern'
run_cmd 'dmesg -f user'
run_cmd 'dmesg -f mail'
run_cmd 'dmesg -f daemon'
run_cmd 'dmesg -f auth'
run_cmd 'dmesg -f syslog'
run_cmd 'dmesg -f lpr'
run_cmd 'dmesg -f news'
run_cmd 'journalctl'

# block
run_cmd 'lsblk'
run_cmd 'lsblk -p'
run_cmd 'lsblk -d'
run_cmd 'lsblk -d -p'
run_cmd 'df -k'
run_cmd 'fdisk -l'

# network
run_cmd 'ifconfig -a'
run_cmd 'ethtool eth0'
run_cmd 'ethtool -a eth0'
run_cmd 'ethtool -i eth0'
run_cmd 'ethtool -c eth0'
run_cmd 'ethtool -g eth0'
run_cmd 'ethtool -k eth0'
run_cmd 'ethtool -n eth0'
run_cmd 'ethtool -T eth0'
run_cmd 'ethtool -x eth0'
run_cmd 'ethtool -P eth0'
run_cmd 'ethtool -l eth0'
run_cmd 'ethtool -S eth0'
run_cmd 'ethtool --phy-statistics eth0'
run_cmd 'ethtool --show-priv-flags eth0'
run_cmd 'ethtool --show-eee eth0'
run_cmd 'ethtool --show-fec eth0'
run_cmd 'ip link'
run_cmd 'ip address'
run_cmd 'ip addrlabel'
run_cmd 'ip route'
run_cmd 'ip rule'
run_cmd 'ip neigh'
run_cmd 'ip ntable'
run_cmd 'ip tunnel'
run_cmd 'ip tuntap'
run_cmd 'ip maddress'
run_cmd 'ip mroute'
run_cmd 'ip mrule'
run_cmd 'ip netns'
run_cmd 'ip l2tp show tunnel'
run_cmd 'ip l2tp show session'
run_cmd 'ip macsec show'
run_cmd 'ip tcp_metrics'
run_cmd 'ip token'
run_cmd 'ip netconf'
run_cmd 'ip ila list'
run_cmd 'hostname'
run_cmd 'cat /etc/hostname'
run_cmd 'cat /etc/hosts'
run_cmd 'ping -c 1 8.8.8.8'
run_cmd 'ping6 -c 1 2001:4860:4860::8888'

# cloud-init
run_cmd 'cat /var/log/cloud-init.log'
run_cmd 'cat /var/log/cloud-init-output.log'
run_cmd 'service cloud-init status'
run_cmd 'service cloud-init-local status'
run_cmd 'service cloud-config status'
run_cmd 'service cloud-final status'
run_cmd 'systemctl status cloud-{init,init-local,config,final}'

# others
run_cmd 'cat /proc/buddyinfo'
run_cmd 'cat /proc/cgroups'
run_cmd 'cat /proc/cmdline'
run_cmd 'cat /proc/consoles'
run_cmd 'cat /proc/crypto'
run_cmd 'cat /proc/devices'
run_cmd 'cat /proc/diskstats'
run_cmd 'cat /proc/dma'
run_cmd 'cat /proc/execdomains'
run_cmd 'cat /proc/fb'
run_cmd 'cat /proc/filesystems'
run_cmd 'cat /proc/iomem'
run_cmd 'cat /proc/ioports'
run_cmd 'cat /proc/kallsyms'
run_cmd 'cat /proc/keys'
run_cmd 'cat /proc/key-users'
run_cmd 'cat /proc/loadavg'
run_cmd 'cat /proc/locks'
run_cmd 'cat /proc/mdstat'
run_cmd 'cat /proc/misc'
run_cmd 'cat /proc/modules'
run_cmd 'cat /proc/mtrr'
run_cmd 'cat /proc/pagetypeinfo'
run_cmd 'cat /proc/partitions'
run_cmd 'cat /proc/sched_debug'
run_cmd 'cat /proc/schedstat'
run_cmd 'cat /proc/slabinfo'
run_cmd 'cat /proc/softirqs'
run_cmd 'cat /proc/stat'
run_cmd 'cat /proc/swaps'
run_cmd 'cat /proc/sysrq-trigger'
run_cmd 'cat /proc/timer_list'
run_cmd 'cat /proc/timer_stats'
run_cmd 'cat /proc/vmallocinfo'
run_cmd 'cat /proc/vmstat'

echo -e "\nLog files have been generated in \"$base\";"
echo -e "More details can be found in \"$joblog\"."

exit 0
