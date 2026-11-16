# WeuTube Mobile Authentication Redesign — 16 November 2026

## Goal
Replace oversized vertically centered Sign In/Create Account cards with compact, familiar mobile-first authentication layouts. Preserve the approved WeuTube navy/coral branding and existing Cognito sign-up, confirmation, sign-in, password reset and MFA backend behavior.

## Reviewed problems
- Duplicate WeuTube brand: logo was in the global header and again inside the card
- Sign-in icon appeared in the header even on the sign-in screen
- Giant card was vertically centered with large unusable blank areas above/below
- Generic dashboard fields had floating outlines and disproportionate height
- Sign-up incorrectly positioned the product as *creator-only* instead of for both viewers and creators
- Password visibility had no explicit tooltip, new account could not confirm a hidden password
- Signup minimum password requirement of 12 characters existed on the backend, but was not explained in the form
- User-entered passwords could be carried between auth modes, creating unnecessary exposure

## Design implementation
1. Keep one header WeuTube brand; hide redundant top-right sign-in control on authentication pages.
2. Mobile (<650dp): use full-width, white page background, 24dp side padding and top-aligned content, no floating form card.
3. Tablet/desktop: retain centered max-width 430dp bounded form card with 32dp padding.
4. Reuse a single auth input component for sign-in, account creation, email confirmation, reset and MFA. Labels sit *above* their corresponding inputs rather than overlapping input borders.
5. 29sp heading, 14sp body, 52dp coral primary button, rounded 13dp fields and clear focus borders.
6. Show one clear password visibility control, accessible tooltip and platform autofill hints. Clear passwords on switching auth modes and after registration.
7. Add required field and email validation, and 12-character minimum plus matching confirmation for registration.
8. Move auth API errors into the form rather than showing them separately above a giant card.
9. Retain Forgot Password, Sign In, Create Account, verification and MFA flows. Users can return to Home without logging in.
10. Account creation uses inclusive "Join the community" language; no claims about creator-only membership.

## Security and privacy notes
- The backend Cognito registration contract requires a 12–128-character password, and the user pool may impose additional requirements; backend remains the final authority.
- Passwords must never be added to source code, build logs, analytics or screenshots. A previously captured screenshot showed a readable password; change it wherever in use.
- This change does not implement session persistence or password storage; existing in-memory token behavior stays unchanged.
- No Terms or Privacy policy links are invented without live, verified legal destinations.

## Verification and release gates
- Flutter analyze and widget tests, including mobile-only logo count, field count, autofill controls and local confirmation validation
- Flutter web release build and Android debug APK build
- Production backend Maven verification and HTTPS smoke test
- Physical-device keyboard behavior, autocomplete, autofocus, rotation, sign-up confirmation, reset email and MFA still require manual validation
- Merge to main only if CI passes; verify production workflow and serve matching test APK from the website

## Known follow-up
- Publish genuine Terms of Service and Privacy Policy pages and link them from Create Account before wider rollout.
- Add device-level accessibility review (TalkBack, large fonts, contrast), keyboard-switch testing and production-signed Android release after key management is configured.
