#!/bin/bash

# Cleanup script for devlab compartment
# This script lists all resources in the compartment that need to be deleted

COMPARTMENT_ID="ocid1.compartment.oc1..aaaaaaaae5v3sal4r6df2hrucviwerue5k3trdiln5buhh7wggjjgw2f7wua"
REGION="us-ashburn-1"  # Change this to your region if different

echo "================================================"
echo "Checking resources in devlab compartment"
echo "Compartment ID: $COMPARTMENT_ID"
echo "================================================"
echo ""

echo "1. COMPUTE INSTANCES:"
echo "--------------------"
oci compute instance list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Instance: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No instances found or error"
echo ""

echo "2. BLOCK VOLUMES:"
echo "-----------------"
oci bv volume list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Volume: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No volumes found or error"
echo ""

echo "3. BOOT VOLUMES:"
echo "----------------"
oci bv boot-volume list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Boot Volume: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No boot volumes found or error"
echo ""

echo "4. VCNs (Virtual Cloud Networks):"
echo "---------------------------------"
oci network vcn list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "VCN: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No VCNs found or error"
echo ""

echo "5. SUBNETS:"
echo "-----------"
oci network subnet list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Subnet: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No subnets found or error"
echo ""

echo "6. INTERNET GATEWAYS:"
echo "--------------------"
oci network internet-gateway list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "IGW: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No IGWs found or error"
echo ""

echo "7. ROUTE TABLES:"
echo "----------------"
oci network route-table list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Route Table: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No route tables found or error"
echo ""

echo "8. SECURITY LISTS:"
echo "------------------"
oci network security-list list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "Security List: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No security lists found or error"
echo ""

echo "9. LOAD BALANCERS:"
echo "------------------"
oci lb load-balancer list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "LB: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No load balancers found or error"
echo ""

echo "10. DATABASE SYSTEMS:"
echo "--------------------"
oci db system list --compartment-id $COMPARTMENT_ID --region $REGION --all 2>/dev/null | jq -r '.data[] | "DB: \(.["display-name"]) - ID: \(.id) - State: \(.["lifecycle-state"])"' || echo "No databases found or error"
echo ""

echo "================================================"
echo "DELETION ORDER:"
echo "================================================"
echo "To delete the compartment, remove resources in this order:"
echo "1. Terminate all Compute Instances"
echo "2. Delete all Block Volumes (after instances are terminated)"
echo "3. Delete all Boot Volumes (may auto-delete with instances)"
echo "4. Delete Subnets"
echo "5. Delete Internet Gateways"
echo "6. Delete Route Tables (except default)"
echo "7. Delete Security Lists (except default)"
echo "8. Delete VCNs"
echo "9. Delete the compartment itself"
echo ""
echo "NOTE: Some resources may have termination protection or dependencies."
echo "================================================"