#!/bin/bash

# Deployment script for Gym Advisor Frontend to AWS ECS
# Usage: ./deploy.sh [environment] [version]

set -e

# Configuration
REGION="${AWS_REGION:-eu-west-2}"
ENVIRONMENT="${1:-production}"
VERSION="${2:-latest}"
PROJECT_NAME="gym-advisor-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    log_info "All required dependencies are installed"
}

# Get ECR repository URL
get_ecr_url() {
    log_info "Getting ECR repository URL..."

    ECR_URL=$(aws ecr describe-repositories \
        --repository-names $PROJECT_NAME \
        --region $REGION \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null || echo "")

    if [ -z "$ECR_URL" ]; then
        log_error "ECR repository not found. Please ensure the ECR repository '$PROJECT_NAME' exists in region $REGION"
        exit 1
    fi

    log_info "ECR URL: $ECR_URL"
}

# Get ECS cluster and service names
get_ecs_info() {
    log_info "Getting ECS cluster and service information..."

    # Try to find the cluster
    ECS_CLUSTER=$(aws ecs list-clusters \
        --region $REGION \
        --query "clusterArns[?contains(@, 'gyms-advisor')][0]" \
        --output text 2>/dev/null | awk -F'/' '{print $NF}' || echo "")

    # Try to find the service
    if [ -n "$ECS_CLUSTER" ]; then
        ECS_SERVICE=$(aws ecs list-services \
            --cluster "$ECS_CLUSTER" \
            --region $REGION \
            --query "serviceArns[?contains(@, 'frontend')][0]" \
            --output text 2>/dev/null | awk -F'/' '{print $NF}' || echo "")
    fi

    if [ -z "$ECS_CLUSTER" ] || [ -z "$ECS_SERVICE" ]; then
        log_error "Could not find ECS cluster or service. Please check your configuration."
        exit 1
    fi

    log_info "ECS Cluster: $ECS_CLUSTER"
    log_info "ECS Service: $ECS_SERVICE"
}

# Load environment variables
load_env_vars() {
    log_info "Loading environment variables..."

    if [ -f ".env.$ENVIRONMENT" ]; then
        export $(cat .env.$ENVIRONMENT | grep -v '^#' | xargs)
        log_info "Loaded environment from .env.$ENVIRONMENT"
    elif [ -f ".env.local" ]; then
        export $(cat .env.local | grep -v '^#' | xargs)
        log_info "Loaded environment from .env.local"
    else
        log_warn "No environment file found. Using default values."
    fi
}

# Authenticate with ECR
ecr_login() {
    log_info "Authenticating with ECR..."

    aws ecr get-login-password --region $REGION | \
        docker login --username AWS --password-stdin $ECR_URL

    if [ $? -eq 0 ]; then
        log_info "Successfully authenticated with ECR"
    else
        log_error "Failed to authenticate with ECR"
        exit 1
    fi
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."

    # Validate required environment variables
    if [ -z "$NEXT_PUBLIC_API_URL" ]; then
        log_error "NEXT_PUBLIC_API_URL is not set. Please check your .env.$ENVIRONMENT file"
        exit 1
    fi

    if [ -z "$NEXT_PUBLIC_API_KEY" ]; then
        log_error "NEXT_PUBLIC_API_KEY is not set. Please check your .env.$ENVIRONMENT file"
        exit 1
    fi

    log_info "Using API URL: $NEXT_PUBLIC_API_URL"

    docker build \
        --platform linux/amd64 \
        --build-arg NEXT_PUBLIC_API_URL="$NEXT_PUBLIC_API_URL" \
        --build-arg NEXT_PUBLIC_API_KEY="$NEXT_PUBLIC_API_KEY" \
        -t $PROJECT_NAME:$VERSION \
        -t $PROJECT_NAME:latest \
        -t $ECR_URL:$VERSION \
        -t $ECR_URL:latest \
        .

    if [ $? -eq 0 ]; then
        log_info "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Push image to ECR
push_image() {
    log_info "Pushing Docker image to ECR..."

    docker push $ECR_URL:$VERSION
    docker push $ECR_URL:latest

    if [ $? -eq 0 ]; then
        log_info "Docker image pushed successfully"
    else
        log_error "Failed to push Docker image"
        exit 1
    fi
}

# Update ECS service
update_service() {
    log_info "Updating ECS service..."

    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --force-new-deployment \
        --region $REGION \
        > /dev/null

    if [ $? -eq 0 ]; then
        log_info "ECS service update initiated"
    else
        log_error "Failed to update ECS service"
        exit 1
    fi
}

# Wait for deployment to complete
wait_for_deployment() {
    log_info "Waiting for deployment to complete..."

    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $REGION

    if [ $? -eq 0 ]; then
        log_info "Deployment completed successfully!"
    else
        log_error "Deployment failed or timed out"
        exit 1
    fi
}

# Main execution
main() {
    log_info "Starting deployment for $PROJECT_NAME ($ENVIRONMENT) version $VERSION"

    check_dependencies
    load_env_vars
    get_ecr_url
    get_ecs_info
    ecr_login
    build_image
    push_image
    update_service
    wait_for_deployment

    log_info "Deployment completed successfully!"
}

# Run main function
main
