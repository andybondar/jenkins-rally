#!/bin/bash -x
#source openrc
cd ~
sudo rally-manage db recreate
sudo rally deployment create --filename=samples/deployments/existing.json --name=Env
rally deployment check
sudo chown -R ubuntu:ubuntu .rally/
