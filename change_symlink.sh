#!/bin/bash -x


if [ "$change_symlink" = "true" ] && [ ! -z "$snapshot_build_number" ] ; then
    echo "=== Change symlink"
    #snapshot=`ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null root@${STORAGE_IP} -p ${STORAGE_PORT} ls -l /store/fuel_ref/rc | awk '{print $11}'`
    snapshot=$snapshot_build_number
    echo "=== Change symlink"
    ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null root@${STORAGE_IP} -p ${STORAGE_PORT} "rm -f /store/fuel_ref/stable"
    ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null root@${STORAGE_IP} -p ${STORAGE_PORT} "ln -s $snapshot /store/fuel_ref/stable"
    ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null root@${STORAGE_IP} -p ${STORAGE_PORT} "ls -lh /store/fuel_ref/stable"
else
    echo "=== Changing symlink skipped"
fi
