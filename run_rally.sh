#!/bin/bash -x

# Check if creds for proviant host are available

#source creds

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

#Get CTRL IP
ctrl_ip=`$fm_ssh "fuel nodes" | grep controller | awk '{print $9}' | head -1`
echo $ctrl_ip

# Create rsa key pair for Rally VM
rm -f rally_rsa_key*
ssh-keygen -f rally_rsa_key -t rsa -N ''
ls rally_rsa_key*

#Upload script to CTRL and create Rally_VM instance
# Copy script and public key to FM
sshpass -p$fuel_master_pass scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -oPubkeyAuthentication=no scripts/manage_rally_vm.sh $fuel_master_user@$FUEL_IP:/root/manage_rally_vm.sh
sshpass -p$fuel_master_pass scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -oPubkeyAuthentication=no rally_rsa_key.pub $fuel_master_user@$FUEL_IP:/root/rally_rsa_key.pub
# Copy script and public key to CTRL
$fm_ssh "scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null /root/manage_rally_vm.sh $ctrl_ip:/root/manage_rally_vm.sh"
$fm_ssh "scp -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null /root/rally_rsa_key.pub $ctrl_ip:/root/rally_rsa_key.pub"
# Remove script and public key from FM
$fm_ssh "rm -f /root/manage_rally_vm.sh"
$fm_ssh "rm -f /root/rally_rsa_key.pub"
# Run script on CTRL
$fm_ssh "ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $ctrl_ip /root/manage_rally_vm.sh boot"

# Upload Test_Image_1
$fm_ssh "ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $ctrl_ip /root/manage_rally_vm.sh upload"

#Create fake floating subnet
$fm_ssh "ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $ctrl_ip /root/manage_rally_vm.sh floating"

# Obtain Rally_VM floating ip
vm_ip=`$fm_ssh "ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $ctrl_ip /root/manage_rally_vm.sh getip"`
echo "Floating -  $vm_ip"

# Check SSH connectivity
count=10
while [[ $count -ne 0 ]] ; do
    echo "=== Waiting for SSH connectivity.. left $count attempts"
    vm_name=`ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} uname -n`
    if [ "$vm_name" = "rally-vm" ]; then
	echo "=== SSH is UP."
	break
    fi
    count=$((count-1))
    sleep 30
done

if [ -z $vm_name ]; then
    echo "=== SSH at Rally_VM is DOWN"
    exit 1
fi
###

# SSH to Rally_VM
#ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} uname -a
scp -r -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null samples/ ubuntu@${vm_ip}:~/

# Prepare 'existing.json'
horizon_ip=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc $DC_ID | grep horizonURL | awk '{print $2}' | awk -F"/" '{print $3}'`
admin_pass=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${proviant_user}@${proviant_ip} -p ${proviant_port} proviant-dc-details --dc $DC_ID | grep "u'password'" | awk '{print $4}' | awk -F"'" '{print $2}'`

cp -f samples/deployments/existing.json samples/deployments/tmp_existing.json

sed -i s/CONTROLLER_IP/${horizon_ip}/g samples/deployments/tmp_existing.json
sed -i s/ADMIN_PASSWORD/${admin_pass}/g samples/deployments/tmp_existing.json

scp -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null samples/deployments/tmp_existing.json ubuntu@${vm_ip}:/home/ubuntu/samples/deployments/existing.json
rm -f samples/deployments/tmp_existing.json
##

# Install Rally and create deployment
scp -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null scripts/get_rally.sh ubuntu@${vm_ip}:get_rally.sh
#
# Tempotrary commented next lines
ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} ./get_rally.sh

scp -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null scripts/create_rally_deploymet.sh ubuntu@${vm_ip}:create_rally_deploymet.sh
ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} ./create_rally_deploymet.sh

# Upload plugins
ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} mkdir -p .rally/plugins
scp -r -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null plugins/* ubuntu@${vm_ip}:~/.rally/plugins/

# Run Rally task(s) and analyze test results
scp -r -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null scripts/run_rally_tasks.sh ubuntu@${vm_ip}:run_rally_tasks.sh
ssh -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip} ./run_rally_tasks.sh

# Download test reports
scp -r -i rally_rsa_key -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ubuntu@${vm_ip}:logs/* logs/

# Clear env
$fm_ssh "ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $ctrl_ip /root/manage_rally_vm.sh clear"

# Check logs

#if [ -f logs/failure.log ]; then
#    echo "=== MOS is unstable. Refer to logs."
#    exit 1
#fi
