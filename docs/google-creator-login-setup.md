# WeuTube: Google user sign-in (separate from YouTube channel access)

## What is implemented
- Flutter's **Continue with Google** uses the existing Cognito user pool through
  the Cognito Hosted UI authorization-code flow with PKCE (S256), a fresh CSRF
  state and the system browser. The browser returns an authorization code, not
  access tokens in the URL.
- A successful exchange produces normal Cognito JWTs, so the existing
  Spring Security creator APIs and account session checks continue to work.
- The existing email/password, MFA, registration and password-reset routes remain.
- The approved `assets/brand/weutube-logo.svg` is unchanged. Logo animation
  uses Flutter depth layers around that original SVG; it does not modify the art.
- `GET /api/public/auth/google-config` is public, cache-disabled,
  and contains only public IdP discovery metadata.

## Required administrator setup before live Google sign-in

**Do not reuse** `/weutube/prod/youtube/client-id` or its secret:
those are for administering a YouTube publishing channel, not for logging
ordinary WeuTube viewers into Cognito.

1. In Google Cloud Console configure a separate **Web OAuth client** for
   Cognito federation; add this authorized redirect URI:
   `https://weutube-prod-login-098859530205.auth.ap-south-1.amazoncognito.com/oauth2/idpresponse`
2. Complete the Google OAuth consent settings, app verification, test users
   (if in testing), and required authorized domain settings.
3. Store its client ID and client secret as AWS SSM **SecureString** values:
   `/weutube/prod/google-login/client-id` and
   `/weutube/prod/google-login/client-secret`.
4. The `WeuTube - activate Google sign-in when credentials are available`
   GitHub Actions workflow checks whether both SSM SecureStrings are accessible.
   When both are present, it prepares a Terraform plan with
   `enable_google_login=true`, **rejects any unrelated managed infrastructure
   changes**, and applies only the Cognito Google IdP, login domain, and
   existing app-client configuration. This uses the existing encrypted,
   locked production Terraform state and the existing GitHub OIDC role.
   If credentials are absent or inaccessible, it makes **no production
   changes** and prints only a safe non-secret readiness summary.
5. On a successful restricted apply, the workflow dispatches
   `deploy-api.yml`, which sets
   `WEUTUBE_GOOGLE_LOGIN_ENABLED` and the Cognito login domain on the
   Spring Boot server. It then verifies the public discovery endpoint:
   `https://api.weutube.com/api/public/auth/google-config`.
6. Real Google single-tap sign-in still requires an authorized Google
   OAuth consent screen and a permitted test/production Google account.
   Check Google Cloud Console configuration and complete the **on-device**
   round trip before advertising it as live. Only a real account selection
   can prove provider consent and the code-to-token exchange.

### Exact Google Console configuration
- OAuth application type: **Web application** for Cognito's Google IdP.
- Authorized redirect URI:
  `https://weutube-prod-login-098859530205.auth.ap-south-1.amazoncognito.com/oauth2/idpresponse`
- The Google Cloud OAuth consent screen must contain the correct support
  email, app identity, authorized domains and publishing/test-user status.
- Create SSM values in **ap-south-1**, as type **SecureString**. Never paste
  the Google client secret into GitHub issues, chat logs, a Flutter build,
  Terraform variable files or public endpoints.
- The workflow can be rerun from
  `Actions > WeuTube - activate Google sign-in when credentials are available > Run workflow`.

### Safety
- The separate YouTube publishing-channel OAuth configuration does not
  satisfy Google **viewer/creator login** requirements.
- Google IdP client secret will be in the encrypted Terraform state,
  as required by the Cognito identity-provider resource; restrict
  Terraform state read permissions.
- Google and email/password accounts using the same email may be distinct
  Cognito identities; **never silently merge accounts based on an
  unverified email address**. Use an explicit identity-linking process
  if existing password accounts need to be joined.

## Callback settings
- Android and iOS: `weutube://auth-callback`, registered by
  `tool/configure_google_auth.py` after `flutter create`.
- Web: `https://weutube.com/auth.html`, handled by the same-origin popup
  callback. The static page avoids keeping the authorization code in the
  browser address bar.
- Allowed callback URLs are configured on the Cognito app client by Terraform.
- Client secret is never sent to mobile/web. Do not store password or tokens
  in a file, log, query parameter, or insecure preferences.

## Acceptance checks
1. Run Flutter analyze, widget and client authentication tests; backend Maven,
   Terraform validation and production deployment checks.
2. On Android/web: Google button opens the Google account selector; select an
   authorized Google account; Cognito exchanges the PKCE code and returns its
   user-pool JWT. `/api/creator/session` should return the signed-in user.
3. Cancel the popup or change the state: the app must not create a session.
4. Test email/password and MFA, password reset, account creation, anonymous
   exploration and a 320 dp screen.
5. Ensure animation honors reduced-motion settings and stops after the intro.
6. A real YouTube upload is an **independent** permission/OAuth check, not a
   consequence of successful Google user login.
