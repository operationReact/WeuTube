# Production deployments must use an encrypted, shared S3 state bucket with
# native lock files. Supply bucket/key/region at terraform init time; do not
# commit a bucket name or state file to the public repository.
terraform {
  backend "s3" {}
}
