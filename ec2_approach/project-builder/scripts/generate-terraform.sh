#!/bin/bash

PROJECT_NAME=$1
SPEC_FILE_PATH=$2
PROJECT_DIR=$3
TERRAFORM_PROJECT_DIR=$4

# 1) Copy every file from TERRAFORM_PROJECT_DIR to PROJECT_DIR
cp -r "$TERRAFORM_PROJECT_DIR"/* "$PROJECT_DIR"/

# 2) Rename infrastructure_spec.json to uservar.tfvars.json inside PROJECT_DIR (if it exists)
if [ -f "$PROJECT_DIR/infrastructure_spec.json" ]; then
    cp "$PROJECT_DIR/infrastructure_spec.json" "$PROJECT_DIR/uservar.tfvars.json"
fi