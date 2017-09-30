#!/bin/bash -x
source ./envs.sh

# cat << EOF

echo "Applying terraform configs"
terraform plan
terraform apply

VPCID=`./scripts/get_ids.py vpc`
PRIMARY_VPC="vpc-xxxxxxxx"

echo "Creating cluster via kops"
kops create cluster \
--name ${KOPS_CLUSTER_NAME} \
--dns private \
--state=${KOPS_STATE_STORE} \
--vpc ${VPCID} \
--master-zones us-east-1b,us-east-1c,us-east-1d \
--zones us-east-1b,us-east-1c,us-east-1d \
--node-count=3 \
--node-size m4.large \
--topology=private \
--networking kube-router \
--yes
#
echo "Associating the new zone with our VPN VPC"
aws route53 associate-vpc-with-hosted-zone --hosted-zone-id `./scripts/get_ids.py zone` --vpc VPCRegion=us-east-1,VPCId=${PRIMARY_VPC}

echo "Create the peering connection"
aws ec2 create-vpc-peering-connection --peer-vpc-id ${PRIMARY_VPC} --vpc-id ${VPCID}

echo "sleeping 60 seconds, waiting for stand up of the connection"
sleep 60

# EOF

echo "Accepting the peering connection"
PEER_ID=`./scripts/get_ids.py peering_connection ${VPCID}`
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id ${PEER_ID}

echo "Sleeping 10 to let vpc peering settle"
sleep 10

echo "populate routes to PRIMARY VPC from new VPC"
for i in `./scripts/get_ids.py routes ${VPCID}`
do
  aws ec2 create-route --route-table-id $i --destination-cidr-block 172.31.0.0/16 --vpc-peering-connection-id ${PEER_ID}
done

echo "populate routes to new VPC from Primary VPC"
NEW_CIDR=`./scripts/get_ids.py cidr`
for i in `./scripts/get_ids.py routes ${PRIMARY_VPC}`
do
  aws ec2 create-route --route-table-id $i --destination-cidr-block ${NEW_CIDR} --vpc-peering-connection-id ${PEER_ID}
done
