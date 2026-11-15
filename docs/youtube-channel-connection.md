# WeuTube — Connect a YouTube channel (production runbook)

## Implemented

- Admin-only `POST /api/admin/youtube/authorization` creates a random, 10-minute OAuth state and a Google consent URL.
- Google's `GET /api/admin/youtube/callback` verifies and atomically consumes that state, exchanges the authorization code server-side and calls YouTube `channels.list?mine=true`.
- The channel ID, title and AES-256-GCM encrypted **refresh token** are persisted in PostgreSQL. No OAuth token is sent to the browser.
- Admin-only `GET /api/admin/youtube/channels` returns connected channel ID/name/timestamps.
- Google authorization is deliberately rejected if the secret or encryption key is not configured.

## Runtime configuration

Google Cloud project: `weutube`. Region: `ap-south-1`.

Existing SSM parameters (provided by project owner):

- `/weutube/prod/youtube/client-id` (String)
- `/weutube/prod/youtube/client-secret` (SecureString)

**Required additional parameter, not created by this repository:**

- `/weutube/prod/youtube/token-key-base64` (SecureString): randomly generated **32-byte** AES key encoded as Base64. Generate once and back it up securely. Losing or rotating it without re-encrypting stored tokens makes existing credentials unrecoverable.

Example, **PowerShell with AWS CLI already authenticated to the correct AWS account**:

```powershell
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$key = [Convert]::ToBase64String($bytes)
aws ssm put-parameter --name /weutube/prod/youtube/token-key-base64 --type SecureString --value $key --region ap-south-1 --no-overwrite
Remove-Variable key, bytes
```

Do not paste the key into chats, source control, CI logs or Terraform variables. The above CLI writes it to SSM without checking plaintext into the repository. Confirm the AWS account before running.

To enable direct SSM retrieval in the deployed Spring Boot service:

```
WEUTUBE_YOUTUBE_SSM_ENABLED=true
WEUTUBE_YOUTUBE_SSM_REGION=ap-south-1
WEUTUBE_YOUTUBE_REDIRECT_URI=https://api.weutube.com/api/admin/youtube/callback
```

The redirect URI shown is a **proposed deployment target, not yet a running URL**. Once the API domain is deployed with HTTPS, register the exact deployed URI under Google Cloud > Google Auth Platform > Clients > WeuTube Backend > Authorized redirect URIs. An exact match is required.

The backend IAM role needs `ssm:GetParameter` for all three parameter ARNs. Terraform `youtube_ssm_iam.tf` provisions a least-privilege policy, but **does not attach it**; deployment must attach it to the workload role. If SecureStrings use a customer-managed KMS key, grant the role appropriate `kms:Decrypt` on that key as well. The AWS SDK obtains temporary credentials from the normal role provider chain; no static AWS keys are required.

For local tests, leave `WEUTUBE_YOUTUBE_SSM_ENABLED=false` and use environment variables `WEUTUBE_YOUTUBE_CLIENT_ID`, `WEUTUBE_YOUTUBE_CLIENT_SECRET`, `WEUTUBE_YOUTUBE_TOKEN_KEY_BASE64` and `WEUTUBE_YOUTUBE_REDIRECT_URI`.

## Connection flow after deployment

1. Create/configure AWS backend compute, Postgres (Flyway migrations V1–V4), HTTPS API domain, Cognito issuer, and admin group `weutube-admin`.
2. Add the exact callback redirect URI to Google's existing Web application OAuth client.
3. Authenticate as a real Cognito administrator; never use the demo Flutter Admin toggle as authentication.
4. Call `POST /api/admin/youtube/authorization` with the admin's Cognito JWT. The response contains a Google authorization URL.
5. Open that URL in a browser while signed into the Google account that owns the YouTube channel, consent to the two requested scopes, and check the JSON callback confirmation.
6. Call `GET /api/admin/youtube/channels` with the same administrator authorization to verify the channel ID and name.

The callback uses a one-time OAuth state; on failures, **restart authorization**. If the Google OAuth app is in Testing, refresh tokens for YouTube scopes may expire after seven days. Public production use may require OAuth verification and compliance with YouTube upload policies.

## Not done

- Production deployment, live OAuth end-to-end verification, admin web authentication, Flutter Connect button integration.
- Token refresh, private video uploads, publishing, earnings or payouts.
- KMS envelope-encryption/key rotation. Current AES key is supplied from SecureString and versioned as `env:v1` in the database.

Do not claim channel publishing is operational merely because the connection callback succeeds.
