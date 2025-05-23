# EC2 Terraform Provisioner

A solution for running Terraform operations on an EC2 instance via a webhook, with support for provisioning infrastructure across multiple AWS accounts.

## Features

- Dedicated EC2 instance for Terraform operations
- Webhook API for triggering Terraform commands
- S3 storage for Terraform state and project files
- DynamoDB for state locking
- Proper IAM permissions for secure operations
- Multi-account support for managing infrastructure across your AWS organization

## Project Structure

```
ec2-terraform-provisioner/
├── infrastructure/             # IaC to set up the EC2 instance and related resources
│   ├── main.tf                 # Main EC2 and networking configuration
│   ├── storage.tf              # S3 buckets and DynamoDB table
│   ├── security.tf             # Security groups and IAM roles
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── user_data.sh            # EC2 user data script
├── terraform-runner/           # Script files to be deployed to EC2
│   ├── run-terraform.sh        # Main script to execute Terraform commands
│   ├── webhook-server.py       # Simple web server to accept Terraform commands
│   └── systemd/                # Systemd service files
│       └── terraform-webhook.service  # Service definition
├── terraform-projects/         # Example Terraform projects to be deployed
│   └── example-project/        # A sample infrastructure project
│       ├── main.tf             # Main Terraform configuration
│       ├── variables.tf        # Input variables
│       └── outputs.tf          # Output values
└── deploy.sh                   # Deployment script
```

## How It Works

1. **Deployment**: The infrastructure is set up using Terraform, including an EC2 instance, S3 buckets, and a DynamoDB table.

2. **Initialization**: When the EC2 instance launches, it runs the `user_data.sh` script that:
   - Installs Terraform and required tools
   - Sets up the webhook server and Terraform runner script
   - Configures a systemd service to run the webhook

3. **Project Deployment**: Terraform projects are packaged as ZIP files and uploaded to the S3 bucket.

4. **Execution**: The webhook server accepts HTTP requests to run Terraform commands, which are executed by the runner script.

5. **Multi-Account Support**: Optionally provide AWS credentials in the webhook request to provision infrastructure in different AWS accounts.

## Setup Instructions

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/ec2-terraform-provisioner.git
   cd ec2-terraform-provisioner
   ```

2. Deploy the infrastructure:
   ```
   ./deploy.sh
   ```

3. Upload a Terraform project:
   ```
   ./upload-project.sh path/to/your/terraform/project your-project-name
   ```

4. Trigger Terraform operations via the webhook:
   ```
   curl -X POST http://<EC2_IP>:8080/run-terraform \
        -H "Content-Type: application/json" \
        -d '{
              "project_name": "your-project-name",
              "command": "apply",
              "variables": {
                "key1": "value1",
                "key2": "value2"
              }
            }'
   ```

## Multi-Account Provisioning

### Basic Usage

To provision infrastructure in a different AWS account, include an `aws_credentials` object in your webhook request:

```json
{
  "project_name": "network-infrastructure",
  "command": "apply",
  "variables": {
    "vpc_cidr": "10.0.0.0/16",
    "environment": "production"
  },
  "aws_credentials": {
    "access_key": "AKIAIOSFODNN7EXAMPLE",
    "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "session_token": "AQoDYXdzEJr...<optional session token>...",
    "region": "us-west-2",
    "account_id": "123456789012"  // Optional, for logging purposes
  }
}
```

### How It Works

The system uses a straightforward approach to manage infrastructure across multiple AWS accounts:

1. **Direct Provider Configuration**:
   - AWS credentials are directly configured in the Terraform provider
   - No environment variables or credential files needed
   - Works naturally with Terraform's provider architecture

2. **Workspace Isolation**:
   - A unique run ID is generated for each execution
   - A separate working directory is created for each run
   - All files are isolated to this directory
   - The workspace is cleaned up after execution completes

3. **State Management**:
   - Terraform state is always stored in the primary account's S3 bucket
   - DynamoDB locking prevents conflicts for concurrent operations

### Obtaining Credentials Securely

The recommended way to obtain credentials for target accounts is using AWS STS AssumeRole:

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::TARGET_ACCOUNT_ID:role/TerraformExecutionRole" \
  --role-session-name "TerraformSession"
```

This returns temporary credentials that can be used in the webhook request.

### Using with run-example.sh

The `run-example.sh` script accepts an optional fourth parameter for the target AWS account ID:

```bash
./run-example.sh apply production my-vpc 123456789012
```

## Security Considerations

- Restrict SSH and webhook access using security groups
- Use private subnets with NAT gateway for production
- Limit IAM permissions to only what is necessary
- Consider adding authentication to the webhook
- Set up CloudWatch alarms for monitoring
- Use temporary credentials when providing AWS credentials
- Consider implementing a more robust authentication mechanism for the webhook

## Benefits over Lambda Approach

- No 15-minute execution time limit
- Larger disk space for operations
- More memory available
- Persistent filesystem for caching
- Simpler implementation (no container required)
- Can run longer-running Terraform operations
- Easier to debug (SSH access available)

## Troubleshooting

- SSH into the EC2 instance to check logs:
  ```
  ssh -i your-key.pem ec2-user@<EC2_IP>
  ```

- View webhook logs:
  ```
  sudo journalctl -u terraform-webhook
  ```

- Check Terraform execution logs:
  ```
  ls -la /home/terraform/logs/
  ```

## IAM Setup for Target Accounts

For multi-account provisioning, you need to set up appropriate IAM roles in your target accounts:

1. Create a role in each target account with permissions to create the required resources
2. Set up a trust relationship to allow the primary account to assume this role
3. Use STS AssumeRole to obtain temporary credentials before making the webhook request

Example trust policy for the target account role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::PRIMARY_ACCOUNT_ID:role/TerraformRunnerRole"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## License

MIT