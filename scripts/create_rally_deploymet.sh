#!/bin/bash -x
source openrc
#rally-manage db recreate
rally deployment create --filename=samples/deployments/existing.json --name=Env
rally deployment check
