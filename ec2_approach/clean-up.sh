### clean-up.sh
#!/bin/bash

# Script to clean up infrastructure

set -e

echo "WARNING: This will destroy all resources created by this project."
echo "Type 'yes' to confirm:"
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# First destroy any infrastructure created by Terraform projects
echo "Destroying infrastructure created by Terraform projects..."
./run-example.sh destroy dev example-vpc

# Wait for the destroy operation to complete
echo "Waiting for destroy operation to complete (30 seconds)..."
sleep 30

# Destroy the runner infrastructure
echo "Destroying runner infrastructure..."
cd infrastructure
terraform destroy -auto-approve

# Delete S3 buckets
STATE_BUCKET="terraform-state-runner-$(aws sts get-caller-identity --query Account --output text)"
CONFIG_BUCKET="terraform-configs-runner-$(aws sts get-caller-identity --query Account --output text)"

echo "Emptying and deleting S3 buckets..."
aws s3 rm s3://$STATE_BUCKET --recursive
aws s3 rb s3://$STATE_BUCKET --force

aws s3 rm s3://$CONFIG_BUCKET --recursive
aws s3 rb s3://$CONFIG_BUCKET --force

echo "Cleanup complete!"