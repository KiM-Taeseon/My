## Run the Terraform Example

### run-example.sh
#!/bin/bash

# Script to trigger a Terraform run on the example project

# Get the instance IP from terraform output
cd infrastructure
INSTANCE_IP=$(terraform output -raw instance_public_ip)
cd ..

# Check if IP is available
if [ -z "$INSTANCE_IP" ]; then
  echo "Error: Could not get instance IP. Is the infrastructure deployed?"
  exit 1
fi

# Default variables
COMMAND=${1:-"plan"}
ENVIRONMENT=${2:-"dev"}
VPC_NAME=${3:-"example-vpc"}

# Trigger the webhook
echo "Triggering $COMMAND operation on example-project..."
curl -X POST http://$INSTANCE_IP:8080/run-terraform \
     -H "Content-Type: application/json" \
     -d '{
           "project_name": "example-project",
           "command": "'$COMMAND'",
           "variables": {
             "vpc_name": "'$VPC_NAME'",
             "environment": "'$ENVIRONMENT'"
           }
         }'

echo -e "\nRequest sent! Check the logs on the EC2 instance to monitor progress."
echo "SSH command: ssh -i your-key.pem ec2-user@$INSTANCE_IP"
echo "Log location: /home/terraform/logs/"