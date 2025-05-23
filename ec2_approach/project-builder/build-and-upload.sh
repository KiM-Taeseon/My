#!/bin/bash

# Project Builder and Upload Script
# Usage: ./build-and-upload.sh [project_name] [spec_file_path] [build_id]

set -e

# Get parameters
PROJECT_NAME=$1
SPEC_FILE_PATH=$2
BUILD_ID=$3

# Fixed: Remove the $ from the variable assignment
TERRAFORM_PROJECT_DIR="/home/templates/"

# Validate parameters
if [ -z "$PROJECT_NAME" ] || [ -z "$SPEC_FILE_PATH" ] || [ -z "$BUILD_ID" ]; then
    echo "Usage: $0 <project_name> <spec_file_path> <build_id>"
    exit 1
fi

# Load environment variables
source /etc/environment

# Set up logging
LOG_FILE="/home/projectbuilder/logs/build-$PROJECT_NAME-$BUILD_ID.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================="
echo "🏗️  PROJECT BUILDER STARTED"
echo "=================================="
echo "Build ID: $BUILD_ID"
echo "Project Name: $PROJECT_NAME"
echo "Spec File: $SPEC_FILE_PATH"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Working Directory: $(pwd)"
echo "=================================="

# Validate spec file exists
if [ ! -f "$SPEC_FILE_PATH" ]; then
    echo "❌ ERROR: Infrastructure specification file not found: $SPEC_FILE_PATH"
    exit 1
fi

# Create project directory
PROJECT_DIR="/home/projectbuilder/projects/$PROJECT_NAME-$BUILD_ID"
echo "📁 Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

# Copy the infrastructure spec for reference and debugging
echo "📋 Copying infrastructure specification for reference..."
cp "$SPEC_FILE_PATH" "$PROJECT_DIR/infrastructure_spec.json"

echo ""
echo "📊 Infrastructure Specification:"
echo "================================="
cat "$PROJECT_DIR/infrastructure_spec.json" | jq . 2>/dev/null || cat "$PROJECT_DIR/infrastructure_spec.json"
echo "================================="
echo ""

# Validate JSON format
if ! jq empty "$PROJECT_DIR/infrastructure_spec.json" 2>/dev/null; then
    echo "❌ ERROR: Invalid JSON format in infrastructure specification"
    exit 1
fi

# Check if generator script exists
GENERATOR_SCRIPT="/home/projectbuilder/scripts/generate-terraform.sh"
if [ ! -f "$GENERATOR_SCRIPT" ]; then
    echo "❌ ERROR: Terraform generator script not found: $GENERATOR_SCRIPT"
    exit 1
fi

if [ ! -x "$GENERATOR_SCRIPT" ]; then
    echo "❌ ERROR: Terraform generator script is not executable: $GENERATOR_SCRIPT"
    exit 1
fi

# Call the black box script to generate Terraform files
echo "🔧 Calling Terraform generator script..."
echo "Command: $GENERATOR_SCRIPT \"$PROJECT_NAME\" \"$SPEC_FILE_PATH\" \"$PROJECT_DIR\" \"$TERRAFORM_PROJECT_DIR\""
echo ""

# Run the generator with timeout
timeout 240 "$GENERATOR_SCRIPT" "$PROJECT_NAME" "$SPEC_FILE_PATH" "$PROJECT_DIR" "$TERRAFORM_PROJECT_DIR"
GENERATOR_EXIT_CODE=$?

if [ $GENERATOR_EXIT_CODE -eq 124 ]; then
    echo "❌ ERROR: Terraform generator script timed out (exceeded 4 minutes)"
    exit 1
elif [ $GENERATOR_EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Terraform generator script failed with exit code: $GENERATOR_EXIT_CODE"
    exit 1
fi

echo ""
echo "✅ Terraform generation completed successfully!"
echo ""

# Show project structure
echo ""
echo "📦 Generated project structure:"
echo "==============================="
find "$PROJECT_DIR" -type f | sort | while read -r file; do
    rel_path=${file#$PROJECT_DIR/}
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
    echo "  $rel_path ($size bytes)"
done
echo "==============================="

# Validate Terraform syntax (basic check)
echo ""
echo "🔧 Validating Terraform syntax..."
cd "$PROJECT_DIR"

# Check for basic Terraform syntax errors
terraform fmt -check=true -write=false . || {
    echo "⚠️  WARNING: Terraform formatting issues detected. Auto-formatting..."
    terraform fmt .
}

# Basic validation without initialization
if terraform validate -no-color 2>/dev/null; then
    echo "✅ Terraform syntax validation passed"
else
    echo "⚠️  WARNING: Terraform validation warnings (this may be normal if providers aren't initialized)"
fi

cd - > /dev/null

# Package the project (exclude the spec file from the ZIP)
echo ""
echo "📦 Packaging project..."
cd "$PROJECT_DIR"
ZIP_FILE="../$PROJECT_NAME.zip"

# Create ZIP excluding infrastructure spec and any temporary files
zip -r "$ZIP_FILE" . \
    -x "infrastructure_spec.json" \
    -x "*.tmp" \
    -x "*.log" \
    -x ".terraform/*" \
    -x "terraform.tfstate*" \
    -x ".git/*"

cd - > /dev/null

# Check ZIP file was created
if [ ! -f "$PROJECT_DIR/../$PROJECT_NAME.zip" ]; then
    echo "❌ ERROR: Failed to create ZIP file"
    exit 1
fi

ZIP_SIZE=$(stat -f%z "$PROJECT_DIR/../$PROJECT_NAME.zip" 2>/dev/null || stat -c%s "$PROJECT_DIR/../$PROJECT_NAME.zip" 2>/dev/null)
echo "✅ Project packaged successfully (ZIP size: $ZIP_SIZE bytes)"

# Upload to S3
echo ""
echo "☁️  Uploading project to S3..."
echo "Destination: s3://$CONFIG_BUCKET/$PROJECT_NAME.zip"

aws s3 cp "$PROJECT_DIR/../$PROJECT_NAME.zip" "s3://$CONFIG_BUCKET/" --region "$AWS_REGION" --no-progress

# Verify upload
echo "🔍 Verifying S3 upload..."
if aws s3 ls "s3://$CONFIG_BUCKET/$PROJECT_NAME.zip" --region "$AWS_REGION" > /dev/null 2>&1; then
    S3_SIZE=$(aws s3 ls "s3://$CONFIG_BUCKET/$PROJECT_NAME.zip" --region "$AWS_REGION" | awk '{print $3}')
    echo "✅ Project successfully uploaded to S3 (size: $S3_SIZE bytes)"
    
    # Set metadata for tracking
    aws s3api put-object-tagging \
        --bucket "$CONFIG_BUCKET" \
        --key "$PROJECT_NAME.zip" \
        --tagging "TagSet=[{Key=BuildId,Value=$BUILD_ID},{Key=BuildDate,Value=$(date -u +%Y-%m-%d)},{Key=Generator,Value=project-builder}]" \
        --region "$AWS_REGION" || echo "⚠️  WARNING: Failed to set S3 object tags"
else
    echo "❌ ERROR: Failed to verify S3 upload"
    exit 1
fi

# Clean up temporary files
echo ""
echo "🧹 Cleaning up temporary files..."
rm -rf "$PROJECT_DIR"
rm -f "$PROJECT_DIR/../$PROJECT_NAME.zip"

echo "✅ Cleanup completed"

# Final summary
echo ""
echo "=================================="
echo "🎉 PROJECT BUILD COMPLETED!"
echo "=================================="
echo "Project Name: $PROJECT_NAME"
echo "Build ID: $BUILD_ID"
echo "S3 Location: s3://$CONFIG_BUCKET/$PROJECT_NAME.zip"
echo "Build Duration: $(($(date +%s) - $BUILD_ID)) seconds"
echo "Status: SUCCESS ✅"
echo ""
echo "📋 Next Steps:"
echo "1. Project is now available for Terraform deployment"
echo "2. Use the Terraform Runner to deploy this project"
echo "3. Check logs at: $LOG_FILE"
echo "=================================="

exit 0