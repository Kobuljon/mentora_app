import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/model_download_service.dart';

// ── State ──────────────────────────────────────────────────────────────────────

enum SetupPhase {
  /// Idle: showing the two engine selection cards.
  selection,

  /// Actively downloading.
  downloading,

  /// Download finished successfully.
  complete,

  /// Something went wrong.
  error,
}

class ModelSetupState {
  final SetupPhase phase;
  final ModelVariant? selectedVariant;
  final DownloadProgress? progress;
  final String? errorMessage;
  final bool wifiWarning;

  const ModelSetupState({
    this.phase = SetupPhase.selection,
    this.selectedVariant,
    this.progress,
    this.errorMessage,
    this.wifiWarning = false,
  });

  ModelSetupState copyWith({
    SetupPhase? phase,
    ModelVariant? selectedVariant,
    DownloadProgress? progress,
    String? errorMessage,
    bool? wifiWarning,
  }) {
    return ModelSetupState(
      phase: phase ?? this.phase,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      wifiWarning: wifiWarning ?? this.wifiWarning,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ModelSetupNotifier extends StateNotifier<ModelSetupState> {
  ModelSetupNotifier() : super(const ModelSetupState());

  final _service = ModelDownloadService.instance;

  /// Called when the user taps one of the engine cards.
  Future<void> startDownload(ModelVariant variant) async {
    // 1. Network check.
    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (!isWifi) {
      state = state.copyWith(wifiWarning: true, selectedVariant: variant);
      return; // Show warning dialog; user must confirm.
    }

    await _beginDownload(variant);
  }

  /// Called when user confirms they want to download over cellular.
  Future<void> confirmCellularDownload() async {
    final variant = state.selectedVariant;
    if (variant == null) return;
    state = state.copyWith(wifiWarning: false);
    await _beginDownload(variant);
  }

  void dismissWifiWarning() {
    state = state.copyWith(wifiWarning: false);
  }

  Future<void> _beginDownload(ModelVariant variant) async {
    // 2. Disk space check.
    final freeMb = await DiskSpacePlus().getFreeDiskSpace ?? 0.0;
    final freeBytes = (freeMb * 1024 * 1024).toInt();
    if (freeBytes < variant.approximateSizeBytes) {
      final needed = _formatGb(variant.approximateSizeBytes);
      final free = _formatGb(freeBytes);
      state = state.copyWith(
        phase: SetupPhase.error,
        errorMessage:
            'Not enough storage. You need ~$needed GB free but only have $free GB available.',
      );
      return;
    }

    state = state.copyWith(
      phase: SetupPhase.downloading,
      selectedVariant: variant,
      progress: DownloadProgress(
        received: 0,
        total: variant.approximateSizeBytes,
      ),
      errorMessage: null,
    );

    await _service.downloadModel(
      variant: variant,
      onProgress: (progress) {
        state = state.copyWith(progress: progress);
      },
      onError: (error) {
        state = state.copyWith(
          phase: SetupPhase.error,
          errorMessage: 'Download failed: ${error.toString()}',
        );
      },
    );

    // If we reach here without an error, mark complete.
    if (state.phase == SetupPhase.downloading) {
      state = state.copyWith(phase: SetupPhase.complete);
    }
  }

  void retryFromError() {
    state = const ModelSetupState();
  }

  void cancelDownload() {
    _service.cancelDownload();
    state = const ModelSetupState();
  }

  static String _formatGb(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
}

// ── Providers ──────────────────────────────────────────────────────────────────

final modelSetupProvider =
    StateNotifierProvider<ModelSetupNotifier, ModelSetupState>(
      (ref) => ModelSetupNotifier(),
    );
