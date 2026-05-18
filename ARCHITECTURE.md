# Mentora Architecture

Mentora is a Flutter app for the Future of Education track. It uses Gemma 4 locally so students can study with a private AI tutor in low-connectivity environments.

## System Overview

```
Student material
  -> MaterialProcessorService
  -> SQLite training_data_chunks
  -> TrainingDataSearchService
  -> Gemma 4 through LiteRT-LM
  -> Chat, quiz generation, answer evaluation, progress analytics
```

## Gemma 4 Usage

- `ModelDownloadService` downloads and manages Gemma 4 E2B/E4B `.litertlm` model files.
- `OptimizedLiteRtEngineFactory` initializes LiteRT-LM with preferred local backends and benchmarking enabled.
- `AiChatService` runs Mentora's tutor chat, including image input when a vision-capable model is available.
- `AiStudyService` uses Gemma 4 to generate material-specific questions and evaluate student answers with optional grammar feedback.

## Grounding and Privacy

Imported materials are processed on the device and stored in SQLite. `TrainingDataSearchService` retrieves relevant chunks from the student's own materials, then injects those snippets into the Gemma 4 prompt. The tutor is instructed to treat uploaded learning material as the primary source and cite source labels such as filename and page number.

Because inference and material storage are local, students can use Mentora after the model download without sending study content to a remote AI API.

## Material Processing

- PDFs are parsed page by page, cleaned, quality-scored, and stored as searchable chunks.
- DOCX files are unpacked and extracted from document XML.
- Images are processed with on-device text recognition.
- Audio can be transcribed through the configured local transcription backend.

## Learning Loop

1. Import a source.
2. Ask grounded follow-up questions.
3. Generate a quiz from the source.
4. Complete answers.
5. Receive Gemma-powered evaluation and grammar feedback.
6. Track progress locally across materials and study sessions.
