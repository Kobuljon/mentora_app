import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SherpaOnnxModelStatus {
  const SherpaOnnxModelStatus({
    required this.rootPath,
    required this.availableFiles,
  });

  final String rootPath;
  final Map<String, bool> availableFiles;

  bool get isReady => missingFiles.isEmpty;

  int get installedCount =>
      availableFiles.values.where((value) => value).length;

  List<String> get missingFiles => [
    for (final entry in availableFiles.entries)
      if (!entry.value) entry.key,
  ];

  String get summary => isReady
      ? 'Ready ($installedCount/${availableFiles.length})'
      : '$installedCount/${availableFiles.length} files ready';
}

class SherpaOnnxImportResult {
  const SherpaOnnxImportResult({
    required this.importedFiles,
    required this.status,
  });

  final List<String> importedFiles;
  final SherpaOnnxModelStatus status;
}

class SherpaOnnxModelService {
  SherpaOnnxModelService._();

  static final SherpaOnnxModelService instance = SherpaOnnxModelService._();
  static final Dio _dio = Dio();

  static const encoderFileName = 'encoder.int8.onnx';
  static const decoderFileName = 'decoder.int8.onnx';
  static const tokensFileName = 'tokens.txt';
  static const tinyEnglishRepoUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en';
  static const requiredFileNames = <String>[
    encoderFileName,
    decoderFileName,
    tokensFileName,
  ];
  static const _tinyEnglishDownloadUrls = <String, String>{
    encoderFileName:
        '$tinyEnglishRepoUrl/resolve/main/tiny.en-encoder.int8.onnx',
    decoderFileName:
        '$tinyEnglishRepoUrl/resolve/main/tiny.en-decoder.int8.onnx',
    tokensFileName: '$tinyEnglishRepoUrl/resolve/main/tiny.en-tokens.txt',
  };

  Future<SherpaOnnxModelStatus> getStatus() async {
    final root = await _ensureModelRoot();
    final available = <String, bool>{
      for (final fileName in requiredFileNames)
        fileName: File(p.join(root.path, fileName)).existsSync(),
    };
    return SherpaOnnxModelStatus(
      rootPath: root.path,
      availableFiles: available,
    );
  }

  Future<String> getModelRootPath() async {
    final root = await _ensureModelRoot();
    return root.path;
  }

  String filePathFor(String rootPath, String fileName) {
    return p.join(rootPath, fileName);
  }

  Future<SherpaOnnxImportResult> importFiles(
    Iterable<file_selector.XFile> files,
  ) async {
    final root = await _ensureModelRoot();
    final selectedByName = <String, file_selector.XFile>{};
    for (final file in files) {
      final destinationFileName = _destinationFileNameForSelection(file.name);
      if (destinationFileName == null) {
        continue;
      }
      selectedByName[destinationFileName] = file;
    }

    final importedFiles = <String>[];
    for (final requiredFile in requiredFileNames) {
      final selected = selectedByName[requiredFile];
      if (selected == null) {
        continue;
      }
      final targetPath = p.join(root.path, requiredFile);
      await _copyXFile(selected, targetPath);
      importedFiles.add(requiredFile);
    }

    if (importedFiles.isEmpty) {
      throw FormatException(
        'Select any of these Sherpa files: ${requiredFileNames.join(', ')}',
      );
    }

    final status = await getStatus();
    return SherpaOnnxImportResult(importedFiles: importedFiles, status: status);
  }

  Future<SherpaOnnxImportResult> downloadTinyEnglishModel({
    void Function(double progress)? onProgress,
  }) async {
    final root = await _ensureModelRoot();
    final downloadedFiles = <String>[];
    final entries = _tinyEnglishDownloadUrls.entries.toList();

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final targetPath = p.join(root.path, entry.key);
      final completedFiles = index;
      final totalFiles = entries.length;

      await _dio.download(
        entry.value,
        targetPath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (onProgress == null) {
            return;
          }
          if (total <= 0) {
            onProgress(completedFiles / totalFiles);
            return;
          }
          final fileFraction = received / total;
          onProgress((completedFiles + fileFraction) / totalFiles);
        },
      );
      downloadedFiles.add(entry.key);
      onProgress?.call((index + 1) / entries.length);
    }

    final status = await getStatus();
    return SherpaOnnxImportResult(
      importedFiles: downloadedFiles,
      status: status,
    );
  }

  Future<List<String>> exportFilesToDirectory(String directoryPath) async {
    final status = await getStatus();
    final exportedFiles = <String>[];

    for (final fileName in requiredFileNames) {
      if (status.availableFiles[fileName] != true) {
        continue;
      }
      final sourceFile = File(p.join(status.rootPath, fileName));
      if (!sourceFile.existsSync()) {
        continue;
      }
      await sourceFile.copy(p.join(directoryPath, fileName));
      exportedFiles.add(fileName);
    }

    return exportedFiles;
  }

  String? _destinationFileNameForSelection(String fileName) {
    final lower = p.basename(fileName).toLowerCase();

    if (lower == encoderFileName ||
        lower.endsWith('-encoder.int8.onnx') ||
        lower.endsWith('-encoder.onnx')) {
      return encoderFileName;
    }
    if (lower == decoderFileName ||
        lower.endsWith('-decoder.int8.onnx') ||
        lower.endsWith('-decoder.onnx')) {
      return decoderFileName;
    }
    if (lower == tokensFileName || lower.endsWith('-tokens.txt')) {
      return tokensFileName;
    }

    return null;
  }

  Future<void> _copyXFile(file_selector.XFile source, String targetPath) async {
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);

    final sourcePath = source.path;
    if (sourcePath.isNotEmpty) {
      await File(sourcePath).copy(targetPath);
      return;
    }

    final sink = targetFile.openWrite();
    try {
      await sink.addStream(source.openRead());
    } finally {
      await sink.close();
    }
  }

  Future<Directory> _ensureModelRoot() async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(
      p.join(supportDir.path, 'models', 'sherpa_onnx', 'whisper_tiny'),
    );
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    return root;
  }
}
