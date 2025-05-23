# Project Builder Service

The Project Builder service converts JSON infrastructure specifications into Terraform configuration files and uploads them to S3 for deployment by the Terraform Runner.

## Directory Structure

```
project-builder/
├── webhook-server.py                    # Main webhook server (port 8081)
├── build-and-upload.sh                 # Script to build and upload projects
├── scripts/
│   └── generate-terraform.sh           # Black box Terraform generator
├── systemd/
│   └── project-builder-webhook.service # Systemd service configuration
└── README.md                           # This file
```

## Service Endpoints

### POST /build-project
Builds a Terraform project from JSON infrastructure specification.

**Request:**
```json
{
  "project_name": "my-web-app",
  "infrastructure_spec": {
    "type": "web_application",
    "vpc_cidr": "10.0.0.0/16",
    "instances": {
      "type": "t3.medium",
      "min_size": 2,
      "max_size": 6
    },
    "database": {
      "engine": "mysql",
      "instance_class": "db.t3.micro"
    }
  }
}
```

**Response:**
```json
{
  "status": "accepted",
  "message": "Project build for my-web-app started",
  "build_id": "1699123456",
  "log_file": "/home/projectbuilder/logs/build-my-web-app-1699123456.log",
  "estimated_time": "30-60 seconds"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "project-builder",
  "version": "1.0.0",
  "timestamp": 1699123456.789,
  "checks": {
    "directories": true,
    "generator_script": true,
    "upload_script": true
  }
}
```

### GET /status
Shows recent build status.

**Response:**
```json
{
  "service": "project-builder",
  "uptime": 1699123456.789,
  "recent_builds": [
    {
      "filename": "build-my-web-app-1699123456.log",
      "size": 2048,
      "modified": 1699123456.789
    }
  ],
  "logs_directory": "/home/projectbuilder/logs"
}
```

## Supported Infrastructure Types

### 1. VPC Infrastructure (`"type": "vpc"`)
Creates basic VPC with public/private subnets, internet gateway, and routing.

**Specification:**
```json
{
  "type": "vpc",
  "vpc_cidr": "10.0.0.0/16",
  "public_subnets": ["10.0.1.0/24", "10.0.2.0/24"],
  "private_subnets": ["10.0.3.0/24", "10.0.4.0/24"],
  "enable_nat_gateway": true
}
```

### 2. Web Application (`"type": "web_application"`)
Creates a complete web application infrastructure with load balancer, auto scaling, and database.

**Specification:**
```json
{
  "type": "web_application",
  "vpc": {
    "cidr": "10.1.0.0/16"
  },
  "load_balancer": {
    "type": "application",
    "scheme": "internet-facing"
  },
  "instances": {
    "type": "t3.medium",
    "min_size": 2,
    "max_size": 6,
    "desired_capacity": 2
  },
  "database": {
    "engine": "mysql",
    "instance_class": "db.t3.micro",
    "allocated_storage": 20
  }
}
```

### 3. Data Processing (`"type": "data_processing"`)
Creates data processing infrastructure with S3 buckets, Lambda functions, and DynamoDB tables.

**Specification:**
```json
{
  "type": "data_processing",
  "storage": {
    "buckets": [
      {"name": "raw-data", "versioning": true},
      {"name": "processed-data", "versioning": true},
      {"name": "archive-data", "lifecycle": true}
    ]
  },
  "processing": {
    "lambda_functions": [
      {"name": "data-ingestion", "runtime": "python3.9"},
      {"name": "data-transform", "runtime": "python3.9"}
    ]
  },
  "database": {
    "type": "dynamodb",
    "tables": [
      {"name": "processing-metadata", "hash_key": "job_id"},
      {"name": "data-catalog", "hash_key": "dataset_id"}
    ]
  }
}
```

### 4. Generic Infrastructure (`"type": "generic"` or any other type)
Creates basic S3 bucket and DynamoDB table for testing purposes.

## Black Box Script Interface

The `generate-terraform.sh` script is called with these parameters:

```bash
/home/projectbuilder/scripts/generate-terraform.sh \
    "$PROJECT_NAME" \
    "$SPEC_FILE_PATH" \
    "$OUTPUT_DIR"
```

### Input
- `PROJECT_NAME`: Name of the project
- `SPEC_FILE_PATH`: Path to JSON specification file
- `OUTPUT_DIR`: Directory where Terraform files should be generated

### Output Requirements
The script must generate at minimum:
- `main.tf` - Main Terraform configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `versions.tf` - Terraform version constraints

### Customization
To customize the Terraform generation logic:

1. Replace `/home/projectbuilder/scripts/generate-terraform.sh` with your implementation
2. Ensure it follows the same interface (parameters and output requirements)
3. Make sure it's executable (`chmod +x`)
4. Test with sample JSON specifications

## Build Process

1. **Receive Request**: JSON specification via webhook
2. **Validate Input**: Check project name and JSON format
3. **Generate Files**: Call black box script to create Terraform files
4. **Validate Output**: Ensure required files are created
5. **Package Project**: Create ZIP file excluding temporary files
6. **Upload to S3**: Store in config bucket for Terraform Runner
7. **Cleanup**: Remove temporary directories and files

## Monitoring and Debugging

### Service Status
```bash
# Check service status
sudo systemctl status project-builder-webhook

# View service logs
sudo journalctl -u project-builder-webhook -f

# Restart service
sudo systemctl restart project-builder-webhook
```

### Build Logs
```bash
# View recent builds
ls -la /home/projectbuilder/logs/

# Follow a specific build
tail -f /home/projectbuilder/logs/build-PROJECT_NAME-BUILD_ID.log

# View build history
find /home/projectbuilder/logs -name "build-*.log" -exec ls -la {} \;
```

### Debugging Failed Builds
1. Check the specific build log file
2. Verify the JSON specification format
3. Test the generator script manually:
   ```bash
   sudo -u projectbuilder /home/projectbuilder/scripts/generate-terraform.sh \
       "test-project" \
       "/path/to/spec.json" \
       "/tmp/test-output"
   ```
4. Check S3 permissions and bucket access

## Security Considerations

- Service runs as non-root user (`projectbuilder`)
- Limited file system access via systemd security settings
- Input validation for project names and JSON format
- Temporary files are cleaned up after processing
- S3 access limited to config bucket only

## Performance

- **Timeout**: 5 minutes per build process
- **Concurrent Builds**: Supported (separate threads)
- **Resource Limits**: 4096 processes, 65536 file descriptors
- **Memory**: No explicit limit (relies on system limits)

## Integration with Terraform Runner

Once a project is built and uploaded to S3, it can be deployed using the Terraform Runner:

```bash
# Deploy the generated project
curl -X POST http://terraform-runner:8080/run-terraform \
     -H "Content-Type: application/json" \
     -d '{
           "project_name": "my-web-app",
           "command": "apply",
           "variables": {
             "environment": "production"
           }
         }'
```

## Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid JSON" | Malformed JSON in request | Validate JSON format |
| "Generator script failed" | Error in Terraform generation | Check generator script logs |
| "S3 upload failed" | Permission or network issues | Check IAM permissions and connectivity |
| "Timeout" | Build process exceeded 5 minutes | Optimize generator script or increase timeout |

## Extending Functionality

To add new infrastructure types:

1. Modify `generate-terraform.sh` to handle new types
2. Add new case statements for the infrastructure type
3. Create appropriate Terraform templates
4. Update this documentation with new specifications
5. Test with sample requests

## API Examples

See the main project documentation for complete API examples and integration patterns.