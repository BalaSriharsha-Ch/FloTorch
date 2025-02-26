#!/bin/bash

# Function to load environment from JSON
load_environment() {
    local env_file=".envs/$1.json"
    if [ ! -f "$env_file" ]; then
        echo "Error: Environment file not found: $env_file"
        exit 1
    }
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq command not found. Please install jq to parse JSON."
        exit 1
    }
    
    PROJECT_NAME=$(jq -r '.project_name' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse project_name"; exit 1; }
    TABLE_SUFFIX=$(jq -r '.table_suffix' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse table_suffix"; exit 1; }
    REGION=$(jq -r '.region' "$env_file" 2>/dev/null) || { echo "Error: Failed to parse region"; exit 1; }
}

# Function to list available environments
list_environments() {
    if [ ! -d ".envs" ]; then
        echo "No environments found"
        return 1
    }
    
    local envs=()
    if ! envs=($(ls .envs/*.json 2>/dev/null | xargs -n 1 basename | sed 's/\.json$//')); then
        echo "Error: Failed to list environment files"
        return 1
    }
    
    if [ ${#envs[@]} -eq 0 ]; then
        echo "No environments found"
        return 1
    }
    
    echo "Available environments:"
    local i=1
    for env in "${envs[@]}"; do
        if [ -n "$env" ]; then
            echo "  $i) $env"
            ((i++))
        fi
    done
    return 0
}

# Function to delete ECR repositories
delete_ecr_repositories() {
    local suffix=$1
    local region=$2
    
    echo "Deleting ECR repositories for environment ${suffix}..."
    
    local repos=("flotorch-app" "flotorch-indexing" "flotorch-retriever" "flotorch-evaluation" "flotorch-runtime" "flotorch-costcompute")
    for repo in "${repos[@]}"; do
        local repo_name="${repo}-${suffix}"
        echo "Deleting repository: $repo_name"
        if ! aws ecr delete-repository --repository-name "$repo_name" --region "$region" --force >/dev/null 2>&1; then
            echo "Warning: Failed to delete ECR repository $repo_name (it may not exist)"
        fi
    done
}

# Function to delete CloudFormation stack
delete_cfn_stack() {
    local stack_name=$1
    local region=$2
    
    echo "Deleting CloudFormation stack ${stack_name}..."
    if ! aws cloudformation delete-stack --stack-name "$stack_name" --region "$region"; then
        echo "Error: Failed to initiate stack deletion"
        return 1
    fi
    
    echo "Waiting for stack deletion to complete..."
    if ! aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$region"; then
        echo "Error: Stack deletion failed or timed out"
        return 1
    fi
    
    echo "Stack deletion completed successfully"
    return 0
}

# Function to delete environment configuration
delete_environment_config() {
    local env_name=$1
    local env_file=".envs/${env_name}.json"
    
    if [ -f "$env_file" ]; then
        if ! rm "$env_file"; then
            echo "Warning: Failed to delete environment configuration file"
            return 1
        fi
    fi
    return 0
}

# Main execution
main() {
    # Check if AWS CLI is installed
    if ! command -v aws >/dev/null 2>&1; then
        echo "Error: AWS CLI is not installed"
        exit 1
    }

    # List available environments
    echo "Listing available environments..."
    if ! list_environments; then
        echo "No environments to clean up"
        exit 0
    fi

    # Get list of environments
    local envs=($(ls .envs/*.json 2>/dev/null | xargs -n 1 basename | sed 's/\.json$//'))
    local num_envs=${#envs[@]}

    # Prompt for environment selection
    while true; do
        read -p "Enter the number of the environment to delete (1-${num_envs}) or 'q' to quit: " selection
        
        if [[ "$selection" == "q" ]]; then
            echo "Cleanup cancelled"
            exit 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$num_envs" ]; then
            selected_env="${envs[$((selection-1))]}"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and ${num_envs}"
        fi
    done

    # Confirm deletion
    read -p "Are you sure you want to delete environment '${selected_env}'? This will delete all associated resources. (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled"
        exit 0
    fi

    # Load environment configuration
    echo "Loading environment configuration..."
    load_environment "$selected_env"

    # Delete resources in the following order:
    # 1. ECR Repositories
    echo "Step 1: Deleting ECR repositories..."
    delete_ecr_repositories "$TABLE_SUFFIX" "$REGION"

    # 2. CloudFormation Stack
    echo "Step 2: Deleting CloudFormation stack..."
    if ! delete_cfn_stack "$PROJECT_NAME" "$REGION"; then
        echo "Error: Failed to delete CloudFormation stack"
        exit 1
    fi

    # 3. Environment Configuration
    echo "Step 3: Deleting environment configuration..."
    if ! delete_environment_config "$selected_env"; then
        echo "Warning: Failed to delete environment configuration"
    fi

    echo "Environment '${selected_env}' has been successfully deleted"
}

# Execute main function with error handling
set -e
main
