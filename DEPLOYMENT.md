# Deployment Guide - Gym Advisor Frontend

This guide walks you through deploying the Gym Advisor Frontend to AWS ECS Fargate using Terraform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deploying with Terraform](#deploying-with-terraform)
4. [Building and Pushing Docker Image](#building-and-pushing-docker-image)
5. [Automated Deployment](#automated-deployment)
6. [Updating the Application](#updating-the-application)
7. [Monitoring and Debugging](#monitoring-and-debugging)
8. [CI/CD Integration](#cicd-integration)

## Prerequisites

### Required Tools

- **Docker** (version 20.x or later)
- **AWS CLI** (version 2.x)
- **Terraform** (version 1.0 or later)
- **Node.js** (version 20.x for local development)

### AWS Resources

Before deployment, ensure you have:

- AWS account with appropriate permissions
- Existing ECS Fargate cluster
- Application Load Balancer (ALB) with HTTPS listener
- VPC with public and private subnets
- NAT Gateway configured for private subnets
- ACM certificate for SSL/TLS
- Route53 hosted zone (optional, for DNS)

### AWS CLI Configuration

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

## Initial Setup

### 1. Clone and Prepare

```bash
cd gym_advisor_frontend
```

### 2. Gather AWS Information

Run these commands to collect necessary information:

```bash
# Set your region
export AWS_REGION=eu-west-2

# List ECS clusters
aws ecs list-clusters --region $AWS_REGION

# List ALBs
aws elbv2 describe-load-balancers --region $AWS_REGION

# Get ALB listeners
aws elbv2 describe-listeners \
  --load-balancer-arn <your-alb-arn> \
  --region $AWS_REGION

# List VPCs
aws ec2 describe-vpcs --region $AWS_REGION

# List subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<your-vpc-id>" \
  --region $AWS_REGION

# List ACM certificates
aws acm list-certificates --region $AWS_REGION

# Get ALB security group
aws elbv2 describe-load-balancers \
  --load-balancer-arns <your-alb-arn> \
  --query 'LoadBalancers[0].SecurityGroups' \
  --region $AWS_REGION
```

### 3. Create Environment File

```bash
# Create environment file from example
cp .env.example .env.production

# Edit with your values
nano .env.production
```

Add your configuration:

```bash
NEXT_PUBLIC_API_URL=https://api.gymadvisor.com
NEXT_PUBLIC_API_KEY=your-api-key-here
```

## Deploying with Terraform

### 1. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in all required values:

```hcl
# AWS Configuration
aws_region  = "eu-west-2"
environment = "production"

# VPC and Networking
vpc_id              = "vpc-xxx"
private_subnet_ids  = ["subnet-xxx", "subnet-yyy"]
public_subnet_ids   = ["subnet-zzz", "subnet-aaa"]

# ECS Configuration
ecs_cluster_name = "your-cluster-name"

# ALB Configuration
alb_arn                = "arn:aws:elasticloadbalancing:..."
alb_listener_arn       = "arn:aws:elasticloadbalancing:..."
alb_security_group_id  = "sg-xxx"
certificate_arn        = "arn:aws:acm:..."
host_header            = "frontend.gymadvisor.com"

# Application Configuration
next_public_api_url = "https://api.gymadvisor.com"
next_public_api_key = "your-api-key"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Infrastructure

```bash
terraform plan
```

Review the resources that will be created:
- ECR repository
- ECS task definition and service
- IAM roles and policies
- Security groups
- ALB target group and listener rule
- CloudWatch log group
- Auto-scaling configuration

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm and create the infrastructure.

### 5. Save Outputs

```bash
terraform output > ../terraform-outputs.txt
```

This saves important information like ECR URL and deployment commands.

## Building and Pushing Docker Image

### Option 1: Manual Deployment

```bash
# Go back to project root
cd ..

# Get ECR repository URL from Terraform output
ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
AWS_REGION=$(cd terraform && terraform output -raw aws_region)

# Authenticate with ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URL

# Build the image
docker build \
  --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_API_URL="https://api.gymadvisor.com" \
  --build-arg NEXT_PUBLIC_API_KEY="your-api-key" \
  -t $ECR_URL:latest \
  .

# Push to ECR
docker push $ECR_URL:latest

# Force new deployment
ECS_CLUSTER=$(cd terraform && terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(cd terraform && terraform output -raw ecs_service_name)

aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  --region $AWS_REGION
```

### Option 2: Using Deployment Script

```bash
# Make sure environment variables are set
export NEXT_PUBLIC_API_URL="https://api.gymadvisor.com"
export NEXT_PUBLIC_API_KEY="your-api-key"
export AWS_REGION="eu-west-2"

# Run deployment script
./deploy.sh production latest
```

The script will:
1. Validate dependencies
2. Load environment variables
3. Get ECR and ECS information
4. Build Docker image
5. Push to ECR
6. Update ECS service
7. Wait for deployment to complete

## Updating the Application

### For Code Changes

```bash
# 1. Make your code changes
# 2. Commit to git (optional)

# 3. Run deployment script
./deploy.sh production v1.0.1

# Or manually:
docker build --platform linux/amd64 -t $ECR_URL:v1.0.1 .
docker push $ECR_URL:v1.0.1
docker tag $ECR_URL:v1.0.1 $ECR_URL:latest
docker push $ECR_URL:latest

aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  --region $AWS_REGION
```

### For Infrastructure Changes

```bash
cd terraform

# 1. Modify Terraform files
# 2. Plan changes
terraform plan

# 3. Apply changes
terraform apply
```

### For Environment Variable Changes

```bash
cd terraform

# 1. Update variables in terraform.tfvars
nano terraform.tfvars

# 2. Apply changes (will recreate task definition)
terraform apply

# 3. Force new deployment
aws ecs update-service \
  --cluster <cluster-name> \
  --service gym-advisor-frontend \
  --force-new-deployment \
  --region eu-west-2
```

## Monitoring and Debugging

### View Logs

```bash
# Real-time logs
aws logs tail /ecs/gym-advisor-frontend --follow --region eu-west-2

# Logs from specific time
aws logs tail /ecs/gym-advisor-frontend \
  --since 1h \
  --format short \
  --region eu-west-2

# Filter logs
aws logs tail /ecs/gym-advisor-frontend \
  --follow \
  --filter-pattern "ERROR" \
  --region eu-west-2
```

### Check Service Status

```bash
# Service status
aws ecs describe-services \
  --cluster <cluster-name> \
  --services gym-advisor-frontend \
  --region eu-west-2

# List tasks
aws ecs list-tasks \
  --cluster <cluster-name> \
  --service-name gym-advisor-frontend \
  --region eu-west-2

# Task details
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --region eu-west-2
```

### Check Target Health

```bash
# Get target group ARN
TG_ARN=$(cd terraform && terraform output -raw target_group_arn)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region eu-west-2
```

### Common Issues

#### Tasks Not Starting

**Problem**: Tasks start then stop immediately

**Solution**:
1. Check logs: `aws logs tail /ecs/gym-advisor-frontend --follow`
2. Verify environment variables in task definition
3. Check if image exists in ECR
4. Verify IAM roles have correct permissions

#### Health Checks Failing

**Problem**: Tasks fail ALB health checks

**Solution**:
1. Verify app is listening on port 3000
2. Check health check path returns 200
3. Ensure security groups allow ALB → ECS traffic
4. Check container logs for startup errors

#### Cannot Access Application

**Problem**: Can't reach application via domain

**Solution**:
1. Verify DNS record points to ALB
2. Check ALB listener rules and priorities
3. Verify ACM certificate covers domain
4. Check target group health
5. Ensure host header matches in listener rule

#### Image Pull Errors

**Problem**: ECS can't pull image from ECR

**Solution**:
1. Verify NAT Gateway exists and is attached to private subnets
2. Check IAM execution role has ECR permissions
3. Ensure ECR repository exists
4. Verify image tag exists in ECR

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

env:
  AWS_REGION: eu-west-2
  ECR_REPOSITORY: gym-advisor-frontend

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build \
            --platform linux/amd64 \
            --build-arg NEXT_PUBLIC_API_URL=${{ secrets.NEXT_PUBLIC_API_URL }} \
            --build-arg NEXT_PUBLIC_API_KEY=${{ secrets.NEXT_PUBLIC_API_KEY }} \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:latest \
            .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster gym-advisor-cluster \
            --service gym-advisor-frontend \
            --force-new-deployment \
            --region $AWS_REGION
```

### Required GitHub Secrets

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_API_KEY`

## DNS Configuration

After deployment, configure your DNS:

### Route53

```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns <alb-arn> \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region eu-west-2)

# Create A record (alias)
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-change.json
```

`dns-change.json`:
```json
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "frontend.gymadvisor.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "<alb-hosted-zone-id>",
        "DNSName": "<alb-dns-name>",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
```

### External DNS Provider

Create a CNAME record:
- **Name**: `frontend` (or `frontend.gymadvisor.com`)
- **Type**: CNAME
- **Value**: `<alb-dns-name>`
- **TTL**: 300

## Cost Estimation

Approximate monthly costs (EU West 2):

- **Fargate**: ~$30-60 (2 tasks, 0.5 vCPU, 1GB memory)
- **ALB**: ~$20 (existing, shared)
- **NAT Gateway**: ~$35 (existing, shared)
- **ECR Storage**: ~$1 (for a few images)
- **CloudWatch Logs**: ~$1-5 (depends on traffic)
- **Data Transfer**: ~$10-20 (depends on traffic)

**Total**: ~$40-80/month (excluding shared resources)

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

This will remove:
- ECR repository and images
- ECS service and task definition
- IAM roles and policies
- Security groups
- ALB target group and listener rule
- CloudWatch log group

The ALB, VPC, subnets, and ECS cluster will remain.

## Support and Troubleshooting

For issues:
1. Check CloudWatch logs first
2. Verify ECS service events
3. Check target group health
4. Review security group rules
5. Verify IAM permissions
6. Check Terraform state: `terraform show`

## Next Steps

After successful deployment:
1. Set up CloudWatch alarms for monitoring
2. Configure automated backups
3. Implement CI/CD pipeline
4. Set up staging environment
5. Configure WAF rules (optional)
6. Set up CloudFront CDN (optional)
