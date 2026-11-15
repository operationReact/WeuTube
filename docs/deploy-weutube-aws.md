# WeuTube — AWS production deployment (not yet applied)

This repository contains deployment tooling, but **no AWS resources have been created by these commits**. All resources incur charges when an operator explicitly runs the Terraform apply workflow. Always review the Terraform plan and expected recurring costs first.

## Credentials already supplied by the project owner

All three names below are expected to exist in Systems Manager Parameter Store in `ap-south-1`:

- `/weutube/prod/youtube/client-id` — String
- `/weutube/prod/youtube/client-secret` — SecureString
- `/weutube/prod/youtube/token-key-base64` — SecureString, Base64-encoded random 32-byte AES key

Values are never committed, echoed, or copied into GitHub Actions. Production EC2 reads them using its IAM role. The deploy workflow verifies that all three can be decrypted before publishing a build.

## 1. Establish GitHub → AWS OIDC role for Terraform

An IAM role trusted by GitHub Actions for `repo:operationReact/WeuTube:ref:refs/heads/main` is required to provision IAM, EC2, EIP, S3, Cognito, and optional Route53 resources. This **bootstrap role is not created by this repo** because Terraform cannot assume a role that does not yet exist. It should be scoped to the deployment AWS account and configured using your existing GitHub OIDC provider, if one exists there.

Add the IAM role ARN as an **Actions repository secret** called `WEUTUBE_TERRAFORM_ROLE_TO_ASSUME` at:

https://github.com/operationReact/WeuTube/settings/secrets/actions

Do not use a long-lived IAM access key. The optional `github_oidc_provider_arn` Terraform input should be set to the AWS provider ARN for `token.actions.githubusercontent.com`. The Terraform code can then create a **narrower runtime deployment role** for the main branch.

## 2. Establish private remote Terraform state

Before the first plan/apply, create or reuse one **private S3 bucket** in `ap-south-1` with bucket-level public access blocked, encryption enabled, and versioning enabled. The Terraform IAM role must have permissions for state read/write, lock-file create/delete, and normal Terraform provider actions.

The workflow stores state at `weutube/prod/terraform.tfstate`, with S3 native state locking. **Never run production Terraform with ephemeral GitHub Actions local state.**

## 3. Infrastructure plan and explicit apply

Manual workflow:

https://github.com/operationReact/WeuTube/actions/workflows/terraform-api.yml

1. Select **Run workflow**, branch **main**.
2. Set `operation=plan` first, `state_bucket` to your existing state bucket, and optionally `hosted_zone_id` for an existing Route53 public zone.
3. Set `github_oidc_provider_arn` if you want Terraform to create the narrowed GitHub API deploy role.
4. Review the resulting resources and costs.
5. Rerun with `operation=apply` **only after** approving the plan.

The `enable_api=true` setting used by this explicit workflow provisions the API EC2 host (default `t3.medium`), 40 GiB encrypted EBS root volume, Elastic IP, SSM role, HTTPS ingress, private S3 artifacts bucket, Cognito user pool and `weutube-admin` group, and the existing website resources from Terraform. No SSH port is opened. **This is single-node infrastructure, not high availability.**

Terraform outputs:

- `api_instance_id`
- `api_eip`
- `api_artifacts_bucket`
- `cognito_user_pool_id`
- `cognito_client_id`
- `cognito_issuer_uri`
- `github_api_deploy_role_arn` (if the OIDC provider ARN was configured)

If the AWS account has no default VPC/subnet, the initial Terraform plan must be adapted before applying.

## 4. DNS, secure deployment and YouTube redirect URL

Configure an **A record**: `api.weutube.com` → Terraform `api_eip`. When an existing Route53 hosted zone ID was supplied to Terraform, it creates this record; otherwise configure it at the authoritative external DNS host.

Only **after the DNS and HTTPS API endpoint are operational**, add exactly this under Google Auth Platform → Clients → WeuTube Backend → Authorized redirect URIs:

`https://api.weutube.com/api/admin/youtube/callback`

Google OAuth redirect URIs must match exactly; do not add speculative or HTTP URLs.

Store the `github_api_deploy_role_arn` output in the Actions repository secret `WEUTUBE_AWS_ROLE_TO_ASSUME`. Then run:

https://github.com/operationReact/WeuTube/actions/workflows/deploy-api.yml

Select branch `main` and provide `api_instance_id`, `api_artifacts_bucket`, `cognito_issuer_uri`, and `api_domain=api.weutube.com`.

This manual workflow verifies SSM reads, runs Maven tests and packages the Spring Boot JAR, uploads an immutable release to private S3, uses SSM Run Command to build/start Java + PostgreSQL + Caddy containers on EC2, and checks `https://api.weutube.com/actuator/health`.

The EC2 deployment creates a stable random local PostgreSQL password on first deployment, never changes it during redeploy, and installs an automatic 02:15 UTC encrypted S3 database backup (90-day lifecycle). Backups are **not** yet restore-tested. The instance root volume is not automatically deleted on termination, which can leave billable detached EBS volumes.

## 5. Provision a real administrator and connect YouTube

Terraform creates `weutube-admin`, but **does not create or enroll a human administrator**. Create a verified admin user in the new Cognito pool, add that user to `weutube-admin`, and use genuine Cognito authentication to obtain a JWT. The existing Flutter Admin Demo switch is **not authentication**.

With an admin JWT:

- `POST /api/admin/youtube/authorization` — starts the consent flow and returns a URL.
- Open the URL with your YouTube channel's Google account.
- Google redirects to the HTTPS callback, which verifies channel identity and encrypts the refresh token in Postgres.
- `GET /api/admin/youtube/channels` — shows stored connected channel metadata, not secrets.

The production Flutter admin OAuth Connect UI is still not wired to authenticated backend calls. No live channel has yet been connected. Google OAuth testing-mode refresh tokens may be limited to seven days. Actual private uploads, publish operations, revenue reports and payouts are separate unfinished features.

## Operational cautions

- Do not publish private videos without explicit owner consent and YouTube policy compliance.
- A successful health endpoint does **not** prove that Google OAuth completed or that the creator wallet/publishing works.
- Database stored on one EC2 host is cost-conscious but has a single point of failure. Review and restore-test backups, monitor disk space, consider RDS before onboarding real creators.
- Caddy requires public DNS to resolve correctly and ports 80/443 to reach the instance for trusted HTTPS certificates.
- IAM policy for default `aws/ssm` encryption is different from customer-managed KMS keys. If using a customer-managed KMS key, explicitly grant `kms:Decrypt` to the GitHub preflight and EC2 runtime roles.
