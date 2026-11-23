# ToneBuddy — On-Device Flutter ML Kit Smart Reply & Translator

Flutter mobile application combining **Google ML Kit Smart Reply** (`google_mlkit_smart_reply`) and **On-Device Translation** (`google_mlkit_translation`) to analyze conversation context and generate tone-calibrated response suggestions across **English**, **French**, **Spanish**, and **Arabic**.

## Key Features
- **On-Device Inference**: Generates smart replies and multilingual translations locally without external LLM API keys.
- **Conversation Parsing**: Supports WhatsApp `[timestamp] Sender: message` exports as well as direct pasted or typed messages.
- **Tone & Language Controls**: Select output language (`English`, `French`, `Spanish`, `Arabic`) and tone profile (`Professional`, `Friendly`, `Neutral`).
- **One-Tap Clipboard Copy**: Copy any suggested reply directly to the device clipboard.

## Tech Stack
- **Framework**: Flutter & Material 3 (`google_fonts`)
- **On-Device ML**: `google_mlkit_smart_reply`, `google_mlkit_translation`
- **Target SDK**: Android (minSdk 23, Kotlin/Gradle)

## Getting Started
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Screenshots
Screenshots are stored under `docs/screenshots/` covering the splash screen, conversation editor, language/tone selector, and generated smart-reply suggestions.
