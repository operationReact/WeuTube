# WeuTube Terraform — initial web infrastructure

This is a **partial**, intentionally low-risk Terraform module for a private S3 static web origin and CloudFront distribution. It does not yet provision API compute, PostgreSQL, Cognito, WAF, certificates, Route53, observability, backups, or deployment pipelines.

## Before running
- Confirm the correct AWS account and region (`ap-south-1`).
- Configure remote Terraform state with locking, access controls and encryption.
- Review cost and security impact of a plan.
- Do not apply from a developer laptop without confirming account identity.
- Domain DNS remains with the registrar until certificate validation and distribution aliases are configured.
- Never commit credentials or state files.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

**No AWS resources have been provisioned by this commit.**
