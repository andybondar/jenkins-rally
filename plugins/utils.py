# Copyright 2013: Mirantis Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import subprocess
import sys

import netaddr

from rally.benchmark.scenarios import base
from rally.benchmark import utils as bench_utils
from rally.benchmark.wrappers import network as network_wrapper
from rally.common import log as logging
from rally.common import sshutils

LOG = logging.getLogger(__name__)


class VMScenario(base.Scenario):
    """Base class for VM scenarios with basic atomic actions.

    VM scenarios are scenarios executed inside some launched VM instance.
    """

    @base.atomic_action_timer("vm.run_command")
    def _run_action(self, ssh, interpreter, script, script_args):
        """Run command inside an instance.

        This is a separate function so that only script execution is timed.

        :returns: tuple (exit_status, stdout, stderr)
        """
        return ssh.execute(interpreter, stdin=open(script, "rb"))

    def _get_netwrap(self):
        if not hasattr(self, "_netwrap"):
            self._netwrap = network_wrapper.wrap(self.clients)
        return self._netwrap

    def _boot_server_with_fip(self, image, flavor, floating_network=None,
                              wait_for_ping=False, **kwargs):
        kwargs["auto_assign_nic"] = True
        server = self._boot_server(image, flavor, **kwargs)

        if not server.networks:
            raise RuntimeError(
                "Server `%(server)s' is not connected to any network. "
                "Use network context for auto-assigning networks "
                "or provide `nics' argument with specific net-id." % {
                    "server": server.name})

        fip = self._attach_floating_ip(server, floating_network)

        return server, fip

    @base.atomic_action_timer("vm.attach_floating_ip")
    def _attach_floating_ip(self, server, floating_network):
        internal_network = list(server.networks)[0]
        fixed_ip = server.addresses[internal_network][0]["addr"]

        fip = self._get_netwrap().create_floating_ip(
            ext_network=floating_network, int_network=internal_network,
            tenant_id=server.tenant_id, fixed_ip=fixed_ip)

        self._associate_floating_ip(server, fip["ip"], fixed_address=fixed_ip)

        return fip

    @base.atomic_action_timer("vm.wait_for_ssh")
    def _wait_for_ssh(self, ssh):
        ssh.wait()

    def _run_command(self, server_ip, port, username, password,
                     interpreter, script):
        """Run command via SSH on server.

        Create SSH connection for server, wait for server to become
        available (there is a delay between server being set to ACTIVE
        and sshd being available). Then call run_action to actually
        execute the command.
        """
        ssh = sshutils.SSH(username, server_ip, port=port,
                           pkey=self.context["user"]["keypair"]["private"],
                           password=password)

        self._wait_for_ssh(ssh)
        return self._run_action(ssh, interpreter, script)
