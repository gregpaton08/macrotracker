# App Store Readiness Checklist

## Blockers (will prevent submission or cause rejection)

- [ ] Add `PrivacyInfo.xcprivacy` manifest — required since April 2024; must declare HealthKit, network API usage (Gemini, Open Food Facts), and CloudKit
- [ ] Create a public privacy policy and add the URL in App Store Connect — required for any app that collects health data or uses third-party APIs
- [ ] Resolve API-key UX — Apple rejects apps that require users to supply their own API keys (guideline 4.2 Minimum Functionality). Options: ship a backend proxy, bundle a free tier, or accept the risk
- [ ] Add a disclaimer: not a dietician, not medical advice, consult your physician, etc.

## High-impact polish

- [ ] Accessibility — progress rings and calendar dots are color-only; VoiceOver users get nothing
- [ ] Add network timeout — "Auto-Fill with AI" hangs ~60s with no internet before erroring
- [ ] Add cancel button to 'Analyzing' display when loading AI generated macros
- [ ] Surface error UI for silent failures — Gemini 429 (rate limit) silently returns 0 macros; CoreData saves use `try?`
- [ ] Switch off `gemini-3-flash-preview` — preview models can be removed by Google without notice
- [ ] Validate goal min/max — min > max causes broken progress rings

## Recommended

- [ ] Migrate API key storage from UserDefaults to Keychain — keys are currently in plaintext
- [ ] Test on a real device — CloudKit sync and HealthKit don't work in the simulator
- [ ] Wire up `LocalParser` regex fallback or remove it from CLAUDE.md — documented but never called
- [ ] Add meal description length limit (could waste API tokens on very long input)
- [ ] Save on background — no scene phase handling; data not explicitly saved when app backgrounds

## Feature ideas

- [ ] Add option to choose Gemini model from available (hit the API for a list)
- [ ] Sort meals by macros, e.g. user can see meals high in fat
- [ ] Option to have Gemini analyze my diet for the past week, or arbitrary time range — actionable insights
- [ ] Show trends, like in Apple Health, e.g. "you've been eating 12g less fat per week over the past week compared to..."
- [ ] Push data back to Apple Health (is this even possible?)
- [ ] Store metadata in meal item, i.e. barcode value and Gemini prompt (for debugging)
- [ ] Get Gemini API limits and display in app
- [ ] Localization — all strings are hardcoded English; number formatting breaks in European locales
- [ ] Add switch in settings to disable AI features.
- [ ] From Gemini, for backend: To make it mathematically impossible to spoof requests, implement Apple's DeviceCheck / App Attest service. App Attest uses a hardware enclave on the iPhone to cryptographically sign requests, proving to the AWS backend that the request is coming from an untampered version of the app running on a genuine Apple device.
