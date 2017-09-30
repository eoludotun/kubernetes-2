#!/Users/dland/virtualenv/boto/bin/python
import hcl
import boto3
import json
import os.path
import sys
import re

if len(sys.argv) < 2:
    sys.exit("USAGE: %s [zone,vpc]" % sys.argv[0])
else:
    qtype = sys.argv[1]

# we read in default.tf to get the same name (${nametag}.local) terraform is using
fname = 'default.tf'
if os.path.isfile(fname):
    with open(fname, 'r') as fp:
        obj = hcl.load(fp)
else:
    sys.exit("ERROR: expecting a file named %s to extract zone name from!" % fname)

try:
    zonename = (obj['variable']['nametag']['default'])
except:
    print "ERROR: unable to determine zonename!"

def print_vpc_cidr():
    try:
        return(obj['variable']['vpc_cidr']['default'])
    except:
        sys.exit("ERROR: unable to read cidr from default.tf!")


def get_vpc_id(zonename):
    ec2 = boto3.resource('ec2')
    client = boto3.client('ec2')
    filters = [{'Name':'tag:Name', 'Values':[zonename]}]
    vpcs = list(ec2.vpcs.filter(Filters=filters))
    if len(vpcs) != 1:
        sys.exit("ERROR: found %d vpcs matching the tag %s, should be 1!" % (len(vpcs), zonename))

    for vpc in vpcs:
        return vpc.id


def get_zone_id(zone):
    zonename = "%s.local" % zone
    client = boto3.client('route53')
    x = client.list_hosted_zones()
    results = []
    for i in x['HostedZones']:
        r = re.compile(r'^%s(\.?)$' % re.escape(zonename))
        search = re.match(r, i['Name'], flags=0)
        if search:
            results.append(i['Id'].split("/")[-1])
    if len(results) == 1:
        return results[0]
    else:
        sys.exit("ERROR: matched %d zones, expected 1!" % len(results))

def get_peering_connection(vpcid):
    ec2 = boto3.resource("ec2")
    x = False
    try:
        for i in ec2.vpc_peering_connections.all():
            if i.requester_vpc.id == vpcid:
                if i.status["Message"].split()[0] != "Deleted":
                    x = i.vpc_peering_connection_id
    except:
        sys.exit("ERROR: unable to query peering connection accociated with vpcID %s!" % (vpcid))
    if x:
        return x
    else:
        sys.exit("ERROR: unable to find peering connection accociated with vpcID %s!" % (vpcid))

def get_route_tables(vpcid):
    ec2 = boto3.resource("ec2")
    result = ''
    for i in ec2.route_tables.all():
        if i.vpc_id == vpcid:
            result += "%s\n" % (i.id)
    return result

def not_enough_args(args):
    if args != 3:
        sys.exit("ERROR: not enough arguments, require VPC ID")

if qtype == "vpc":
    print get_vpc_id(zonename)
elif qtype == "zone":
    print get_zone_id(zonename)
elif qtype == "peering_connection":
    not_enough_args(len(sys.argv))
    print get_peering_connection(sys.argv[2])
elif qtype == "routes":
    not_enough_args(len(sys.argv))
    print get_route_tables(sys.argv[2]).rstrip()
elif qtype == "cidr":
    print print_vpc_cidr()
else:
    sys.exit("ERROR: undefined lookup!")
