```
❯ What else can I do to make my app professional grade quality?

⏺ Let me do a broader look at the codebase to give you a grounded answer rather than generic advice.

⏺ Task(Audit app for professional quality)
  ⎿  Done (34 tool uses · 64.4k tokens · 2m 46s)

⏺ Here's what I found, organized by what matters most for a v1 release.

  Must-fix before shipping
  ┌─────┬─────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  #  │                              Issue                              │                                                                     Why it matters                                                                      │
  ├─────┼─────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 1   │ No app icon                                                     │ Blank icon on home screen. Apple may reject.                                                                                                            │
  ├─────┼─────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────
  
  High-impact polish
  ┌─────┬────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────┐
  │  #  │                             Issue                              │                                    Details                                     │
  ├─────┼────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 7   │ Accessibility: progress rings and calendar dots are color-only │ VoiceOver users get nothing. Would fail an accessibility audit.                │
  ├─────┼────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 8   │ No network timeout                                             │ "Auto-Fill with AI" hangs 60 seconds with no internet before showing an error. │
  ├─────┼────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 9   │ No delete confirmation on meals                                │ Swipe-to-delete is immediate — no undo, no confirmation dialog.                │
  ├─────┼────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
  │ 10  │ Gemini model is -preview                                       │ gemini-3-flash-preview could be removed by Google without notice.              │
  └─────┴────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────┘
  Medium-impact (can ship without, but worth doing)

  - Hardcoded English strings (no localization readiness)
  - DateFormatter uses dateFormat instead of locale-aware setLocalizedDateFormatFromTemplate
  - Number formatting with String(format:) breaks in European locales (comma vs period)
  - No scene phase handling (data not explicitly saved on background)
  - Goal min/max not validated (min > max causes broken rings)
  - Meal description has no length limit (could waste API tokens)
  - Deprecated presentationMode usage (should be @Environment(\.dismiss))
  - No tests at all (0% coverage)

  Low-impact (future improvements)

  - Inconsistent NavigationView vs NavigationStack
  - Export fetches all meals without batching
  - API keys stored in UserDefaults instead of Keychain
  - Orphaned FoodEntity rows from v1 data model migration

  ---
  The top 6 are the ones I'd fix before submitting to App Review. Want me to tackle those?
```


* Add cancel button to 'Analyzing' display when loading AI generated macros.
