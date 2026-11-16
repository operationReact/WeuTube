# WeuTube backend API contract — 16 November 2026

This document records the implemented source code, not a claim of successful production deployment.

## Authentication

Cognito configured via Terraform user pool + public app client. Spring verifies Cognito JWT access tokens for protected endpoints. The app client must allow `USER_PASSWORD_AUTH`; apply the Terraform change before calling the new sign-in route. Tokens must be kept in the platform secure storage; never log refresh tokens or commit credentials.

Public endpoints (under `/api/public/auth`):
- `POST /sign-up` — `{email,password,displayName}`; sends Cognito email confirmation.
- `POST /confirm` — `{email,code}`.
- `POST /resend-code` — `{email}`.
- `POST /sign-in` — `{email,password}`; returns Cognito access, ID and refresh tokens or an MFA challenge.
- `POST /confirm-mfa` — `{email,session,challenge,code}`; supports software-token or SMS MFA.
- `POST /refresh` — `{refreshToken}`.
- `POST /forgot-password` — `{email}`.
- `POST /reset-password` — `{email,code,newPassword}`.

Protected endpoint: `POST /api/auth/sign-out` with Bearer access token. Authentication responses disable HTTP caching.

## Creator

Every creator endpoint requires a verified Bearer **access token**. Identity comes from the token subject, never a client-provided creator ID.

- `GET /api/creator/account`
- `PATCH /api/creator/account` — `{displayName}`
- `GET /api/creator/dashboard` — real DB status counts; YouTube subscriber/view fields null until connected
- `POST /api/creator/videos/drafts` — `{title}`
- `PATCH /api/creator/videos/drafts/{id}` — `{title}`; only owner and DRAFT
- `DELETE /api/creator/videos/drafts/{id}` — only owner and DRAFT
- `GET /api/creator/videos`
- `GET /api/creator/videos/{id}` — owner-only details and review reason
- `POST /api/creator/videos/{id}/private-upload` — authenticated multipart `file` plus `channelId`; an admin must have granted creator access to the linked channel. Maximum 256 MiB. Upload remains PRIVATE until review, and success creates PRIVATE_REVIEW.
- `GET /api/creator/analytics` — real YouTube Data API views, likes and comments for up to 500 latest published videos. Marked partial when anything is missing; no fabricated RPM/revenue.
- `GET /api/creator/wallet` — INR verified ledger, reserved payouts, available minor units
- `GET /api/creator/wallet/withdrawals` — latest 100 owner requests
- `POST /api/creator/wallet/withdrawals` — `{requestKey:uuid,amountMinor:integer}`; verified funds only, client-idempotent.
- `GET /api/creator/notifications` — real review and payout events, latest 50

Older prototype `/api/videos` and `/api/wallet/withdrawals` are not substitutes for these creator-specific endpoints.

## Admin

Admin endpoints require `cognito:groups` containing `weutube-admin`; a UI mode switch does not grant the role.

- `POST /api/admin/youtube/authorization` — Google owner connection URL and 10-minute state
- `GET /api/admin/youtube/callback` — Google redirect, consumes state once and saves encrypted verified channel credentials
- `GET /api/admin/youtube/channels` — linked channel metadata, never tokens
- `POST /api/admin/channels/{channelId}/creators` — `{creatorSubject}` grants permission
- `DELETE /api/admin/channels/{channelId}/creators/{creatorSubject}` — revoke
- `GET /api/admin/reviews/queue?page=0`
- `POST /api/admin/reviews/{id}/decision` — `{decision:"APPROVED"|"REJECTED",reason}`, reason required for rejection, atomic state transition and audit
- `POST /api/admin/videos/{id}/publish` — approved video only, validates connected channel and private visibility before changing to public using YouTube Data API
- `POST /api/admin/videos/{id}/reconcile-publish` — resolves uncertain publishing by verifying actual public visibility
- `GET /api/admin/payouts/queue?page=0`
- `POST /api/admin/payouts/{id}/decision` — approve/reject with audit, **does not send money**

## Video lifecycle

`DRAFT → UPLOADING → PRIVATE_REVIEW → APPROVED → PUBLISHING → PUBLISHED`. Admin may reject a private-review video. UPLOADING and PUBLISHING are deliberately persistent when the provider outcome is uncertain: do not blindly retry external operations and create duplicates or accidentally publish twice. PUBLISHING has a reconciliation API; UPLOADING requires an operational recovery process.

## Google scope update

In addition to `youtube.upload` and `youtube.readonly`, publishing requires `youtube.force-ssl` for `videos.update`. **Previously connected Google accounts need to reauthorize after deployment.** Review Google OAuth verification and channel ownership rules before production use.

## Production release prerequisites

1. Apply and review the updated Cognito Terraform app-client auth flow. It is committed, not applied by a code commit.
2. Run Maven CI; apply Flyway V5–V8 in PostgreSQL through a controlled deployment. Back up the DB and validate rollback strategy beforehand.
3. Deploy the latest API image and update the environment `WEUTUBE_COGNITO_CLIENT_ID`, `WEUTUBE_COGNITO_REGION`, the issuer and existing encrypted Google settings.
4. Connect the owner's YouTube channel under the new scopes; create or sign in a real creator; admin grants that creator the channel; upload a small original private video; moderate and publish deliberately.
5. Verify Android and web clients send real Cognito access tokens and that all secure API errors render appropriately; frontend prototype is not yet wired for all flows.
6. Implement external verified YouTube monetary revenue import and payment-provider reconciliation before enabling actual payouts. A YouTube view count **does not** imply creator earnings.
7. Verify real HTTPS, CORS, YouTube API quotas, load, interruption recovery and original artwork/icon. The current 256 MiB synchronous upload flow is not a scalable solution for very large videos.
8. iOS app device build and App Store signing require macOS CI and Apple developer access.

## Status

Java CI establishes compilation and unit tests; it does **not** prove actual Cognito sign-up, Google upload, monetary reconciliation, database migration, production rollout or user journey end-to-end. Mark these as separately verified only after running real authenticated smoke tests.
