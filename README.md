# Mentora

An AI-powered English tutor for students aged 12–16, built with Flutter and Google's Gemma 4 on-device LLM.

## Features

- **On-device AI chat** — Powered by `flutter_litert_lm` with the Gemma 4 E2B/E4B Instruction-Tuned model running entirely on-device (no server, no API key).
- **Multimodal input** — Send images alongside text when using a vision-capable model build (~2.5 GB+). Text-only model builds show a graceful fallback message.
- **Markdown & LaTeX rendering** — AI responses render rich text, lists, code blocks, and math equations (inline `$…$` and block `$$…$$`).
- **Stoppable generation** — A stop button cancels active streaming mid-response.
- **Downloaded model management** — View, inspect, and delete downloaded models from the Settings screen.
- **Offline-first** — All inference runs on the device; no network connection required after model download.

## Models

| Variant | Display Name                  | Size    | Notes                      |
| ------- | ----------------------------- | ------- | -------------------------- |
| `e2b`   | Standard Engine (Gemma 4 E2B) | ~2.5 GB | Multimodal (text + vision) |
| `e4b`   | Advanced Engine (Gemma 4 E4B) | ~4 GB   | Multimodal (text + vision) |

> **Important:** The model file served at your download URL must be the **full multimodal build** (~2.5 GB for E2B). A text-only prune (~1.2 GB) will not support image input.

Models are downloaded to the app's documents directory and the active path is persisted in `SharedPreferences` under the keys `isModelReady` and `modelFilePath`.

## Requirements

- Flutter SDK `^3.11.4`
- `flutter_litert_lm ^0.3.0` (minimum for Gemma 4 multimodal support)
- Android API 34+ or iOS 17+ recommended for GPU backend performance
- ~3 GB free storage for the E2B model

## Getting Started

1. Clone the repo and run `flutter pub get`.
2. Launch the app; the onboarding screen will prompt you to download a model.
3. Once downloaded, open the Chat tab and start a conversation.

To run on a connected Android device:

```bash
flutter run -d "<device-id>"
```

Use `flutter devices` to list available device IDs.

## Architecture

```
lib/
  core/
    services/          # Notification service
    theme/             # App theme
  features/
    chat/              # Chat screen, provider, service, message model
    home/              # Home screen
    library/           # Library screen
    models/            # Downloaded models management screen
    onboarding/        # Model download flow & ModelDownloadService
    progress/          # Progress screen
    settings/          # Settings screen
  navigation/          # Bottom nav shell
```
