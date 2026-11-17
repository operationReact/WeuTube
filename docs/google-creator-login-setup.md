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
4. After reviewing Terraform, run the existing **production Terraform apply**
   with `-var='enable_google_login=true'`. The default is deliberately
   `false` so an unconfigured login integration cannot break deployments.
   The Terraform operator must have decrypt access to those two parameters.
   Google credentials become sensitive Terraform state values; restrict and
   encrypt the existing production state and never print plan/state contents.
5. Deploy the updated API and web build through the existing production
   deployment workflow. The CI deployment reads Terraform outputs
   `google_login_enabled` and `cognito_login_domain`, and passes them
   through private EC2 app configuration. Check the public config:
   `https://api.weutube.com/api/public/auth/google-config`.
   Until it returns `enabled: true`, **Google sign-in is not live**.

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
