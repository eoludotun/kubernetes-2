#!/bin/bash -x
source ./envs.sh

VPCID=`./scripts/get_ids.py vpc`
PRIMARY_VPC="vpc-xxxxxxxx"
PEER_ID=`./scripts/get_ids.py peering_connection ${VPCID}`

echo "Deleting routes to new VPC from Primary VPC"
NEW_CIDR=`./scripts/get_ids.py cidr`
for i in `./scripts/get_ids.py routes ${PRIMARY_VPC}`
do
  aws ec2 delete-route --route-table-id $i --destination-cidr-block ${NEW_CIDR}
done

echo "Deleting routes to PRIMARY VPC from new VPC"
for i in `./scripts/get_ids.py routes ${VPCID}`
do
  aws ec2 delete-route --route-table-id $i --destination-cidr-block 172.31.0.0/16
done

echo "Deleting the peering connection"
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id ${PEER_ID}

echo "Disassociating the new zone with our VPN VPC"
aws route53 disassociate-vpc-from-hosted-zone --hosted-zone-id `./scripts/get_ids.py zone` --vpc VPCRegion=us-east-1,VPCId=${PRIMARY_VPC}

echo "Deleting cluster via kops"
kops delete cluster \
--name ${KOPS_CLUSTER_NAME} \
--state=${KOPS_STATE_STORE} \
--yes

echo "Deleting VPC via terraform configs"
terraform destroy
