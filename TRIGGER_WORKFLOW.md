# Workflow Triggering Guide

## Workflow Sequence

The GitHub Actions workflows are designed to run in a specific sequence:

1. **Terraform Plan** ([.github/workflows/terraform-plan.yml](.github/workflows/terraform-plan.yml))
2. **Terraform Apply** ([.github/workflows/terraform-apply.yml))
3. **Deploy Kafka** ([.github/workflows/kafka-deploy.yml))

## How Workflows are Triggered

### 1. Terraform Plan Workflow
- **Automatic Trigger**: Creates a plan when pull requests are opened or updated
- **Manual Trigger**: Can be run manually using the "workflow_dispatch" event
- **Path-based Trigger**: Only runs when terraform files or workflow files are changed

### 2. Terraform Apply Workflow
- **Automatic Trigger**: Runs when changes are pushed to the main branch
- **Manual Trigger**: Can be run manually using the "workflow_dispatch" event
- **Prerequisite**: Should only be run after a successful plan review and merge

### 3. Deploy Kafka Workflow
- **Automatic Trigger**: Runs automatically when the Terraform Apply workflow completes successfully
- **Manual Trigger**: Can be run manually using the "workflow_dispatch" event
- **Conditional**: Only runs if the Terraform Apply workflow succeeds

## Triggering Workflows Manually

### Using GitHub UI
1. Go to the repository's "Actions" tab
2. Select the workflow you want to run from the left sidebar
3. Click the "Run workflow" button
4. Select the branch (usually main)
5. Click "Run workflow"

### Using GitHub CLI
```bash
# Trigger Terraform Plan workflow
gh workflow run "Terraform Plan" --repo leketech/kafka-eks-terraform

# Trigger Terraform Apply workflow
gh workflow run "Terraform Apply" --repo leketech/kafka-eks-terraform

# Trigger Deploy Kafka workflow
gh workflow run "Deploy Kafka" --repo leketech/kafka-eks-terraform
```

## Proper Workflow Execution Sequence

To deploy the entire infrastructure correctly, follow this sequence:

1. **Create a feature branch** for your changes
2. **Make Terraform changes** in your feature branch
3. **Create a Pull Request** to merge your changes to main
4. **Terraform Plan workflow** will automatically run and show the planned changes
5. **Review the plan** in the PR comments
6. **Merge the Pull Request** to main branch
7. **Terraform Apply workflow** will automatically run and apply the changes
8. **Deploy Kafka workflow** will automatically run after successful apply

## Troubleshooting Workflow Triggers

### If Deploy Workflow Doesn't Trigger
1. Check that the Terraform Apply workflow completed successfully
2. Verify the workflow name matches exactly ("Terraform Apply")
3. Check the workflow run conclusion is "success"
4. Manually trigger the Deploy Kafka workflow if needed

### If Apply Workflow Doesn't Trigger
1. Ensure changes were pushed to the main branch
2. Verify the path filters include your changed files
3. Manually trigger the workflow if needed

## Best Practices

1. **Always review Terraform plans** before merging to main
2. **Don't skip the plan step** - it's crucial for understanding changes
3. **Monitor workflow execution** in the Actions tab
4. **Use manual triggers** for testing and debugging
5. **Check logs** if workflows fail to identify issues

The workflows are designed to be robust and handle most scenarios automatically, but manual triggering is available for special cases or troubleshooting.