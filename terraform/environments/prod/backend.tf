terraform {
  backend "s3" {
    # Configuration will be provided via command line during terraform init
    # -backend-config="bucket=..."
    # -backend-config="key=..."
    # -backend-config="region=..."
    # -backend-config="dynamodb_table=..."
  }
}