# H-TODO AI

An AI-powered academic and personal task planner built with Flutter, featuring natural-language schedule parsing in English, Bengali (`বাংলা`), and Banglish, Light and Dark glassmorphism UI, a smart recurring/bulk rule engine, strict date-based exact alarms, biometric app lock, and private Google Drive sync.

- **Interactive Showcase Website:** https://aitodo.naimurrashid.dev
- **Download Latest Android APK:** https://github.com/naimurhamim/h-todo-ai/releases/latest

## Features

- **Multilingual AI Auto-Plan:** Paste raw class notices, assignment deadlines, exam schedules, or syllabi in English, Bengali (`বাংলা`), or Banglish to extract structured tasks and syllabus checklists automatically, with smart duplicate detection and syllabus merging.
- **Smart Recurring & Bulk Rule Engine:** Generate daily, every-N-days, weekly, or monthly routines (up to **400 tasks / 366 days** per command in ~1–2 seconds locally without free API token timeouts), plus natural-language `bulk_delete`, `bulk_reschedule`, `bulk_update`, and `bulk_complete` actions with an instant top floating `Undo / OK` bar.
- **Hybrid Local-First Chat Engine & Scrollable Presets:** Built-in zero-token **Quick Presets** (1-tap Instant Q&A chips such as `Today`, `Tomorrow`, `This Week`, `Next Due`, `Overdue`, `Summary`, `Reminders` plus editable templates for `Daily Routine`, `Twice Daily`, `Weekly`, `Monthly`, `Postpone Today`, `Clear Done`) execute strictly offline with AI switched off, while complex multi-line notices and syllabi route exclusively to Cloud AI with zero overlap.
- **Multi-Provider BYOK AI Support & Atomic Auto-Failover:** Bring your own free API keys (even comma-separated backup keys per provider) for **Groq (Recommended • Fast)**, Google Gemini, OpenRouter, xAI Grok, or any custom OpenAI-compatible endpoint. Includes prompt/context compression and automatic Multi-Model, Multi-Key, and Cross-Provider failover on rate limits (`429`), retired models, or truncated JSON — discarding incomplete JSON atomically before trying the next model.
- **Strict Date-Based Exact Alarms & 99-Alarm Rolling Window:** Default reminders fire at `4:00 PM` the day before and `10:00 PM` on the due day (customizable in Profile -> Reminders). Tasks with a custom due time disable default alerts automatically so alarms never double-fire. Respects Android OS alarm caps by scheduling the soonest 99 exact alarms chronologically and auto-rolling on launch and resume. The Overview bell badge counts strictly **Today's remaining tasks** and opens a read-only **Notifications** sheet with separate **Today** and **Tomorrow** panels.
- **Expanded Built-in Categories & Custom Task Types:** Includes 21 built-in categories (`Assignment`, `Class Test`, `Exam`, `Lab`, `Meeting`, `Mail`, `Travel`, `Bank`, `Institution`, `Call`, `Work`, `Study`, `Bill`, `Shopping`, `Health`, `Fitness`, `Event`, `Family`, `Document`, `Personal`, `Task`) with automatic EN/BN inference, plus `+ Custom` user-defined task types with a 30-icon picker synced across tasks and backups.
- **Today-Anchored Open Timeline (`All Scheduled`):** Opens `All Scheduled` directly anchored at **Today** with future schedules below and earlier dates smoothly scrollable upward above, plus a 1-tap `Today` jump button.
- **Light & Dark Glassmorphism UI:** High-refresh-rate (`90Hz / 120Hz` auto-enabled on supported Android displays) frosted glass cards, state-preserving tab navigation, interactive `Overview` (7-day strip, live progress ring, Next Up countdown, **Upcoming Tasks** with automatic Tomorrow fallback), `Plan Your Day` (swipeable Week Grid & Today-anchored Full Timeline views), `AI Auto-Plan`, and `Profile`.
- **Privacy & App Lock:** Optional 4-digit PIN and fingerprint/biometric unlock on app launch and resume.
- **Opt-In Private Google Drive Sync & Offline JSON Backup:** Brand-new users stay offline with zero unsolicited auto sign-in prompts until tapping Google Sign-In; returning signed-in users silently reuse cached Drive authorization without Credential Manager `"Signing you in..."` popups and auto-backup quietly in the background (emitting top banners only on newly downloaded cloud data, manual backup/restore, or sync errors). Syncs to each user's private Google Drive `appDataFolder` with offline delete tombstones (`deletedTaskIds`), plus portable JSON Export and Merge/Replace Import.
- **Auto Update Checker & Quiet Notifications:** Silently checks GitHub Releases on launch, notifies once per release via Android notification & Overview bell banner linking directly to Profile -> Check for Updates, and clears automatically once updated.

## Interactive Showcase Website (`docs/`)

The `docs/` directory hosts the responsive GitHub Pages showcase for `H-TODO AI` at `https://aitodo.naimurrashid.dev` (`docs/CNAME`), featuring:
- Interactive desktop and mobile glassmorphism phone simulator covering all 4 app screens (`Overview`, `Plan Your Day`, `AI Auto-Plan`, `Profile & Security`).
- Annotated curved SVG arrow callouts (desktop) and numbered interactive hotspot pins (mobile/tablet) explaining every feature.
- Bilingual `EN / বাংলা` switch, synced Light/Dark Glass toggle, live GitHub Releases APK download integration, and developer details.

## Local Setup

1. Place your Firebase Android config file at `android/app/google-services.json` (gitignored so credentials stay private).
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run static analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Build or run on Android:
   ```bash
   flutter run
   flutter build apk --release
   ```

## Developer

- **Name:** MD Naimur Rashid
- **Website:** https://naimurrashid.dev/
- **GitHub:** https://github.com/naimurhamim
- **LinkedIn:** https://www.linkedin.com/in/md-naimur-rashid/
