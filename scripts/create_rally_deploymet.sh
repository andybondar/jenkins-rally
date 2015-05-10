#!/bin/bash -x
source openrc
rally-manage db recreate
rally deployment create --fromenv --name=Env
