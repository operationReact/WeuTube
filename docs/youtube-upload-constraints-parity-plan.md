# WeuTube — YouTube upload constraints parity: engineering plan (2026-11-16)

## Verified platform rules (official sources)
- **Max size/length:** YouTube allows **256 GB or 12 hours, whichever is less**: https://support.google.com/youtube/answer/71673
- **Long videos:** Channels without long-upload privileges are limited to **15 minutes**. YouTube's channel API returns `status.longUploadsStatus` as `allowed`, `eligible`, or `disallowed` when authorized: https://developers.google.com/youtube/data/reference/rest/v3/channels
- **File formats:** MP4, MOV, MPEG1/2/4, MPG, AVI, WMV, MPEG-PS, FLV, 3GPP, WebM; DNxHR, ProRes, CineForm and HEVC are typically codecs inside supported containers: https://support.google.com/youtube/troubleshooter/2888402
- **Metadata:** title up to 100 Unicode characters, no `<`/`>`; description up to **5,000 UTF-8 bytes**, no angle brackets: https://developers.google.com/youtube/data/reference/rest/v3/videos ; https://developers.google.com/youtube/terms/required-minimum-functionality
- **Privacy:** third-party YouTube upload clients must permit user choice of **public/private/unlisted**. The current WeuTube admin-review model temporarily uploads private, and forces public on admin publish; **this is not full API minimum-functionality parity**.
- **Audience:** YouTube asks whether videos are made for kids, plus applicable age restrictions; WeuTube must support these before claiming complete parity: https://support.google.com/youtube/answer/57407
- **Shorts:** Square/vertical videos up to three minutes can qualify; should not be conflated with 12-hour standard uploads: https://support.google.com/youtube/answer/15424877
- **Resumable protocol:** https://developers.google.com/youtube/data/guides/using_resumable_upload_protocol

## Existing WeuTube architectural gap
Current path: Flutter mobile/web -> one authenticated multipart HTTP request -> Spring MVC multipart temp file on EC2 -> synchronous Google resumable upload with one PUT -> mark PRIVATE_REVIEW. Cap is **256 MiB** in three places: Flutter, Spring multipart properties and `GooglePrivateUploadService.MAX_UPLOAD_BYTES`. The Google upload session is initiated but Google-resume/reconcile logic is NOT implemented for client network interruption. Changing the cap to 256 GB without changing the architecture would invite EC2 disk exhaustion, memory pressure, reverse-proxy timeouts and duplicate-or-unknown uploads.

## Phase 1 in this PR — rules parity without claiming 256 GB delivery
1. Share/validate YouTube-standard metadata: 100-codepoint title, 5,000 UTF-8-byte description, disallowed angle brackets; submit creator description to Google instead of silently discarding it.
2. Recognize YouTube-supported video containers and map correct MIME types for mobile/web; reject executables/audio. Codec validity remains confirmed by YouTube, not guessed from extension.
3. Display both the **YouTube maximum** and **WeuTube's actual 256 MiB direct-transport cap** honestly; do not advertise 256 GB uploads as working.
4. Add backend and Flutter tests for Unicode, UTF-8 byte limits, accepted formats and capacity distinction.
5. Preserve private upload/administrator-grant protections and never bypass real channel authorization.

## Phase 2 — YouTube-native resumable uploads, NO S3 (corrected 2026-11-16)

**Decision:** YouTube alone stores full videos. WeuTube does not maintain a second 256 GB copy in S3 or on EC2. This explicitly supersedes the earlier S3 staging proposal.

**Why a small server relay is still required for the current shared-channel model:** Google's documented resumable session creation AND subsequent upload PUT requests require a Google OAuth bearer token. The connected YouTube channel belongs to the WeuTube operator and is grant-controlled. Exposing that channel's access/refresh token to a member's Flutter client would let that member act as the channel outside WeuTube's access checks.

Flow:

```text
Flutter (original video stays on phone/desktop)
  → authenticated WeuTube HTTPS API: 8 MiB chunk + opaque session ID
  → bounded in-memory/streaming server relay (no full-file disk staging)
  → Google/YouTube resumable session; 308 Range = authoritative received bytes
  → YouTube alone stores/processes video, returns verified ID
PostgreSQL stores only upload progress/ownership/session metadata
```

A different *creator-owned YouTube channel* product could use OAuth PKCE/user-delegated Google tokens and upload straight from the client to YouTube (official JavaScript API CORS sample). That is not safe to substitute for the existing administrator-controlled shared channel without changing consent, grants and ownership.

Implement before raising the current 256 MiB direct uploader limit:

1. **Authenticated sessions.** API creates an opaque session ID tied to one draft and creator identity. Validate existing admin grant and OAuth-connected channel at creation and every chunk, file name/media type, title/description, size <=256 GB, eligible long-upload status, fixed chunk size and per-account quotas. Initiate Google's resumable session on the server. Store the Google session URI privately in PostgreSQL; **never** return it or Google bearer tokens to clients.
2. **Small streaming relay.** Each chunk is <=8 MiB (multiple of 256 KiB; final part may be smaller). Stream the incoming HTTP request directly into a Google `PUT` while preserving Content-Range and bounded memory/temporary buffers. No S3 uploads, no 256 GB EC2 disk staging. Limit concurrent chunk requests to avoid 40 GB root-disk pressure and resource exhaustion.
3. **Checkpoint + reconciliation.** Persist the Google-confirmed offset from HTTP 308 `Range`, never the number of bytes the phone merely sent. After a dropped connection, timeout or server restart, query Google via `PUT` with `Content-Range: bytes */TOTAL` to recover its true offset. Do not create another video or repeat a non-idempotent request blindly. Respect backoff and expired session policies.
4. **Flutter.** Read the original local video in seekable 8 MiB slices without buffering the full file. Persist the opaque WeuTube session ID, Google-confirmed offset and file fingerprint; on app restart ask the user to reselect the same original file when Android/browser file permissions expire. Offer pause, resume, cancel, retry and accurate transfer percentage. If upload is paused, it cannot continue with the device offline unless some other holder possesses the original bytes.
5. **Completion + processing.** On successful Google response, verify returned YouTube video ID, expected channel and private status before transitioning to PRIVATE_REVIEW. Display separate "Sending to YouTube", "Processing on YouTube", and "WeuTube review" stages.
6. **Safety + cost.** No S3 video storage, but EC2 relaying still has network and compute cost. Never promise zero bandwidth cost. Rate-limit uploads, bound concurrent sessions, expire abandoned sessions, verify MIME/container and duration/long-video privilege. YouTube API quotas/channel rules still apply.
7. **Tests.** 308 zero/nonzero Range, invalid/off-by-one ranges, concurrent chunks, 256 GB arithmetic, auth revocation, expired URI, reconnect after app/server restart, 5xx handling, partial response, duplicate completion, large-file client I/O, real authorized channel smoke. Do not enable the new 256 GB path until integration tests pass and the operator approves resource limits.

**No background video-storage worker is required for the streaming approach.** A small status/reconciliation job may still be useful. Google cannot complete an upload if the app stops transferring and no other source holds the bytes.

Official protocol: https://developers.google.com/youtube/data/guides/using_resumable_upload_protocol

## Phase 3 — full YouTube upload-feature compliance
- Add a creator-controlled final visibility choice (public/private/unlisted) and keep a separate WeuTube approval state; design YouTube privacy transitions so creators are never told a private video is public. Currently WeuTube requires private initial uploads and admin-approved public release, which must be redesigned against YouTube Required Minimum Functionality.
- Add `selfDeclaredMadeForKids`, age restrictions, synthetic/altered-media disclosures and copyright/rights confirmation where applicable; carry them through to YouTube API payload.
- Correctly persist/submit YouTube description, category and language. WeuTube's app-specific discovery category is NOT identical to YouTube's categoryId; use a known mapping or YouTube category API.
- Support Shorts classification based on duration/aspect ratio using provider response, not user-declared category alone.
- Real-user and app-policy review, upload rights/grants, Google OAuth project verification, quota availability and YouTube API audit.

## Release and acceptance
- Phase 1 only is eligible for normal CI and release. Do not falsely claim 256 GB uploads work after Phase 1.
- Production APK/web deployment may proceed when Java tests, Flutter analysis/tests/builds pass.
- Full parity is not complete until Phases 2 and 3 pass end-to-end checks. Do not turn off the direct transport limit without a durable, tested alternative.
