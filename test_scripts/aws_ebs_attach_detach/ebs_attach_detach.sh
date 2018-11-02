#!/bin/bash

# History:
# v1.0  2018-05-21  charles.shih  init version

set -e	# exit when error occurred

host=
pem=/home/cheshi/.pem/rhui-dev-cheshi.pem
inst_id=i-016a424b045119b61
vol1_id=vol-098ec788160aa7dc2
vol2_id=vol-0b51dfb969c6f0c0c
vol3_id=vol-0d814fb743e5d2b29
vol4_id=vol-074f574e2049d7560

function get_dns_by_instid()
{
	# $1 - Instance ID
	# output: $host

	host=$(aws ec2 describe-instances --instance-ids $1 --query 'Reservations[].Instances[].PublicDnsName' --output text)
}

function guest_exec()
{
	echo "InstID: $inst_id PEM: $pem UserName: ec2-user Host: $host"
	ssh -o StrictHostKeyChecking=no -i $pem -l ec2-user $host "$@"
}

function wait_volume_stat()
{
	if [ "$1" = "available" ] || [ "$1" = "attached" ]; then
		stat=$1
	else
		sleep 60s && echo "** Waited 60 seconds for unknown status \"$1\" **"
		return
	fi

	round=0
	count=0
	until [[ $count -eq 4 ]] || [[ $round -gt 3000 ]]; do
                let "round=round+1"
                count=$(aws ec2 describe-volumes --volume-ids $vol1_id $vol2_id $vol3_id $vol4_id | grep $stat | wc -l)
                echo "** $(date +"%Y-%m-%d %H:%M:%S") * \"$stat\" ($count of 4) **"
                sleep 1s
	done
}


# Main
get_dns_by_instid $inst_id

for i in {1..100}; do
	echo -e "\nRound times: $i"

	# Attach Volume
	echo -e "\nAttaching..."
	aws ec2 attach-volume --volume-id $vol1_id --instance-id $inst_id --device /dev/sdf
	aws ec2 attach-volume --volume-id $vol2_id --instance-id $inst_id --device /dev/sdg
	aws ec2 attach-volume --volume-id $vol3_id --instance-id $inst_id --device /dev/sdh
	aws ec2 attach-volume --volume-id $vol4_id --instance-id $inst_id --device /dev/sdi
	wait_volume_stat "attached"

	echo -e "\nMounting..."
	#guest_exec 'for i in {f,g,h,i}; do sudo mkdir -p /mnt/$i; sudo mount /dev/xvd$i /mnt/$i; done && lsblk'
	guest_exec 'for i in {1,2,3,4}; do sudo mkdir -p /mnt/nvme${i}n1; sudo mount /dev/nvme${i}n1 /mnt/nvme${i}n1; done && lsblk'
	sleep 2s

	echo -e "\nUmounting..."
	#guest_exec 'for i in {f,g,h,i}; do sudo umount /dev/xvd$i; done && lsblk'
	guest_exec 'for i in {1,2,3,4}; do sudo umount /dev/nvme${i}n1; done && lsblk'

	# Detach Volume
	echo -e "\nDetaching..."
	aws ec2 detach-volume --volume-id $vol1_id --instance-id $inst_id
	aws ec2 detach-volume --volume-id $vol2_id --instance-id $inst_id
	aws ec2 detach-volume --volume-id $vol3_id --instance-id $inst_id
	aws ec2 detach-volume --volume-id $vol4_id --instance-id $inst_id
	wait_volume_stat "available"
done

exit 0

