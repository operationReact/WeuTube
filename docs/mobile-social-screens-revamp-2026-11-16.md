# WeuTube mobile social surfaces — critical UX review and revamp
Date: 2026-11-16

## Review summary
The Home playback work is stronger than the supporting app surfaces. Current Explore, Create and You present many large decorative cards, marketing copy, horizontal carousels and multiple inconsistent navigation patterns. This creates poor information density, hides primary actions, and makes the app feel like unrelated pages rather than one coherent video service. Additionally, Explore showed both a header search button and an active search box, Create relied on an unrelated thumbnail to explain upload, and the guest You page used broad self-promotional panels instead of useful account actions.

## Design principles
- Preserve approved connected-people WeuTube icon/wordmark, navy and coral. No generic icon substituted for brand.
- One consistent global header, five-item bottom nav, white content background and compact 16–20dp margins.
- Video first. No fabricated creator statistics or demo content presented as real.
- Primary CTA visible without scrolling on normal mobile devices.
- Small screens down to 320dp must not overflow. Use 44dp+ hit targets and single meaningful title.
- Published YouTube embeds must keep their unobscured official player, separate from WeuTube engagement actions.
- Existing Spring Boot, Cognito auth, YouTube feed and genuine social API behavior must remain intact.

## A. Explore
- Title + short subtitle, followed immediately by search.
- One search entry point in this context (hide search icon in global header on Explore).
- 40dp topical chips, scrollable only when necessary.
- Feature content uses an actual feed video thumbnail/title/creator and demo label when appropriate.
- A compact creator strip (tapping calls existing follow action), then a real two-column video grid.
- Search empty state is a helpful message with a clear-search icon; no fake results.
- Remove theatrical copy ('Spotlight', 'Curated preview stories') that implied editorial curation.

## B. Create
- Simple title and clear upload CTA in the first screen viewport.
- Remove generic stock preview/image unrelated to the signed-in user's videos.
- Navy upload focus area with compact coral primary button.
- Explain Prepare / Review / Publish as three readable steps below it.
- If anonymous, CTA is Sign in to upload, not a nonfunctional upload button.
- Retain private upload and approval workflow; never claim immediate public publishing.

## C. You
- Compact profile header and explicit guest/signed-in state (no fake follower counts).
- Sign-in or Creator Studio button according to real session.
- Saved and Following as readable list rows with icons and chevrons.
- Real creator tools only for authenticated users, using the existing guarded navigation.
- No decorative giant navy profile banner, repeated creator suggestions or illustrative fake metrics.
- No change to Cognito session behavior.

## D. Responsive shell and verification
- Hide redundant header search button on Explore; search field is on the screen.
- Keep Home and Shorts video-first, including existing muted playback lifecycle.
- Add Flutter widgets tests covering updated labels, guest account affordances, empty search at 320dp and no duplicate search.
- Run Flutter analyze/test/web build and Android debug APK build. Verify every URL before distributing an APK.
- Deploy to https://weutube.com via the existing GitHub Actions main-branch workflow and verify health + APK.
- Actual device performance, video permissions and auth require manual smoke testing; CI doesn't establish UX success for all devices.

## Acceptance criteria
- All 5 bottom tabs remain functional and recognizable.
- No 320dp RenderFlex overflow.
- Explore search filters existing feed, clear search restores results; no duplicate search icon.
- Create first-screen CTA routes via existing sign-in or upload studio action.
- You guest doesn't report fictional profile stats.
- Source content remains clearly labelled demo vs published.
- No extra video/player created in discovery rows.
- All relevant CI checks pass, PR merged and production deployment verified.
