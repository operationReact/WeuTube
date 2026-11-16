# WeuTube Create-to-Upload single flow — November 16, 2026

## User problem
Create used a large promotional card that sent signed-in users to a separate legacy "Upload Video" route. The legacy route displayed a form even if channel authorization returned HTTP 403, with a generic "Access denied" banner. Bottom navigation incorrectly highlighted You instead of Create. The client artificially capped files at 20 MB while the Spring Boot endpoint and Google uploader allowed 256 MB.

## Root causes confirmed in code
- `SocialHub.create()` displayed "Open Upload Studio", while `WeuTubeIntegratedApp.createFromSocial()` routed to `Upload Video`.
- `navigate('Upload Video')` called `/api/creator/channels`, reported 403 through the general banner, and still rendered the form with an empty channel list.
- `CreatorGrantedChannelController.mine()` returns only channels both admin-granted to the signed-in creator and OAuth-connected. The server deliberately forbids arbitrary creator-chosen channels.
- `AdminChannelGrantController` is admin-only. There is no implemented creator self-service OAuth channel authorization; do not pretend there is.
- Flutter previously loaded the entire video into Uint8List using `withData:true`, capped at 20 MB. The API's multipart limit is 256 MiB, with provider-side private upload.

## Implementation
1. Make the **Create tab** the sole upload entry point. Old `Upload Video` navigation targets redirect to `Create`, preserving the active bottom tab. No oversized promotional hero.
2. Use an isolated `WeuTubeUploadComposer` for signed-in and signed-out users. Signed-out users see a direct sign-in CTA and return to Create on successful login.
3. Before revealing file selection or form controls, retrieve `/api/creator/channels`. Handle loading, no-grant, 401, 403 and transient API errors with a specific explanation and Check Again/View My Videos actions.
4. Only when a real grant exists show the compact file-first upload form. Match title (<=100 characters), description (<=2,000) and backend-supported category validation. Show channel selection from authorized channels only.
5. Pick video with `withReadStream:true` and send via streaming `MultipartFile` up to the backend's 256 MiB limit, without full in-memory buffering in the Flutter client. Show **device-to-server** transfer percent, not an invented YouTube processing percent.
6. Submit one private draft, update metadata, then upload. If the upload response becomes uncertain, block automatic retries and direct creators to My Videos to avoid duplicate YouTube uploads.
7. Hide bottom navigation while the keyboard is open to prevent covered submit controls. Keep product navy/coral branding and standard app header.

## Security and product restrictions
- Never grant channel upload rights client-side or expose an admin credential. The server remains the authority for channel ownership and OAuth state.
- No direct "Connect YouTube" self-service button is shown until backend authorization is built with OAuth security checks.
- `256 MB` is a **backend limit**, not a promise of successful uploads on weak networks. This protocol is not resumable from the mobile client; server Google upload uses resumable initiation but an interrupted client submission can require reconciliation.
- Avoid duplicate uploads: once a private-upload request begins, the client asks the user to check My Videos after an uncertain result.
- If a creator sees 403, a server identity or grants investigation may still be required. UI changes alone do not assert that the underlying permission has changed.

## Verification
- Flutter analyze, unit/widget tests at narrow widths, web release build, debug APK build.
- Tests confirm correct Create tab route, no misleading intermediate promotional card, no file form when grant is absent/denied, and available form after a valid grant.
- Merge only after green checks. Production deploy verifies HTTPS website, API health and hosted Android APK URL; real upload still needs end-to-end authorized channel testing.

## Remaining work before general launch
- Self-service YouTube creator authorization or a clearer admin grant-management process.
- Server-side resumable upload reconciliation, large file performance testing and uploads over slow networks.
- Real Android/browser device validation with a channel-granted test creator.
