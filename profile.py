"""
Repo-based profile for the low-latency shuffle project.
"""

import geni.portal as portal
import geni.rspec.pg as RSpec
import geni.urn as urn
import geni.aggregate.cloudlab as cloudlab

pc = portal.Context()

images = [ ("UBUNTU20-64-STD", "Ubuntu 20.04") ]

types = [ ("m510", "m510 (Intel Xeon-D 1548 8 cores@2.0Ghz, Mellanox CX3 10GbE)"),
          ("xl170", "xl170 (Intel Xeon E5-2640v4 10 cores@2.4Ghz, Mellanox CX4 25GbE)"),
          ("d6515", "d6515 (AMD EPYC Rome 32 cores@2.35Ghz, Mellanox CX5 100Gbps)"),
          ("c6220", "c6220 (2 x Intel Xeon E5-2650v2 8 cores@2.6Ghz, Mellanox CX3 56Gbps)"),
          ("r320", "r320 (Intel Xeon E5-2450 8 cores@2.1Ghz, Mellanox CX3 56Gbps)")]

num_nodes = range(1, 200)

pc.defineParameter("image", "Disk Image",
                   portal.ParameterType.IMAGE, images[0], images)

pc.defineParameter("type", "Node Type",
                   portal.ParameterType.NODETYPE, types[0], types)

pc.defineParameter("num_nodes", "# Nodes",
                   portal.ParameterType.INTEGER, 1, num_nodes)

params = pc.bindParameters()

rspec = RSpec.Request()

lan = RSpec.LAN()
rspec.addResource(lan)

node_names = ["rcnfs"]
for i in range(1, params.num_nodes):
    node_names.append("rc%02d" % i)

for name in node_names:
    node = RSpec.RawPC(name)

    if name == "rcnfs":
        # Ask for a 200GB file system mounted at /shome on rcnfs
        bs = node.Blockstore("bs", "/shome")
        bs.size = "200GB"

    node.hardware_type = params.type
    node.disk_image = 'urn:publicid:IDN+emulab.net+image+emulab-ops:' + params.image

    cmd_string = "sudo /local/repository/startup.sh"
    node.addService(RSpec.Execute(shell="sh", command=cmd_string))

    rspec.addResource(node)

    iface = node.addInterface("eth0")
    lan.addInterface(iface)

pc.printRequestRSpec(rspec)

