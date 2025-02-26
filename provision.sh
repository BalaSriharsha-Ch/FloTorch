#!/bin/bash

# Function to validate password complexity
validate_password() {
    local password=$1
    if [[ -z "$password" ]]; then
        return 1
    fi
    [[ ${#password} -ge 8 && ${#password} -le 41 ]] &&
    [[ "$password" =~ [A-Za-z] ]] &&
    [[ "$password" =~ [0-9] ]] &&
    [[ "$password" =~ [^A-Za-z0-9] ]]
}

# Function to prompt for password with validation
prompt_password() {
    local prompt_text=$1
    local confirm_text=$2
    local password=""
    local password_confirm=""
    
    while true; do
        if ! read -s -p "$prompt_text" password || [ $? -ne 0 ]; then
            echo "Error: Failed to read password input"
            exit 1
        fi
        echo
        if validate_password "$password"; then
            if ! read -s -p "$confirm_text" password_confirm || [ $? -ne 0 ]; then
                echo "Error: Failed to read confirmation password"
                exit 1
            fi
            echo
            if [ "$password" = "$password_confirm" ]; then
                echo "$password"
                return 0
            else
                echo "Error: Passwords do not match. Please try again."
            fi
        else
            echo "Error: Password must be 12-41 characters with at least one letter, one number, and one symbol."
        fi
    done
}

# Function to save environment to JSON
save_environment() {
    local suffix=$1
    if [ -z "$suffix" ]; then
        echo "Error: No suffix provided for environment save"
        exit 1
    fi
    
    if ! mkdir -p .envs 2>/dev/null; then
        echo "Error: Failed to create .envs directory"
        exit 1
    fi
    
    if ! cat > ".envs/${suffix}.json" << EOF
{
    "version": "${VERSION}",
    "project_name": "${PROJECT_NAME}",
    "table_suffix": "${TABLE_SUFFIX}",
    "client_name": "${CLIENT_NAME}",
    "opensearch_user": "${OPENSEARCH_USER}",
    "opensearch_password": "${OPENSEARCH_PASSWORD}",
    "nginx_password": "${NGINX_PASSWORD}",
    "region": "${REGION}",
    "prerequisites_met": "${PREREQUISITES_MET}",
    "need_opensearch": "${NEED_OPENSEARCH}"
}
EOF
    then
        echo "Error: Failed to write environment configuration to file"
        exit 1
    fi
    echo "Environment configuration saved to .envs/${suffix}.json"
}

# Function to load environment from JSON
load_environment() {
    local env_file=".envs/$1.json"
    if [ ! -f "$env_file" ]; then
        echo "Error: Environment file not found: $env_file"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq command not found. Please install jq to parse JSON."
        exit 1
    fi
    
    VERSION=$(jq -r '.version' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse version"; exit 1; }
    PROJECT_NAME=$(jq -r '.project_name' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse project_name"; exit 1; }
    TABLE_SUFFIX=$(jq -r '.table_suffix' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse table_suffix"; exit 1; }
    CLIENT_NAME=$(jq -r '.client_name' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse client_name"; exit 1; }
    OPENSEARCH_USER=$(jq -r '.opensearch_user' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse opensearch_user"; exit 1; }
    OPENSEARCH_PASSWORD=$(jq -r '.opensearch_password' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse opensearch_password"; exit 1; }
    NGINX_PASSWORD=$(jq -r '.nginx_password' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse nginx_password"; exit 1; }
    REGION=$(jq -r '.region' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse region"; exit 1; }
    PREREQUISITES_MET=$(jq -r '.prerequisites_met' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse prerequisites_met"; exit 1; }
    NEED_OPENSEARCH=$(jq -r '.need_opensearch' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse need_opensearch"; exit 1; }
}

# Function to list available environments
list_environments() {
    if [ ! -d ".envs" ]; then
        echo "No environments found"
        return 1
    fi
    
    local envs=()
    if ! envs=($(ls .envs/*.json 2>/dev/null | xargs -n 1 basename | sed 's/\.json$//')); then
        echo "Error: Failed to list environment files"
        return 1
    fi
    
    if [ ${#envs[@]} -eq 0 ]; then
        echo "No environments found"
        return 1
    fi
    
    echo "Available environments:"
    for env in "${envs[@]}"; do
        if [ -n "$env" ]; then
            echo "  - $env"
        fi
    done
    return 0
}

# Function to build and push Docker images
build_and_push_images() {
    local suffix=$1
    local region=$2

    echo "Building and pushing Docker images for environment ${suffix}..."

    # Get AWS account ID
    local account_id=$(aws sts get-caller-identity --query Account --output text)

    # Login to ECR
    aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin ${account_id}.dkr.ecr."$region".amazonaws.com

    # Create repositories if they don't exist
    echo "Ensuring ECR repositories exist..."
    local repos=("flotorch-app" "flotorch-indexing" "flotorch-retriever" "flotorch-evaluation" "flotorch-runtime" "flotorch-costcompute")
    for repo in "${repos[@]}"; do
        local repo_name="${repo}-${suffix}"
        if ! aws ecr describe-repositories --repository-names "$repo_name" --region "$region" >/dev/null 2>&1; then
            echo "Creating repository: $repo_name"
            aws ecr create-repository --repository-name "$repo_name" --region "$region" --image-scanning-configuration scanOnPush=true
        else
            echo "Repository $repo_name already exists"
        fi
    done

    # Build and push Docker images
    echo "Building and pushing Docker images..."
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-app-"$suffix":latest -f app/Dockerfile --push .
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-indexing-"$suffix":latest -f indexing/fargate_indexing.Dockerfile --push .
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-retriever-"$suffix":latest -f retriever/fargate_retriever.Dockerfile --push .
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-evaluation-"$suffix":latest -f evaluation/fargate_evaluation.Dockerfile --push .
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-runtime-"$suffix":latest -f opensearch/opensearch.Dockerfile --push .

    # Build cost compute image
    cd lambda_handlers
    docker build --platform linux/amd64 -t ${account_id}.dkr.ecr."$region".amazonaws.com/flotorch-costcompute-"$suffix":latest -f cost_handler/Dockerfile --push .
    cd ..

    echo "Docker images updated successfully"
}

# Function to update CloudFormation stack
update_cfn_stack() {
    local region="$1"
    local version="$2"
    local stack_name="${PROJECT_NAME}"

    if [ -z "$region" ] || [ -z "$version" ] || [ -z "$stack_name" ]; then
        echo "Error: Missing required parameters for stack update"
        exit 1
    fi

    echo "Updating CloudFormation stack '${stack_name}'..."
    if ! aws cloudformation update-stack \
        --stack-name "$stack_name" \
        --template-url "https://flotorch-public.s3.us-east-1.amazonaws.com/${version}/templates/master-template.yaml" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --disable-rollback \
        --region "$region" 2>/dev/null; then
        echo "Error: Failed to update CloudFormation stack"
        exit 1
    fi
    
    echo "Stack update initiated successfully. Please check AWS Console for status."
}

# Function to create OpenSearch service-linked role
create_opensearch_service_role() {
    echo "Creating OpenSearch service-linked role..."
    if ! aws iam get-role --role-name "AWSServiceRoleForAmazonOpenSearchService" >/dev/null 2>&1; then
        if ! aws iam create-service-linked-role --aws-service-name es.amazonaws.com 2>/dev/null; then
            echo "Error: Failed to create OpenSearch service-linked role"
            return 1
        fi
        echo "OpenSearch service-linked role created successfully"
    else
        echo "OpenSearch service-linked role already exists"
    fi
    return 0
}

# Function to update an existing environment
update_environment() {
    local update_suffix=$1
    if [ -z "$update_suffix" ]; then
        echo "Error: No environment suffix provided for update"
        exit 1
    fi
    
    echo "Loading environment ${update_suffix}..."
    if ! load_environment "$update_suffix"; then
        echo "Error: Failed to load environment"
        exit 1
    fi

    echo "FloTorch Deployment Update Configuration"
    echo "----------------------------------------"
    echo "Current values shown in brackets. Press Enter to keep current value."

    while true; do
        if ! read -p "Subscribed to FloTorch on AWS Marketplace? (yes/no) [${PREREQUISITES_MET}]: " new_prerequisites; then
            echo "Error: Failed to read prerequisites input"
            exit 1
        fi
        new_prerequisites=${new_prerequisites:-$PREREQUISITES_MET}
        if [[ "$new_prerequisites" =~ ^(yes|no)$ ]]; then
            PREREQUISITES_MET=$new_prerequisites
            break
        else
            echo "Error: Please enter either 'yes' or 'no'"
        fi
    done

    while true; do
        if ! read -p "Do you need OpenSearch? (yes/no) [${NEED_OPENSEARCH}]: " new_opensearch; then
            echo "Error: Failed to read OpenSearch input"
            exit 1
        fi
        new_opensearch=${new_opensearch:-$NEED_OPENSEARCH}
        if [[ "$new_opensearch" =~ ^(yes|no)$ ]]; then
            NEED_OPENSEARCH=$new_opensearch
            break
        else
            echo "Error: Please enter either 'yes' or 'no'"
        fi
    done

    if ! read -p "Enter Version [${VERSION}]: " new_version; then
        echo "Error: Failed to read version input"
        exit 1
    fi
    VERSION=${new_version:-$VERSION}

    if ! read -p "Enter Project Name [${PROJECT_NAME}]: " new_project_name; then
        echo "Error: Failed to read project name input"
        exit 1
    fi
    PROJECT_NAME=${new_project_name:-$PROJECT_NAME}

    echo "Table Suffix: ${TABLE_SUFFIX} (cannot be changed during update)"

    while true; do
        if ! read -p "Enter Client Name [${CLIENT_NAME}]: " new_client_name; then
            echo "Error: Failed to read client name input"
            exit 1
        fi
        new_client_name=${new_client_name:-$CLIENT_NAME}
        if [[ "$new_client_name" =~ ^[a-z0-9-]{3,20}$ ]]; then
            CLIENT_NAME=$new_client_name
            break
        else
            echo "Error: Must be 3-20 lowercase letters, numbers, or hyphens"
        fi
    done

    if [ "$NEED_OPENSEARCH" = "yes" ]; then
        if ! read -p "Enter OpenSearch admin username [${OPENSEARCH_USER}]: " new_opensearch_user; then
            echo "Error: Failed to read OpenSearch username"
            exit 1
        fi
        OPENSEARCH_USER=${new_opensearch_user:-$OPENSEARCH_USER}

        if ! read -s -p "Enter OpenSearch admin password (leave empty to keep current): " new_opensearch_password; then
            echo "Error: Failed to read OpenSearch password"
            exit 1
        fi
        echo
        if [ -n "$new_opensearch_password" ]; then
            if validate_password "$new_opensearch_password"; then
                OPENSEARCH_PASSWORD=$new_opensearch_password
            else
                echo "Invalid password format. Keeping existing password."
            fi
        fi
    fi

    if ! read -s -p "Enter NGINX password (leave empty to keep current): " new_nginx_password; then
        echo "Error: Failed to read NGINX password"
        exit 1
    fi
    echo
    if [ -n "$new_nginx_password" ]; then
        if validate_password "$new_nginx_password"; then
            NGINX_PASSWORD=$new_nginx_password
        else
            echo "Invalid password format. Keeping existing password."
        fi
    fi

    while true; do
        if ! read -p "Enter AWS region [${REGION}]: " new_region; then
            echo "Error: Failed to read region input"
            exit 1
        fi
        new_region=${new_region:-$REGION}
        if [[ "$new_region" =~ ^[a-z]{2}-[a-z]+-[0-9]{1}$ ]]; then
            REGION=$new_region
            break
        else
            echo "Error: Invalid region format. Please use format like us-east-1"
        fi
    done

    if ! save_environment "$TABLE_SUFFIX"; then
        echo "Error: Failed to save updated environment"
        exit 1
    fi

    if [ "$PREREQUISITES_MET" = "no" ]; then
        if ! build_and_push_images "$TABLE_SUFFIX" "$REGION"; then
            echo "Error: Failed to build and push Docker images"
            exit 1
        fi
    fi

    echo -e "\nUpdating CloudFormation stack..."
    if ! aws cloudformation update-stack \
        --stack-name $PROJECT_NAME \
        --template-url "https://flotorch-public.s3.us-east-1.amazonaws.com/${VERSION}/templates/master-template.yaml" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --disable-rollback \
        --region "$REGION" \
        --parameters \
            ParameterKey=PrerequisitesMet,ParameterValue="$PREREQUISITES_MET" \
            ParameterKey=NeedOpensearch,ParameterValue="$NEED_OPENSEARCH" \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=TableSuffix,ParameterValue="$TABLE_SUFFIX" \
            ParameterKey=ClientName,ParameterValue="$CLIENT_NAME" \
            ParameterKey=OpenSearchAdminUser,ParameterValue="$OPENSEARCH_USER" \
            ParameterKey=OpenSearchAdminPassword,ParameterValue="$OPENSEARCH_PASSWORD" \
            ParameterKey=NginxAuthPassword,ParameterValue="$NGINX_PASSWORD" 2>/dev/null; then
        echo "Error: Failed to initiate stack update"
        exit 1
    fi

    echo -e "\nUpdate initiated. Check AWS CloudFormation console for progress."
}

# Main execution with exception handling
if [ -d ".envs" ] && [ -n "$(ls -A .envs 2>/dev/null)" ]; then
    echo "Existing environments found."
    while true; do
        if ! read -p "Do you want to create a new environment or update an existing one? (new/update): " ACTION; then
            echo "Error: Failed to read action input"
            exit 1
        fi
        if [[ "$ACTION" =~ ^(new|update)$ ]]; then
            break
        else
            echo "Error: Please enter either 'new' or 'update'"
        fi
    done

    if [ "$ACTION" = "update" ]; then
        if list_environments; then
            while true; do
                if ! read -p "Enter the environment suffix to update: " UPDATE_SUFFIX; then
                    echo "Error: Failed to read environment suffix"
                    exit 1
                fi
                if [ -f ".envs/${UPDATE_SUFFIX}.json" ]; then
                    if ! update_environment "$UPDATE_SUFFIX"; then
                        echo "Error: Failed to update environment"
                        exit 1
                    fi
                    exit 0
                else
                    echo "Error: Environment ${UPDATE_SUFFIX} not found"
                fi
            done
        fi
    fi
fi

echo "FloTorch Deployment Configuration"
echo "----------------------------------"

while true; do
    if ! read -p "Subscribed to FloTorch on AWS Marketplace? (yes/no): " PREREQUISITES_MET; then
        echo "Error: Failed to read prerequisites input"
        exit 1
    fi
    if [[ "$PREREQUISITES_MET" =~ ^(yes|no)$ ]]; then
        break
    else
        echo "Error: Please enter either 'yes' or 'no'"
    fi
done

while true; do
    if ! read -p "Do you need OpenSearch? (yes/no) [yes]: " NEED_OPENSEARCH; then
        echo "Error: Failed to read OpenSearch input"
        exit 1
    fi
    NEED_OPENSEARCH=${NEED_OPENSEARCH:-yes}
    if [[ "$NEED_OPENSEARCH" =~ ^(yes|no)$ ]]; then
        break
    else
        echo "Error: Please enter either 'yes' or 'no'"
    fi
done

VERSION="latest"

if ! read -p "Enter Project Name [flotorch]: " PROJECT_NAME; then
    echo "Error: Failed to read project name"
    exit 1
fi
PROJECT_NAME=${PROJECT_NAME:-flotorch}

while true; do
    if ! read -p "Enter Table Suffix (exactly 6 lowercase letters): " TABLE_SUFFIX; then
        echo "Error: Failed to read table suffix"
        exit 1
    fi
    if [[ "$TABLE_SUFFIX" =~ ^[a-z]{6}$ ]]; then
        break
    else
        echo "Error: Must contain exactly 6 lowercase letters"
    fi
done

while true; do
    if ! read -p "Enter Client Name [flotorch]: " CLIENT_NAME; then
        echo "Error: Failed to read client name"
        exit 1
    fi
    CLIENT_NAME=${CLIENT_NAME:-flotorch}
    if [[ "$CLIENT_NAME" =~ ^[a-z0-9-]{3,20}$ ]]; then
        break
    else
        echo "Error: Must be 3-20 lowercase letters, numbers, or hyphens"
    fi
done

OPENSEARCH_USER="admin"
OPENSEARCH_PASSWORD="Flotorch@123"
if [ "$NEED_OPENSEARCH" = "yes" ]; then
    if ! read -p "Enter OpenSearch admin username [admin]: " OPENSEARCH_USER; then
        echo "Error: Failed to read OpenSearch username"
        exit 1
    fi
    OPENSEARCH_USER=${OPENSEARCH_USER:-admin}

    if ! create_opensearch_service_role; then
        echo "Failed to create OpenSearch service-linked role. Please ensure you have sufficient IAM permissions."
        exit 1
    fi
    
    if ! read -s -p "Enter OpenSearch admin password: " OPENSEARCH_PASSWORD; then
        echo "Error: Failed to read OpenSearch password"
        exit 1
    fi
    echo
fi

if ! read -s -p "Enter NGINX password: " NGINX_PASSWORD; then
    echo "Error: Failed to read NGINX password"
    exit 1
fi
echo

while true; do
    if ! read -p "Enter AWS region [us-east-1]: " REGION; then
        echo "Error: Failed to read region"
        exit 1
    fi
    REGION=${REGION:-us-east-1}
    if [[ "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]{1}$ ]]; then
        break
    else
        echo "Error: Invalid region format. Please use format like us-east-1"
    fi
done

if ! mkdir -p .envs 2>/dev/null; then
    echo "Error: Failed to create .envs directory"
    exit 1
fi

if ! save_environment "$TABLE_SUFFIX"; then
    echo "Error: Failed to save environment configuration"
    exit 1
fi

if [ "$PREREQUISITES_MET" = "no" ]; then
    if ! build_and_push_images "$TABLE_SUFFIX" "$REGION"; then
        echo "Error: Failed to build and push Docker images"
        exit 1
    fi
fi

echo -e "\nStarting CloudFormation deployment..."
if ! aws cloudformation create-stack \
    --stack-name "$PROJECT_NAME" \
    --template-url "https://flotorch-public.s3.us-east-1.amazonaws.com/${VERSION}/templates/master-template.yaml" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --disable-rollback \
    --region "$REGION" \
    --parameters \
        ParameterKey=PrerequisitesMet,ParameterValue="$PREREQUISITES_MET" \
        ParameterKey=NeedOpensearch,ParameterValue="$NEED_OPENSEARCH" \
        ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
        ParameterKey=TableSuffix,ParameterValue="$TABLE_SUFFIX" \
        ParameterKey=ClientName,ParameterValue="$CLIENT_NAME" \
        ParameterKey=OpenSearchAdminUser,ParameterValue="$OPENSEARCH_USER" \
        ParameterKey=OpenSearchAdminPassword,ParameterValue="$OPENSEARCH_PASSWORD" \
        ParameterKey=NginxAuthPassword,ParameterValue="$NGINX_PASSWORD" 2>/dev/null; then
    echo "Error: Failed to initiate CloudFormation deployment"
    exit 1
fi

echo -e "\nDeployment initiated. Check AWS CloudFormation console for progress."