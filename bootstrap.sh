#!/bin/bash

ROOT_DIR=$(pwd)

cd bootstrap

terraform init
terraform apply --auto-approve

ROOT_DIR="$ROOT_DIR" source bootstrap/scripts/backend-migrate.sh

