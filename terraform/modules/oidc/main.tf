# Import existing OIDC provider or create new one if it doesn't exist
data "aws_iam_openid_connect_provider" "existing_github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = length(data.aws_iam_openid_connect_provider.existing_github.id) > 0 ? 0 : 1

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# Reference existing OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Create IAM role for GitHub Actions with a unique name
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsKafkaDeployRole-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Generate a random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Attach permissions required by Terraform to deploy EKS + networking + state backend
# Updated to use the correct bucket name
resource "aws_iam_role_policy" "github_actions_permissions" {
  name = "terraform-kafka-permissions"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # EKS cluster and nodegroup management
      {
        Effect = "Allow",
        Action = [
          "eks:*"
        ],
        Resource = "*"
      },
      # EC2 permissions (VPC, subnets, security groups, instances, etc.)
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ],
        Resource = "*"
      },
      # Load Balancer permissions (for EKS services)
      {
        Effect = "Allow",
        Action = [
          "elasticloadbalancing:*"
        ],
        Resource = "*"
      },
      # IAM permissions (for creating roles, policies, IRSA, etc.)
      {
        Effect = "Allow",
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRoles",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ],
        Resource = "*"
      },
      # Auto Scaling (for EKS node groups)
      {
        Effect = "Allow",
        Action = [
          "autoscaling:*"
        ],
        Resource = "*"
      },
      # Access Terraform state in S3 - More specific permissions
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:HeadBucket",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      # DynamoDB state locking
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ],
        Resource = "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}"
      },
      # CloudWatch Logs
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      # Additional CloudWatch Logs permissions for tagging (required by EKS module)
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:TagResource"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/eks/*"
      },
      # CloudWatch Metrics
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      },
      # KMS (for encryption)
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ],
        Resource = "*"
      },
      # Additional KMS permissions required by EKS module (for tagging keys)
      {
        Effect = "Allow",
        Action = [
          "kms:CreateKey",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      # STS (for assuming roles and getting identity)
      {
        Effect = "Allow",
        Action = [
          "sts:GetCallerIdentity",
          "sts:AssumeRoleWithWebIdentity"
        ],
        Resource = "*"
      }
    ]
  })
}

# Additional policy for EKS cluster access
resource "aws_iam_role_policy_attachment" "github_actions_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.github_actions.name
}

# Additional policy for EKS worker nodes
resource "aws_iam_role_policy_attachment" "github_actions_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.github_actions.name
}

# Additional policy for EKS CNI
resource "aws_iam_role_policy_attachment" "github_actions_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.github_actions.name
}

# Additional policy for container registry
resource "aws_iam_role_policy_attachment" "github_actions_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.github_actions.name
}