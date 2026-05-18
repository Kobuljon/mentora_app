import 'dart:io';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

class OptimizedLiteRtEngineFactory {
  const OptimizedLiteRtEngineFactory._();

  static Future<LiteLmEngine> create({
    required String modelPath,
    bool enableVision = true,
    int maxNumTokens = 8192,
    int maxNumImages = 1,
    List<LiteLmBackend>? preferredBackends,
    bool? enableSpeculativeDecoding,
    bool enableBenchmark = false,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final cpuThreads = Platform.numberOfProcessors.clamp(1, 16).toInt();
    final backends = preferredBackends ?? _preferredBackends();
    final failures = <String>[];

    for (final backend in backends) {
      try {
        return await LiteLmEngine.create(
          LiteLmEngineConfig(
            modelPath: modelPath,
            backend: backend,
            visionBackend: enableVision ? backend : null,
            cacheDir: cacheDir.path,
            cpuThreads: backend == LiteLmBackend.cpu ? cpuThreads : null,
            maxNumTokens: maxNumTokens,
            maxNumImages: enableVision ? maxNumImages : null,
            enableSpeculativeDecoding: enableSpeculativeDecoding,
            enableBenchmark: enableBenchmark,
          ),
        );
      } catch (error) {
        failures.add('${backend.name}: $error');
      }
    }

    throw StateError(
      'Unable to initialize LiteRT-LM with optimized backends. '
      'Tried ${backends.map((b) => b.name).join(', ')}. '
      'Failures: ${failures.join(' | ')}',
    );
  }

  static List<LiteLmBackend> _preferredBackends() {
    if (Platform.isAndroid) {
      return const [LiteLmBackend.gpu, LiteLmBackend.npu, LiteLmBackend.cpu];
    }

    return const [LiteLmBackend.cpu];
  }
}
