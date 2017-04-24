#!/bin/bash

# variables list
#
# AMI_NAME=ami name to create
# AMI_GROUPS=to make ami public, set value to all
# AMI_USERS=aws account id
# AMI_REGIONS=aws region name|all
# SOURCE_AMI_EBS_TYPE=ebs volume type (gp2)
# SOURCE_AMI_ROOT_DISK_TYPE=ami rood disk type (instance-store, ebs)
# SOURCE_AMI_VIRTUALIZATION_TYPE=ami virtualization type (hvm, pvm)
# PACKER_TEMPLATE_FILE=overrides default packer template file location

# default variables
export AMI_REGIONS=us-east-1
export SOURCE_AMI_EBS_TYPE=gp2
export SOURCE_AMI_ROOT_DISK_TYPE=ebs
export SOURCE_AMI_VIRTUALIZATION_TYPE=hvm

help() {
  echo "AMI Build Script using Packer."
  echo
  echo "Options:"
  echo "  -A (optional):  aws access key id, ENV Variable AWS_ACCESS_KEY_ID"
  echo "  -S (optional):  aws secret access key, ENV Variable AWS_SECRET_ACCESS_KEY"
  echo "  -n (required):  ami name"
  echo "  -r (optinal):   aws region for ami build, default set to us-east-1"
  echo "  -g (optional):  ami groups"
  echo "  -u (optional):  ami users"
  echo "  -e (optional):  source ami ebs type, default set to gp2"
  echo "  -y (optional):  source ami root disk type, default set to ebs"
  echo "  -v (optional):  source ami virtualization type, default set to hvm"
  echo "  -t (optional):  packer template file, default to {ami name}.json"
  echo
  echo e.g. bash build-all-amis.sh -n amazon-linux-ecs
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts :n:v:d:y:r:e:h flag; do
	case $flag in
		A) export AWS_ACCESS_KEY_ID=$OPTARG ;;
		S) export AWS_SECRET_ACCESS_KEY=$OPTARG ;;
		n) export AMI_NAME=$OPTARG ;;
    r) export AMI_REGIONS=$OPTARG ;;
    g) export AMI_GROUPS=$OPTARG ;;
    u) export AMI_USERS=$OPTARG ;;
    e) export SOURCE_AMI_EBS_TYPE=$OPTARG ;;
    y) export SOURCE_AMI_ROOT_DISK_TYPE=$OPTARG ;;
    v) export SOURCE_AMI_VIRTUALIZATION_TYPE=$OPTARG ;;
    t) export PACKER_TEMPLATE_FILE=$OPTARG ;;
    h) help; exit 1 ;;
    \?) echo "Invalid option -$OPTARG"; exit 1 ;;
    :) echo "Missing value for option -$OPTARG"; exit 1 ;;
	esac
done

function ami_regions() {
  # return regions to iterate for ami build
  if [ "$AMI_REGION" == "all" ]; then
		lookup_str="$AMI_NAME,$SOURCE_AMI_VIRTUALIZATION_TYPE,$SOURCE_AMI_ROOT_DISK_TYPE,$SOURCE_AMI_EBS_TYPE"
		AMI_REGIONS=`grep $lookup_str files/sourceamis | cut -f5 -d, | uniq`
  fi
}

function pre_run() {
  # validate packer is installed
  if [ -z "$(which packer)" ]; then
    echo "error: Cannot find Packer, please make sure it's installed"
    exit 1
  fi

  # validate variables
  : "${AWS_ACCESS_KEY_ID?set variable AWS_ACCESS_KEY_ID or option -A}"
  : "${AWS_SECRET_ACCESS_KEY?set variable AWS_SECRET_ACCESS_KEY or option -S}"
  : "${AMI_NAME?set variable AMI_NAME or option -n}"
  : "${AMI_REGIONS?set variable AMI_REGIONS or option -r}"
  : "${SOURCE_AMI_EBS_TYPE?set variable SOURCE_AMI_EBS_TYPE or option -e}"
  : "${SOURCE_AMI_ROOT_DISK_TYPE?set variable SOURCE_AMI_ROOT_DISK_TYPE or option -y}"
  : "${SOURCE_AMI_VIRTUALIZATION_TYPE?set variable SOURCE_AMI_VIRTUALIZATION_TYPE or option -v}"
}

function source_ami() {
  # usage: ami_id_lookup awsRegion
  #   e.g.
  #     ami_id_lookup ami_name virtualization_type root_device_type ebs_type
  #     ami_id_lookup amazon-linux-ecs hvm ebs gp2 us-west-1
  aws_region=$1
  if [ -z "$aws_region" ]; then
    echo Must provide a valid AWS Region to lookup source ami
    exit 1
  fi

  echo "Looking up Ami ID for $AMI_NAME,$SOURCE_AMI_VIRTUALIZATION_TYPE,$SOURCE_AMI_ROOT_DISK_TYPE,$SOURCE_AMI_EBS_TYPE,$aws_region"
  lookup_str="$AMI_NAME,$SOURCE_AMI_VIRTUALIZATION_TYPE,$SOURCE_AMI_ROOT_DISK_TYPE,$SOURCE_AMI_EBS_TYPE,$1"
  source_ami_id=`grep $lookup_str files/sourceamis | cut -f6 -d,`
  if [ -z "$source_ami_id" ]; then
    echo no source ami found for search string $lookup_str
    exit 1
  else
    export SOURCE_AMI_ID=$source_ami_id
    return
  fi
}

function log_file() {
  # create separate log file for each region
	export LOG_FILE=$(mktemp /tmp/packer_${AMI_NAME}_${SOURCE_AMI_VIRTUALIZATION_TYPE}_${SOURCE_AMI_ROOT_DISK_TYPE}_${SOURCE_AMI_EBS_TYPE}-XXX)
}

function template_file() {
  if [ -z "$PACKER_TEMPLATE_FILE" ]; then
    export PACKER_TEMPLATE_FILE=templates/${AMI_NAME}.json
  else
    export PACKER_TEMPLATE_FILE=$PACKER_TEMPLATE_FILE
  fi
}

function ami_groups() {
  if [ -n "${RELEASE+x}" ]; then
	  export AMI_GROUPS="all"
  fi
}

function exec_packer() {
  export AMI_REGION=$1
  log_file
  source_ami $AMI_REGION

	echo ---
  echo "Build Details."
	echo "  Ami Name: $AMI_NAME"
	echo "  Ami Region: $AMI_REGION"
  echo "  Ami Packer Template: $PACKER_TEMPLATE_FILE"
	echo "  Source Ami Id: $SOURCE_AMI_ID"
  echo "  Source AMI Ebs Voume Type: $SOURCE_AMI_EBS_TYPE"
  echo "  Source AMI Root Disk Type: $SOURCE_AMI_ROOT_DISK_TYPE"
  echo "  Source AMI Virtualization Type: $SOURCE_AMI_VIRTUALIZATION_TYPE"
	echo
	echo "Running Packer Validate on $PACKER_TEMPLATE_FILE .."
  packer validate $PACKER_TEMPLATE_FILE
  if [ "$?" != 0 ]; then
    exit 1
  fi

  echo "Running Packer Inspect on $PACKER_TEMPLATE_FILE .."
  packer inspect $PACKER_TEMPLATE_FILE

  echo "Running Packer Build on $PACKER_TEMPLATE_FILE .."
  packer build $PACKER_TEMPLATE_FILE | tee $LOG_FILE
  if [ "$?" != 0 ]; then
    echo
    echo Packer Run Failed.
    exit 1
  fi

  tail $LOG_FILE
  rm $LOG_FILE
}

function build_regions() {
	for REGION in $AMI_REGIONS; do
		ami_groups
		exec_packer "${REGION}"
	done
}

pre_run
ami_regions
template_file
build_regions
echo
