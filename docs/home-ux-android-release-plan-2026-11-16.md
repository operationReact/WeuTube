# WeuTube Home UX and Android test release — 16 November 2026

## Release goal
Make the Flutter Home feed easier to understand, visibly brand-consistent, and usable from the same verified website and Android **test** APK. Preserve the approved navy/coral WeuTube brand assets and the existing Cognito and Spring Boot API integration. No new sample engagement should be presented as live statistics.

## Workstream 1 — Navigation and compact header
- Keep the existing WeuTube brand header, but shrink mobile height from 66px to 54px (desktop 62px).
- Exactly one search entry point, in the main header. Search leads to Explore.
- Remove the redundant sign-in/account icon from social feed screens; account access is through the bottom **You** tab. Keep sign-in on non-social public pages and authenticated administrative navigation.
- Shorts becomes a dedicated immersive vertical swipe view with no redundant global header.
- Maintain consistent five-tab navigation: Home, Explore, Shorts, Create, You.
- **Acceptance:** Home has exactly one search entry point; bottom tab destinations remain reachable; Shorts does not have a second header.

## Workstream 2 — Discovery and feed hierarchy
- Rename the non-chronological "Fresh" label to **Latest**, and sort real videos by `publishedAt` newest-first; undated demo fixtures follow real uploads.
- Remove the redundant "Your video" plus control from the creator strip; Create remains the upload entry point.
- Rename the strip **Discover creators**. Do not use coral story/unseen rings in a directory of ordinary profiles.
- Creator discovery avatars lead to Explore instead of implying a feature-complete Stories viewer.
- Retain Following filter and its discover-creators empty state.
- Add pull-to-refresh around Home's vertical pager.
- **Acceptance:** Latest is clear, Home hierarchy is smaller, and the discovery row doesn't promise story behavior.

## Workstream 3 — Playback and engagement
- Continue autoplaying **only the active demo preview**, muted, with at most one active controller. Do not autoplay offscreen cards.
- First tap unmutes a playing preview; subsequent taps pause/resume. A separate explicit sound toggle enables re-muting.
- Hide the centered Play icon while playback is active, restore it if preview is unavailable or paused.
- Provide a subtle scrubbable playback-progress indicator.
- Pause previews when the app goes to background and resume active previews appropriately.
- Keep double-tap like; real likes, comments, follows, and saves require authenticated API calls.
- Published YouTube videos remain external links until licensed in-app playback is implemented and verified. Do not claim direct native playback for them.
- **Acceptance:** Video play/pause and audio controls are usable in Home and Shorts, and Play does not overlay playing content.

## Workstream 4 — Automated regression checks
- Flutter analyze and widget tests, including search duplication, discovery labels, Latest selection, and Shorts header behavior.
- Build Flutter production web and a debug-signed Android test APK from the **same commit**.
- Verify that APK is nonempty and a valid ZIP/APK, archive it as a GitHub Actions artifact, and publish its SHA-256 alongside the downloadable file.
- Backend Maven verify and production smoke tests remain required by the existing deployment workflow.
- **Acceptance:** CI green; deployment job confirms HTTPS website, API health and APK URL.

## Workstream 5 — Deployment and user verification
1. Open PR from `fix/home-feed-navigation-playback-20261116` into `main`.
2. Review Flutter CI run; correct any static analysis, widget or build failures.
3. Merge once green. The deployment workflow responds to `apps/flutter/**` changes on `main` and deploys the website and matching test APK together.
4. Verify `https://weutube.com/`, `https://api.weutube.com/actuator/health`, and `https://weutube.com/downloads/weutube-test.apk`. Compare its checksum with `weutube-test.apk.sha256`.
5. Manually test Android back navigation, autoplay, mute, pause, double-tap, discovery/Following/Latest, login and protected engagement on a physical device.

## Important release constraints
- `weutube-test.apk` is a **debug-signed test APK**. It is not production-distribution signing. Debug keys created on different CI runners can change; updates may require uninstalling an older test APK.
- Do not publish a production-signed APK until a persistent signing key is configured securely in CI and verified. Do not store keystore secrets in Git.
- The public feed still contains **clearly labelled demonstration content**. A successful deployment proves the UI/package and smoke-tested endpoints; it does not prove true creator engagement, payouts, or comprehensive real-device media quality.
- User-visible APK links should point to the exact tested build; never infer a GitHub Actions run or artifact ID before it exists.

## Out-of-scope follow-up
- Dedicated creator profile pages and real creator Story behavior.
- Licensed in-app published-video playback.
- Production Android signing, release key continuity and Play Store distribution.
- Real user device/performance and accessibility certification beyond automated checks.
