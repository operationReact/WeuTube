# Official YouTube embedded playback in WeuTube — implementation plan

## Goal
Enable **actual publicly published YouTube-hosted videos** to play inline in WeuTube's immersive Home and Shorts while keeping existing demo MP4 playback, approved navy/coral brand palette, five-tab navigation, and Spring Boot API. No video proxy, stream scraping, or audiovisual caching.

## Critique: constraints that determine the design
1. **YouTube player cannot be covered.** The social action rail, captions, scrims, play-heart overlays, and gestures used on DEMO MP4s cannot sit on the official YouTube iframe. Real YouTube posts use the same rounded dark immersive card but reserve an unobstructed video viewport at the top; creator information and WeuTube engagement controls live **beneath** the iframe, entirely outside it. Do not hide YouTube branding, ads, links, or controls.
2. **YouTube client identity must be supplied.** The current WeuTube web Caddy header is `Referrer-Policy: no-referrer`, which can cause embedding error 153. Set only the web host to `strict-origin-when-cross-origin` and keep API server no-referrer. Native WebView needs an app-ID origin `https://com.weutube.weutube`, matching the Android application ID produced by the existing Flutter CI scaffold.
3. **Minimum size**: iframe viewport must be at least 200px by 200px. The card allocates at least 200px height and a responsive width; do not use video full-bleed cover/crop that obscures the embedded player's controls.
4. **Visible-only autoplay**: only the active PageView item initializes a player, with mute=true and native YouTube controls intact. The preceding and next item use thumbnails, not hidden background players. A single player is permitted to autoplay and it may be blocked by the platform; always provide an 'Open on YouTube' fallback action.
5. **A source of truth**: only allow a validated HTTPS YouTube video ID extracted from approved hosts and path shapes, never load arbitrary URLs or raw media on our servers. Published feed rows already expose `youtubeUrl`; no backend schema change is required.
6. **Real engagement remains distinct**: currently WeuTube likes, comments, follows and saves are our API state. They must **not** be passed off as YouTube engagement or claimed as counted YouTube views / monetized viewing. Do not automate YouTube engagement actions.
7. **Mobile gestures**: YouTube controls necessarily intercept interactions within the iframe. Preserve vertical PageView swipe gestures on the content area below the player; disable library's vertical drag to enter fullscreen to reduce conflicts. Offer YouTube's fullscreen button explicitly.
8. **Device variance**: embed restrictions (creator disabled embed, georestrictions, ads, privacy settings), no-referrer older APKs, WebView quirks, and autoplay blocks can still break playback. A successful CI build cannot prove all videos play. Test real published videos on Android and Chrome; keep a fallback.

## Phases
1. Add `youtube_player_iframe: 6.0.2`, shared cross-platform published player stage, video URL validator and active-page lifecycle management.
2. Route published Home and Shorts items through a dark immersive card with the visible, unmodified player and separate footer actions; demo items keep their existing immersive video overlay design.
3. Route Explore/collections published-video taps through an inline modal rather than always launching the external YouTube app; fall back to the public YouTube link.
4. Fix web Referrer-Policy in `deploy/Caddyfile` and trigger production deploy when that file changes.
5. Add tests for genuine/impostor YouTube video IDs and no iframe when offscreen. Run Flutter analyze, unit/widget tests, web and Android build in CI; verify backend and deployment smoke unchanged.
6. Open PR, wait for green, merge; production workflow updates web/API stack and hosts a new debug-signed APK. Verify hosted APK URL and HTTPS website before calling the release deployed.

## Acceptance tests
- [ ] A real approved published `youtubeUrl` is embedded inline on Home and Shorts.
- [ ] The page below the YouTube player remains midnight navy/coral and immersive, not a generic white card.
- [ ] YouTube iframe is never obscured by WeuTube controls or decoration.
- [ ] Exactly one *visible* YouTube player is active; changing pages and leaving app stops previous playback.
- [ ] Official controls remain accessible; autoplay starts muted where allowed, with click-to-play if blocked.
- [ ] No unrelated/tracking/untrusted URL is loaded into the embed.
- [ ] Demo content is still clearly labeled and plays using the existing demo player.
- [ ] Creator follow/like/comment/save/share still work as **WeuTube** actions.
- [ ] Web Referrer header follows YouTube requirements.
- [ ] Flutter analyze/tests/web debug APK build pass and production smoke passes.
- [ ] Test real videos in browser and Android. Embedded-video playback cannot be certified from CI alone.

## User-experience caveats
- YouTube branding, ads, and controls are non-negotiable. Our card's visual identity surrounds them; it cannot mask them for a clone-like edge-to-edge effect.
- Automatic playback is not guaranteed by browsers/OS or by a video's embedding permission.
- Player availability may vary by region and user/device. The app offers an external YouTube fallback.
- `weutube-test.apk` remains debug-signed and can conflict with older installs signed by a different CI debug keystore.
- WeuTube's monetization and content policy require a separate YouTube-policy review. This implementation does not alter earnings, wallet, milestones, or grant any entitlement based on YouTube autoplay.
