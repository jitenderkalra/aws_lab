#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-devops-free-tier}"
REGION="${REGION:-us-east-1}"
ACCOUNT_BUCKET="tf-state-devops-620356661348-ue1-20251205b"
LOCK_TABLE="tf-lock-devops-ue1-20251205b"

echo "Using profile=${PROFILE}, region=${REGION}"

# us-east-1 bucket creation cannot include LocationConstraint
if [ "${REGION}" = "us-east-1" ]; then
  aws --profile "${PROFILE}" --region "${REGION}" s3api create-bucket \
    --bucket "${ACCOUNT_BUCKET}" \
    2>/dev/null || echo "Bucket already exists or cannot be created (check region/ownership)."
else
  aws --profile "${PROFILE}" --region "${REGION}" s3api create-bucket \
    --bucket "${ACCOUNT_BUCKET}" \
    --create-bucket-configuration LocationConstraint="${REGION}" \
    2>/dev/null || echo "Bucket already exists or cannot be created (check region/ownership)."
fi

aws --profile "${PROFILE}" --region "${REGION}" s3api put-bucket-versioning \
  --bucket "${ACCOUNT_BUCKET}" \
  --versioning-configuration Status=Enabled

aws --profile "${PROFILE}" --region "${REGION}" dynamodb create-table \
  --table-name "${LOCK_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "Lock table already exists."

echo "State backend ready: bucket=${ACCOUNT_BUCKET}, table=${LOCK_TABLE}"
