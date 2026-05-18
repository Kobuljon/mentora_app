# Mentora app ProGuard / R8 rules

# Ignore missing classes from optional ML Kit language packs (we only use Latin)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Ignore missing JP2000 decoder from PDFBox (optional dependency)
-dontwarn com.gemalto.jp2.**

# Keep Tesseract OCR native bindings
-keep class com.googlecode.tesseract.android.** { *; }
-keep class com.googlecode.leptonica.android.** { *; }

# Keep flutter_litert_lm native bindings
-keep class com.google.ai.edge.litertlm.** { *; }
-keep class com.google.litertlm.** { *; }
