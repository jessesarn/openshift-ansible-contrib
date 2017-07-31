#!/bin/bash

# Parameters:
# -i INV          path to ansible inventory (relative path)
# -e nodes=NUMBER number of nodes after upscaling 
# -h              displays script information, usage
# -v              sets verbosity in ansible-playbook

# Variables
ANSIBLE_PARAMS="--user openshift --private-key ~/.ssh/openshift"
INVENTORY=
EXTERNAL_VAR=
VERBOSE= # for now, it means -vvv
USAGE="Description: This script runs up-scaling method.

Usage: `basename $0` [-h] [-e nodes=N] -i path_to_inventory

Parameters:
-h                    Display this message.
-v                    Set output verbosity (to -vvv).
-i path_to_inventory  Set inventory directory (relative path).
-e nodes=N            Set number of nodes after autoscaling.
                      If not set, deployment is incremented by 1 by default."

# Parse arguments
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
    -e|--external)
      EXTERNAL_VAR="$2"
      shift;shift
      ;;
    -i|--inventory)
      INVENTORY="$2"
      if [[ ! -d $INVENTORY ]]; then
        echo "$INVENTORY is not a directory." >&2
        exit 1
      fi
      shift;shift
      ;;
    -h|--help)
      echo "$USAGE"
      exit 0
      ;;
    -v|--verbose)
      VERBOSE="-vvv"
      shift
      ;;
    *)
      echo "Unknown argument '$arg'." >&2
      exit 1
      ;;
  esac
done

# Check that required variable is empty
if [[ -z "${INVENTORY}" ]]; then
  echo "Parameter -i is required. For more information, use -h|--help"
  exit 1
fi

# Run upscaling_pre-tasks.yaml to:
# - do preverification based on entered number of nodes
# - update openstack_num_nodes variable in inventory

ansible-playbook $ANSIBLE_PARAMS -i "$INVENTORY" \
openshift-ansible-contrib/playbooks/upscaling_pre-tasks.yaml \
-e "$EXTERNAL_VAR" -e "inv_directory=${INVENTORY%/}" $VERBOSE

# Check that pre-tasks were successfully completed
if [[ $? -ne 0 ]]; then
  exit 1
fi

# Run upscaling_scale-up.yaml to rerun provisioning and installation
# and verify the result
ansible-playbook $ANSIBLE_PARAMS -i "$INVENTORY" \
openshift-ansible-contrib/playbooks/upscaling_scale-up.yaml \
-e "$EXTERNAL_VAR" $VERBOSE
