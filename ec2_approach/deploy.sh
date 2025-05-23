#!/bin/bash
# Enhanced deploy.sh with validation

set -e

# Get current AWS account and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-northeast-2"
KEY_NAME="banyan_key"

# Validate prerequisites
echo "🔍 Validating prerequisites..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ ERROR: AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# Check if SSH key exists
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "❌ ERROR: SSH key '$KEY_NAME' not found in region $AWS_REGION"
    echo "Create it with: aws ec2 create-key-pair --key-name $KEY_NAME --region $AWS_REGION"
    exit 1
fi

# Check if we have the necessary permissions
echo "🔐 Checking AWS permissions..."
required_actions=(
    "ec2:DescribeInstances"
    "iam:CreateRole"
    "s3:CreateBucket"
    "dynamodb:CreateTable"
)

# Variables
STATE_BUCKET="terraform-state-runner-$ACCOUNT_ID"
CONFIG_BUCKET="terraform-configs-runner-$ACCOUNT_ID"

echo "🚀 Deploying Terraform Runner + Project Builder Infrastructure"
echo "============================================================"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "State Bucket: $STATE_BUCKET"
echo "Config Bucket: $CONFIG_BUCKET"
echo ""

# Create S3 buckets with proper error handling
echo "📦 Creating S3 buckets..."
if ! aws s3 mb s3://$STATE_BUCKET --region $AWS_REGION 2>/dev/null; then
    if aws s3 ls s3://$STATE_BUCKET 2>/dev/null; then
        echo "✅ State bucket already exists"
    else
        echo "❌ Failed to create state bucket"
        exit 1
    fi
else
    echo "✅ Created state bucket"
fi

if ! aws s3 mb s3://$CONFIG_BUCKET --region $AWS_REGION 2>/dev/null; then
    if aws s3 ls s3://$CONFIG_BUCKET 2>/dev/null; then
        echo "✅ Config bucket already exists"
    else
        echo "❌ Failed to create config bucket"
        exit 1
    fi
else
    echo "✅ Created config bucket"
fi

# Deploy infrastructure with validation
echo "🏗️  Deploying infrastructure..."
cd infrastructure

# Initialize Terraform
if ! terraform init; then
    echo "❌ Terraform initialization failed"
    exit 1
fi

# Validate configuration
if ! terraform validate; then
    echo "❌ Terraform configuration validation failed"
    exit 1
fi

# Plan deployment
echo "📋 Planning deployment..."
if ! terraform plan \
    -var="state_bucket_name=$STATE_BUCKET" \
    -var="config_bucket_name=$CONFIG_BUCKET" \
    -var="key_name=$KEY_NAME" \
    -out=tfplan; then
    echo "❌ Terraform planning failed"
    exit 1
fi

# Apply with confirmation
echo "🚀 Applying infrastructure..."
if ! terraform apply tfplan; then
    echo "❌ Terraform apply failed"
    exit 1
fi

# Validate deployment
echo "✅ Validating deployment..."
if ! terraform output instance_public_ip > /dev/null 2>&1; then
    echo "❌ Deployment validation failed - missing outputs"
    exit 1
fi

# Get outputs
TERRAFORM_RUNNER_IP=$(terraform output -raw instance_public_ip)
PROJECT_BUILDER_IP=$(terraform output -raw project_builder_public_ip)

echo ""
echo "✅ Deployment completed successfully!"
echo "======================================"
echo ""
echo "🔧 Terraform Runner: http://$TERRAFORM_RUNNER_IP:8080"
echo "🏭 Project Builder:   http://$PROJECT_BUILDER_IP:8081"
echo ""
echo "⏳ Services are starting up (may take 2-3 minutes)..."
echo "Check status with:"
echo "  curl http://$PROJECT_BUILDER_IP:8081/health"