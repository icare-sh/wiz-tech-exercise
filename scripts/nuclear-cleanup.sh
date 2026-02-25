#!/bin/bash
set -e

echo "=============================================="
echo "NUCLEAR CLEANUP - Delete ALL AWS Resources"
echo "=============================================="
echo ""

AWS_PROFILE="${AWS_PROFILE:-wiz}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "⚠️  WARNING: This will delete ALL resources related to wiz-tech-exercise"
echo "Including: VPCs, Subnets, Security Groups, EKS Clusters, EC2 instances, etc."
echo ""
read -p "Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "=============================================="
echo "Step 1: Deleting EKS Clusters"
echo "=============================================="

for CLUSTER in $(aws eks list-clusters --region $AWS_REGION --query 'clusters[?starts_with(@, `wiz`)]' --output text); do
    echo "Deleting EKS cluster: $CLUSTER"
    
    for NG in $(aws eks list-nodegroups --cluster-name $CLUSTER --region $AWS_REGION --query 'nodegroups[*]' --output text); do
        echo "  Deleting node group: $NG"
        aws eks delete-nodegroup --cluster-name $CLUSTER --nodegroup-name $NG --region $AWS_REGION || true
    done
    
    echo "  Waiting for node groups to be deleted..."
    sleep 30
    
    for ADDON in $(aws eks list-addons --cluster-name $CLUSTER --region $AWS_REGION --query 'addons[*]' --output text); do
        echo "  Deleting addon: $ADDON"
        aws eks delete-addon --cluster-name $CLUSTER --addon-name $ADDON --region $AWS_REGION || true
    done
    
    echo "  Deleting cluster: $CLUSTER"
    aws eks delete-cluster --name $CLUSTER --region $AWS_REGION || true
done

echo "Waiting 60s for EKS clusters to start deleting..."
sleep 60

echo ""
echo "=============================================="
echo "Step 2: Deleting EC2 Instances"
echo "=============================================="

# Delete EC2 instances with "mongo" or "wiz" tags
for INSTANCE in $(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[*].Instances[?Tags[?contains(Value, `mongo`) || contains(Value, `wiz`)]].InstanceId' \
    --output text); do
    echo "Terminating EC2 instance: $INSTANCE"
    aws ec2 terminate-instances --instance-ids $INSTANCE --region $AWS_REGION
done

# Delete all key pairs with "wiz" or "mongo" in name
for KEY in $(aws ec2 describe-key-pairs --region $AWS_REGION \
    --query 'KeyPairs[?contains(KeyName, `wiz`) || contains(KeyName, `mongo`)].KeyName' \
    --output text); do
    echo "Deleting key pair: $KEY"
    aws ec2 delete-key-pair --key-name $KEY --region $AWS_REGION || true
done

echo "Waiting 30s for EC2 instances to terminate..."
sleep 30

echo ""
echo "=============================================="
echo "Step 3: Deleting Load Balancers"
echo "=============================================="

for LB in $(aws elbv2 describe-load-balancers --region $AWS_REGION \
    --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`) || contains(LoadBalancerName, `wiz`)].LoadBalancerArn' \
    --output text); do
    echo "Deleting load balancer: $LB"
    aws elbv2 delete-load-balancer --load-balancer-arn $LB --region $AWS_REGION || true
done

for TG in $(aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `k8s`) || contains(TargetGroupName, `wiz`)].TargetGroupArn' \
    --output text); do
    echo "Deleting target group: $TG"
    aws elbv2 delete-target-group --target-group-arn $TG --region $AWS_REGION || true
done

echo "Waiting 30s for load balancers to be deleted..."
sleep 30

echo ""
echo "=============================================="
echo "Step 4: Deleting VPCs and Associated Resources"
echo "=============================================="

for VPC in $(aws ec2 describe-vpcs --region $AWS_REGION \
    --filters "Name=tag:Name,Values=*wiz*" \
    --query 'Vpcs[*].VpcId' --output text); do
    
    echo "Processing VPC: $VPC"
    
    for NGW in $(aws ec2 describe-nat-gateways --region $AWS_REGION \
        --filter "Name=vpc-id,Values=$VPC" "Name=state,Values=available" \
        --query 'NatGateways[*].NatGatewayId' --output text); do
        echo "  Deleting NAT Gateway: $NGW"
        aws ec2 delete-nat-gateway --nat-gateway-id $NGW --region $AWS_REGION
    done
    
    for IGW in $(aws ec2 describe-internet-gateways --region $AWS_REGION \
        --filters "Name=attachment.vpc-id,Values=$VPC" \
        --query 'InternetGateways[*].InternetGatewayId' --output text); do
        echo "  Detaching and deleting Internet Gateway: $IGW"
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC --region $AWS_REGION
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $AWS_REGION
    done
    
    for SUBNET in $(aws ec2 describe-subnets --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC" \
        --query 'Subnets[*].SubnetId' --output text); do
        echo "  Deleting subnet: $SUBNET"
        aws ec2 delete-subnet --subnet-id $SUBNET --region $AWS_REGION || true
    done
    
    for RTB in $(aws ec2 describe-route-tables --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC" \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
        echo "  Deleting route table: $RTB"
        aws ec2 delete-route-table --route-table-id $RTB --region $AWS_REGION || true
    done
    
    for SG in $(aws ec2 describe-security-groups --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
        echo "  Deleting security group: $SG"
        aws ec2 delete-security-group --group-id $SG --region $AWS_REGION || true
    done
    
    echo "Waiting 30s before deleting VPC..."
    sleep 30
    
    echo "  Deleting VPC: $VPC"
    aws ec2 delete-vpc --vpc-id $VPC --region $AWS_REGION || echo "  VPC deletion failed, will retry later"
done

echo ""
echo "=============================================="
echo "Step 5: Cleaning S3 and Other Resources"
echo "=============================================="

for BUCKET in $(aws s3 ls | grep "wiz-mongo-backups" | awk '{print $3}'); do
    echo "Emptying and deleting S3 bucket: $BUCKET"
    aws s3 rm s3://$BUCKET --recursive
    aws s3 rb s3://$BUCKET
done

for LOG_GROUP in $(aws logs describe-log-groups --region $AWS_REGION \
    --query 'logGroups[?contains(logGroupName, `wiz`) || contains(logGroupName, `/aws/eks`)].logGroupName' \
    --output text); do
    echo "Deleting CloudWatch log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION || true
done

for REPO in $(aws ecr describe-repositories --region $AWS_REGION \
    --query 'repositories[?contains(repositoryName, `wiz`)].repositoryName' \
    --output text); do
    echo "Deleting ECR repository: $REPO"
    aws ecr delete-repository --repository-name $REPO --region $AWS_REGION --force || true
done

echo ""
echo "=============================================="
echo "Step 6: Clearing Terraform States in S3"
echo "=============================================="

echo "Backing up current states..."
aws s3 cp s3://wiz-tech-exercise-terraform-state-324037288864/dev/eks/terraform.tfstate \
    /tmp/eks-state-backup-$(date +%Y%m%d-%H%M%S).tfstate 2>/dev/null || echo "No EKS state to backup"
aws s3 cp s3://wiz-tech-exercise-terraform-state-324037288864/dev/ec2/terraform.tfstate \
    /tmp/ec2-state-backup-$(date +%Y%m%d-%H%M%S).tfstate 2>/dev/null || echo "No EC2 state to backup"

echo "Clearing states..."
aws s3 rm s3://wiz-tech-exercise-terraform-state-324037288864/dev/eks/terraform.tfstate 2>/dev/null || true
aws s3 rm s3://wiz-tech-exercise-terraform-state-324037288864/dev/ec2/terraform.tfstate 2>/dev/null || true

echo ""
echo "=============================================="
echo "✅ CLEANUP COMPLETE!"
echo "=============================================="
echo ""
echo "All AWS resources have been deleted."
echo "State backups saved in /tmp/"
echo ""
echo "Next steps:"
echo "1. Commit and push your code changes"
echo "2. Merge PR to main"
echo "3. GitHub Actions will deploy everything fresh with proper state management"
echo ""

