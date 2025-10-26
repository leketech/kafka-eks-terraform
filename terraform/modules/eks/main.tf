module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    eks_nodes = {
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      instance_types = var.node_group_instance_types
      capacity_type  = var.node_group_capacity_type
      
      # Add bootstrap configuration to ensure nodes can join the cluster
      bootstrap_extra_args = "--enable-docker-bridge true"
      
      # Attach additional IAM policies for EBS CSI driver
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      
      # Add tags to ensure proper identification
      tags = {
        Name = "${var.cluster_name}-node-group"
      }
    }
  }

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Enable the EBS CSI driver addon for persistent volume provisioning
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent                = true
      preserve                   = true
      resolve_conflicts_on_create = "NONE"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
  
  # Add node security group tags
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}