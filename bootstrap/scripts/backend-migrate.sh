#!/usr/bin/env bash
set -e

ROOT_DIR=${ROOT_DIR:?ROOT_DIR not set}

# 1) Reading output values after bootstrap apply is complete
BUCKET=$(terraform output -raw state_bucket)
TABLE=$(terraform output -raw lock_table)
REGION=$(terraform output -raw aws_region)

echo "Generating backend.hcl for bucket ${BUCKET}"

# 1) Create / overwrite backend.hcl
cat >$ROOT_DIR/main/backend.hcl <<EOF
bucket         = "${BUCKET}"
key            = "main/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${TABLE}"
EOF

# 2) 

# 2) Ensure main.tf contains backend "s3" {} block (to suppress warnings)
MAIN_TF="${BASH_SOURCE%/*}main.tf"
if ! grep -q 'backend "s3"' "$MAIN_TF"; then
    echo "Injecting backend \"s3\" {} stub into main.tf"
    # insert after the required_version line
    sed -i "/required_version/ a\\  backend \"s3\" {\\n    bucket         = \\\"${BUCKET}\\\"\\n    key            = \\\"terraform/state-test/terraform.tfstate\\\"\\n    region         = \\\"${REGION}\\\"\\n  }" "$MAIN_TF"
fi

# 3) Migrate the local state to the new S3+DDB backend
terraform init -backend-config=backend.hcl -migrate-state -force-copy -input=false
echo "Backend migration complete"

