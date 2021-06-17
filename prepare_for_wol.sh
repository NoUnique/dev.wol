#!/bin/bash

##############
#
# This script is modified from
# dhutchison/container-images/homebridge/configure_docker_networks_for_wol.sh
#
# This script will set the required kernel network settings to 
# allow broadcast traffic to be sent from a docker network
# to another network.
# 
# This sets using both "sysctl -w" as well as configuring a file in
# "/etc/sysctl.d/" so the change will persist a reboot. 
#
##############

# The name of the network the docker container will be connected to
DOCKER_NETWORK=traefik
PATH_CONFIG=/etc/sysctl.d/97-docker-broadcast.conf

echo "This process needs 'sudo' permissions. Please enter your password."
if ! sudo true; then
    sudo -k # make sure to ask for password on next sudo
    if ! sudo true; then exit 1; fi
fi

# Install requirements
sudo apt -qq install -y jq  # command-line JSON parser

# Find the subnet for the docker network
SUBNET=$(docker network inspect "${DOCKER_NETWORK}" | jq --raw-output .[0].IPAM.Config[0].Subnet)
if [ -z ${SUBNET} ]; then echo "Could not determine the subnet for $DOCKER_NETWORK"; exit 1; fi
echo "Got subnet for ${DOCKER_NETWORK}: ${SUBNET}"

# Find the subnet for the docker network
GATEWAY=$(docker network inspect "${DOCKER_NETWORK}" | jq --raw-output .[0].IPAM.Config[0].Gateway)
if [ -z ${GATEWAY} ]; then echo "Could not determine the gateway for $DOCKER_NETWORK"; exit 1; fi
echo "Got gateway for ${DOCKER_NETWORK}: ${GATEWAY}"

# Find the network interface
INTERFACE=$(ip route | grep "${SUBNET}" | cut -d ' ' -f3)
if [ -z ${INTERFACE} ]; then echo "Could not determine the network interface for ${SUBNET}"; exit 1; fi
echo "Got interface for ${DOCKER_NETWORK}: ${INTERFACE}"


SETTINGS=(
    "net.ipv4.icmp_echo_ignore_broadcasts=0"  # Disable the setting to ignore echo broadcasts
    "net.ipv4.conf.all.bc_forwarding=1"  # Enabling broadcast forwarding for "all" interfaces, 
    "net.ipv4.conf.${INTERFACE}.bc_forwarding=1"  # Check the setting value to check we are substituting correctly
)

# Set system contol values
for SETTING in ${SETTINGS[@]}; do
    sudo sysctl -w ${SETTING}
done

# Write to persist setup
printf "%s\n" "${SETTINGS[@]}" | sudo tee ${PATH_CONFIG}

cat ${PATH_CONFIG}

