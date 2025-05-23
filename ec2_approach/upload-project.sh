### upload-project.sh
#!/bin/bash

# Script to package and upload a Terraform project

set -e

# Variables
CONFIG_BUCKET="terraform-configs-runner-$(aws sts get-caller-identity --query Account --output text)"

# Check arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <project-directory> [project-name]"
  exit 1
fi

PROJECT_DIR=$1
PROJECT_NAME=${2:-$(basename $PROJECT_DIR)}

# Package the project
echo "Packaging project $PROJECT_NAME from directory $PROJECT_DIR..."
cd $PROJECT_DIR
zip -r ../../$PROJECT_NAME.zip .
cd ../..

# Upload to S3
echo "Uploading project to S3..."
aws s3 cp $PROJECT_NAME.zip s3://$CONFIG_BUCKET/

echo "Project $PROJECT_NAME uploaded successfully to s3://$CONFIG_BUCKET/$PROJECT_NAME.zip"