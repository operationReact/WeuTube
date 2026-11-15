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
