# WeuTube

Frontend-first implementation for the WeuTube creator platform.

## Apps
- `apps/web/index.html` — responsive interactive web UI prototype (sample data; no backend).
- `apps/flutter/` — shared Flutter Android, iOS and web application UI.
- `assets/brand/` — approved navy and coral brand assets.

Colors: navy `#0B1F4D`, coral `#FF4B3A`, background `#F8F9FC`.

## Important
The Flutter sign-in, upload, analytics, earnings and payout screens are UI-only demonstrations. The Spring Boot backend now has draft/review APIs and server-side Google OAuth connection, encrypted channel credentials and token refresh; these are not deployed or verified against a live Google account. The demo Admin toggle is not secure authentication. Do not use the prototype to collect credentials or process payments. No live YouTube video upload/publishing is enabled. See `docs/youtube-channel-connection.md`.

Flutter SDK is required to generate native platform scaffolding and build Android/iOS releases. iOS signing and App Store submission require Apple developer configuration.

## Production deployment status

Infrastructure-as-code, a production Java/DB/Caddy container stack, Cognito resources,
private S3 artifacts, encrypted daily backups and manual OIDC-based GitHub Actions
plan/apply/deploy workflows are now **committed but not provisioned**. The Terraform
production API host is disabled by default until an explicit manual apply.

Deployment runbook: [docs/deploy-weutube-aws.md](docs/deploy-weutube-aws.md).

Before connecting a live YouTube channel, an AWS Terraform role, private remote state
bucket, production DNS/HTTPS and a real Cognito administrator are required. Flutter
still uses prototype-only sign-in and does not yet invoke the connection API.
