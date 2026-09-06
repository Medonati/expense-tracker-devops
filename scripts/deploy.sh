#!/bin/bash

set -e

IMAGE="$1"

if [ -z "$IMAGE" ]; then
  echo "Usage: ./deploy.sh <image>"
  exit 1
fi

REGION="us-east-1"
REGISTRY="748241639517.dkr.ecr.us-east-1.amazonaws.com"

echo "Deploying image: $IMAGE"

echo "Authenticating Docker to ECR..."

aws ecr get-login-password --region "$REGION" | \
docker login \
  --username AWS \
  --password-stdin \
  "$REGISTRY"

echo "Pulling image..."
docker pull "$IMAGE"

echo "Stopping existing backend container..."
docker stop backend || true

echo "Removing existing backend container..."
docker rm backend || true

echo "Starting new backend container..."
docker run -d \
  --name backend \
  --network expense-network \
  -p 3000:3000 \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  --restart unless-stopped \
  "$IMAGE"

echo "Waiting for application to start..."
sleep 10

echo "Running health check..."
curl --fail http://localhost:3000/health

echo
echo "Deployment successful."
