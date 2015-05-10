#!/bin/bash -x

# Check if creds for proviant host are available

if [ -z "$DC_ID" ]; then
echo "Datacenter is not defined!"
exit 1
fi
if [ -z "$proviant_ip" ]; then
echo "Proviant IP is not defined!"
exit 1
fi
if [ -z "$proviant_port" ]; then
echo "Proviant SSH port is not defined!"
exit 1
fi
if [ -z "$proviant_user" ]; then
echo "Proviant user is not defined!"
exit 1
fi

# Remove old logs
rm -rf logs
mkdir -p logs

ssh ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc ${DC_ID}

# Obtain access to FM
# to add - verify SSH connection to proviant
FUEL_IP=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc $DC_ID | grep 'Master: hostname:' | awk '{print $7}' | awk -F"://" '{print $2}'`
fuel_master_user=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc $DC_ID | sed -e '1,/fuel-master-ssh-credentials/d' | head -1 | awk {'print $1'}`
fuel_master_pass=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc $DC_ID | sed -e '1,/fuel-master-ssh-credentials/d' | head -1 | awk {'print $2'} | awk -F"'" '{print $2}'`

# SSH to FM
fm_ssh="sshpass -p$fuel_master_pass ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -oPubkeyAuthentication=no $fuel_master_user@$FUEL_IP"

#$fm_ssh "uname -a"

#Get CTRL IP
ctrl_ip=`$fm_ssh "fuel nodes" | grep controller | awk '{print $9}' | head -1`
echo $ctrl_ip

# Create rsa key pair for Rally VM
rm -f rally_rsa_key*
ssh-keygen -f rally_rsa_key -t rsa -N ''
ls rally_rsa_key*

#Upload script to CTRL and create Rally_VM instance
# Copy script and public key to FM
sshpass -p$fuel_master_pass scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -oPubkeyAuthentication=no scripts/create_rally_vm.sh $fuel_master_user@$FUEL_IP:/root/create_rally_vm.sh
sshpass -p$fuel_master_pass scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -oPubkeyAuthentication=no rally_rsa_key.pub $fuel_master_user@$FUEL_IP:/root/rally_rsa_key.pub
# Copy script and public key to CTRL
$fm_ssh "scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null /root/create_rally_vm.sh $ctrl_ip:/root/create_rally_vm.sh"
$fm_ssh "scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null /root/rally_rsa_key.pub $ctrl_ip:/root/rally_rsa_key.pub"
# Remove script and public key from FM
$fm_ssh "rm -f /root/create_rally_vm.sh"
$fm_ssh "rm -f /root/rally_rsa_key.pub"
# Run script on CTRL

# Obtain Rally_VM floating ip

# Save logs
echo 'OK' > logs/rally.log
