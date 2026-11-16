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

## Phase 2 — durable resumable ingress; required for 256 GB parity
Implement *before* removing 256 MiB cap:
- A server-owned upload session: `POST /api/creator/uploads` returns opaque upload ID with owner/authorized-channel linkage, size, expected content type, expected duration and checksum. Idempotent; no Google credentials go to client.
- Chunked/direct-to-durable-storage ingress (S3 multipart via scoped presigned part URLs, 8-64 MiB parts with no leaked credentials). S3 supports multipart uploads beyond 256 GB; encrypted object with TTL and per-creator quotas. Ensure bucket lifecycle cleanup for abandoned multipart data.
- Validate size/duration, MIME sniffing/container metadata with bounded ffprobe; detect unsupported codecs, empty files and suspicious files. Use YouTube `status.longUploadsStatus` on OAuth-connected authorized channel for 15min restrictions. Never use filename extension alone as security proof.
- A durable queue/worker with idempotent DB state transitions; stream from S3 to Google resumable session (Content-Range, 308 support, ranged retry, backoff) and persist upload-session state/bytes/checkpoints securely. Do not mark success until YouTube responds with verified video ID, private status and expected channel.
- Show distinct **device-to-storage**, **storage-to-YouTube**, **YouTube processing**, and **WeuTube review** states. Persist progress across app restarts; support pause/resume/cancel/retry without duplicate uploads.
- Cap concurrent uploads and enforce per-account bandwidth/storage quotas to avoid unexpected AWS charges. Confirm daily provider quota and user/channel upload limits with YouTube API rather than inventing a single universal number.
- Add integration tests for 256 MB boundary, 1+ GB simulation, network cut, chunk mismatch, expired session, server restart, duplicate completion and cleanup. Measure 4K/long-video performance on Android and web.

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
