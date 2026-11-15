# WeuTube AWS production bootstrap — one-time action

The WeuTube AWS GitHub OIDC authentication has been **verified** in GitHub Actions run #43743370717 against account `098859530205`.

Read-only AWS prerequisite run #43743656363 then found:
- GitHub role `weutube-prod-terraform-github` cannot access any of the three YouTube SSM parameters.
- It cannot query EC2 VPCs.
- The requested Terraform S3 bucket is either absent or cannot be accessed.

This is expected when the new OIDC role was created without IAM permission policies. Do not run Terraform apply until these are fixed.

## One AWS Console action: create the bootstrap CloudFormation stack

1. Download the JSON template:
   https://github.com/operationReact/WeuTube/blob/main/infra/bootstrap/weutube-terraform-bootstrap.json
   (Use **Raw → Download**. This is public infrastructure code only, no secrets.)
2. Sign in to **AWS account 098859530205**, region **Mumbai (ap-south-1)**.
3. Open https://ap-south-1.console.aws.amazon.com/cloudformation/home?region=ap-south-1#/stacks/create
4. Choose **With new resources (standard)** → **Choose an existing template** → **Upload a template file** → upload the downloaded JSON file.
5. Stack name: `weutube-terraform-bootstrap`.
6. Keep `ExistingGithubRoleName=weutube-prod-terraform-github`. If you have **not** already created the private bucket, leave `CreateStateBucket=true`. If it already exists in your AWS account with private access, SSE encryption and versioning, set `false` to attach only the role policy.
7. Review the permissions carefully. This is a powerful temporary provisioning role: the policy grants scoped S3 and IAM resource management, and broad EC2, Cognito and CloudFront provisioning rights required by Terraform. **Only deploy this template if you approve that access.** Restrict the role's trust to the verified immutable WeuTube GitHub OIDC subject on `main`.
8. Acknowledge **CAPABILITY_NAMED_IAM** and click **Submit**. Wait for `CREATE_COMPLETE`.

The stack creates the S3 bucket `weutube-prod-tfstate-098859530205` (unless `CreateStateBucket=false`), blocks public access, enables encryption and versioning, and attaches an inline provisioning policy to the **already-existing** GitHub IAM role. It does not create EC2/Cognito or deploy the app.

**Do not delete this CloudFormation stack while Terraform still depends on its IAM policy and state bucket.** The bucket has `DeletionPolicy=Retain`, but removing the policy would break future Terraform operations. Review costs/permissions before enabling production services.

## Verify AWS prerequisites

Run https://github.com/operationReact/WeuTube/actions/workflows/aws-preflight.yml on `main`.

The workflow makes only read calls, verifies account, checks that S3 state bucket is accessible, tests decryption of the 3 existing SSM parameters **without printing their values**, and checks EC2 discovery permissions.

The three parameter names must match:

- `/weutube/prod/youtube/client-id`
- `/weutube/prod/youtube/client-secret`
- `/weutube/prod/youtube/token-key-base64`

If you used a customer-managed KMS key for SecureString, also grant the role `kms:Decrypt` on that specific key. The CloudFormation template assumes the default AWS SSM key.

## Terraform plan, review, apply

Open https://github.com/operationReact/WeuTube/actions/workflows/terraform-api.yml

- Select `main`, `operation=plan`.
- State bucket defaults to `weutube-prod-tfstate-098859530205`.
- Existing GitHub OIDC provider ARN defaults to `arn:aws:iam::098859530205:oidc-provider/token.actions.githubusercontent.com`.
- Leave `hosted_zone_id` empty unless you have an **existing Route53 hosted zone** and have explicitly granted DNS permissions to the deployment role.

The workflow is configured to **only** run Terraform apply when `operation=apply` is explicitly selected. Review the plan first; EC2 and other AWS resources cost money.

After apply you will get:

- `api_instance_id`
- `api_eip`
- `api_artifacts_bucket`
- `cognito_issuer_uri`
- `github_api_deploy_role_arn`

Copy the **deploy role ARN** output (different from the Terraform role ARN) to the GitHub Actions repository secret `WEUTUBE_AWS_ROLE_TO_ASSUME`, then configure DNS and run https://github.com/operationReact/WeuTube/actions/workflows/deploy-api.yml.

**Reminder:** this process has not yet been applied to AWS. No live YouTube channel can be connected until HTTPS, Cognito admin authentication, exact Google OAuth redirect URI and API deployment are verified.
