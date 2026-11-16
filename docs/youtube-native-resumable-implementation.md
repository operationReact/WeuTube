# YouTube-native, S3-free resumable video uploads

## Product contract

The active Flutter **Create** uploader accepts the same advertised **total video size** as YouTube: up to **256 GB or 12 hours, whichever is less**, subject to the connected channel's YouTube privileges and Google's own validation. No WeuTube-specific per-video size ceiling applies to the resumable route. **8 MiB** is only the per-request transfer chunk and does not limit the size of a completed upload.

YouTube Help: https://support.google.com/youtube/answer/71673
YouTube resumable API: https://developers.google.com/youtube/data/guides/using_resumable_upload_protocol

## Data flow (no video storage on WeuTube)

1. Creator signs in and gets a valid admin grant to a connected shared YouTube channel.
2. Flutter creates a draft and submits its title, description and discovery category.
3. Flutter calls `POST /api/creator/uploads` with draft UUID, authorized channel, filename and **full video length as a 64-bit integer**.
4. Spring Boot validates ownership/grants and initializes Google's private resumable session using a backend-only OAuth access token, caching the short-lived access token across chunk requests.
5. The API stores only a UUID, owner and connected channel, file metadata/size, private Google session URL, Google-confirmed offset and state in PostgreSQL (Flyway V11). **No S3 bucket or persistent local video copy is created.**
6. Flutter reads up to **8 MiB at a time** from the selected original video and sends it to `PUT /api/creator/uploads/{id}/chunk` with Content-Range. The server forwards one bounded chunk to Google. A maximum of four chunk relays may be in memory at once to protect server availability.
7. Google responds **308** with a confirmed byte range or **200/201** with the newly created video. Progress displayed to the creator is based **only on the range acknowledged by Google**, not how quickly the app sent bytes into a socket.
8. On interrupted/uncertain transfer the server records RECONCILE. `GET /api/creator/uploads/{id}` probes Google's accepted offset before the app resends. On verified completion the video enters PRIVATE_REVIEW.
9. Flutter persists an opaque session ID and filename/size locally. If OS file access expires or the app restarts, the creator reselects the same original video to resume. No YouTube OAuth token or resumable provider URL is exposed to creator clients.
10. `DELETE /api/creator/uploads/{id}` cancels a pending session without deleting a file from S3 (there is no S3 file). It cannot cancel a Google video already completed.

## Endpoints

| Route | Description |
|---|---|
| POST /api/creator/uploads | Idempotent owner/channel-scoped start; returns session ID, total, acknowledged, status, chunkBytes |
| GET /api/creator/uploads/{id} | Owner-only progress and provider status reconciliation after uncertain transfer |
| PUT /api/creator/uploads/{id}/chunk | Authenticated application/octet-stream body, Content-Range, maximum 8 MiB per *request* |
| DELETE /api/creator/uploads/{id} | Owner-only cancellation |

Everything is authenticated and re-checks the channel grant. The older `/api/creator/videos/{id}/private-upload` endpoint remains temporarily for older APK compatibility, but it is no longer called by the active Create UI; its 256 MiB synchronous gateway remains isolated.

## Honest release qualifications

- YouTube may reject a video because of channel verification (15-minute default), copyright/strikes, actual file format or codec, insufficient quota, OAuth project restrictions, age/audience settings, long-upload eligibility, size or duration. These are YouTube decisions, not arbitrary WeuTube caps.
- There is **no extra S3 storage cost**, but relay traffic still has AWS EC2 internet-egress charges and Google Data API quotas.
- Mobile file streams are sequential. Resume after a restart currently re-reads/skips already-accepted bytes from the original file locally; it does **not** retransmit those bytes to YouTube. Optimized file seeks/Blob slices are recommended for long-video reliability.
- OAuth channel grants and live provider upload acceptance require an authorized real account test. CI mocks and green pipelines alone do not prove Google accepted a multi-gigabyte upload.
- Google has finite-lived resumable session URLs; expired sessions require explicit reconciliation and possibly a fresh upload. Do not blindly duplicate a provider upload.
- YouTube's public/unlisted/private **creator choice**, audience fields, and provider publication controls remain tracked separately in issue #8. Current WeuTube moderation still starts with private uploads only.
- WeuTube limits concurrent in-flight relay requests for reliability but **not the total video size**. WeuTube does not store full videos.
- Source filename/size are checked for a resumed file, but a robust content fingerprint, direct seek optimization, real 4K/256-GB transfer smoke tests and server fault-injection remain important production-hardening items.

## Verification and deployment gate

1. Maven `verify` including `CreatorResumableUploadControllerTest`, `YouTubeResumableRangesTest`, and `YouTubeAccessTokenServiceTest`.
2. Flutter analyze, widget tests, web release build, Android debug APK build.
3. Production Flyway V11 migration + API health checks and web/deploy smoke check.
4. A real authorized-channel 1+ GiB upload, interrupted transfer resume, Google verified private review, and network-charge measurement before describing the full-size path as production proven.

**Never advertise real 256 GB upload success based solely on CI.**
