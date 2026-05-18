# Mentora: Your Offline AI Tutor, Trained on Your Materials

A private, on-device AI tutor for students in low-connectivity learning environments.

Mentora helps students turn their own PDFs, notes, images, and audio materials into grounded explanations, quizzes, answer feedback, and progress insights. It is built with Flutter and Google's Gemma 4 running locally through LiteRT-LM, so learning can continue after the model is downloaded even when the device is offline.

## Hackathon Submission

**Track:** Future of Education

**Core idea:** A tutor should not disappear when the Wi-Fi does. Mentora brings Gemma 4 onto the student's device, keeps private learning materials local, and adapts practice around the exact sources the student is studying.

## Demo Flow

1. Download a Gemma 4 E2B or E4B model during onboarding.
2. Turn on airplane mode to show the app is offline-ready.
3. Import a study material such as a PDF, scanned note, or audio file.
4. Ask Mentora what to review first and get an answer grounded in uploaded material snippets.
5. Generate quiz questions from the same material.
6. Complete a study session and receive comprehension and grammar feedback.
7. Review progress analytics built from local study history.

## Features

- **On-device AI chat** — Powered by `flutter_litert_lm` with the Gemma 4 E2B/E4B Instruction-Tuned model running entirely on-device (no server, no API key).
- **Multimodal input** — Send images alongside text when using a vision-capable model build (~2.5 GB+). Text-only model builds show a graceful fallback message.
- **Material-grounded retrieval** — Imported materials are chunked into a local SQLite knowledge base. Mentora retrieves relevant snippets and asks Gemma 4 to answer from those sources first.
- **AI-generated study sessions** — Generate quizzes from uploaded materials, answer them, and receive teacher-style evaluation and grammar feedback.
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

See [ARCHITECTURE.md](ARCHITECTURE.md) for the hackathon-focused technical overview.
