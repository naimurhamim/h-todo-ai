# H-TODO AI

An AI-powered academic and personal task planner built with Flutter, featuring natural-language schedule parsing in Bengali and English, Light and Dark glassmorphism UI, dual deadline reminders, privacy app lock, and Firebase cloud sync.

## Features

- **AI Schedule Auto-Plan:** Paste class notices, assignment deadlines, exam schedules, or syllabi in Bengali (`বাংলা`), English, or Banglish to extract structured tasks and syllabus checklists automatically.
- **Multi-Provider AI Support:** Bring your own API key for Google Gemini, Groq, xAI Grok, OpenRouter, or a custom OpenAI-compatible endpoint, with live model discovery and automatic fallback.
- **Smart Duplicate Handling:** Detects repeated task notices on matching dates/times, skips exact duplicates, and merges newly added syllabus items or notes into existing tasks.
- **Light & Dark Glassmorphism UI:** Smooth frosted cards, ambient backdrops, bottom-anchored AI chat with per-message copy, progress rings, and quick theme switching.
- **Dual Local Notifications:** Automatic reminders at `4:00 PM` the day before a deadline and `10:00 PM` on the due day (customizable in Profile -> Reminders), plus an Overview Notifications sheet showing countdowns.
- **Privacy & App Lock:** Optional 4-digit PIN and fingerprint/biometric unlock on app launch and resume.
- **Google Sign-In & Cloud Backup:** Automatic debounced backup and restore via Firebase Auth & Cloud Firestore.
- **In-App Update Checker:** Verifies the latest GitHub Release from Profile -> About -> Check for Updates.

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
