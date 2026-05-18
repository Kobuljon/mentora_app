import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalTestMaterialFile {
  const LocalTestMaterialFile({
    required this.assetPath,
    required this.name,
    required this.extension,
  });

  final String assetPath;
  final String name;
  final String extension;

  String get typeLabel => extension.replaceFirst('.', '').toUpperCase();
}

class LocalTestMaterialsService {
  LocalTestMaterialsService._();

  static final LocalTestMaterialsService instance =
      LocalTestMaterialsService._();

  static const folderPath = 'assets/Test Materials/';
  static const supportedExtensions = <String>[
    '.pdf',
    '.docx',
    '.mp3',
    '.m4a',
    '.wav',
    '.jpg',
    '.png',
  ];

  Future<List<LocalTestMaterialFile>> listFiles() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    final files =
        assets
            .where((assetPath) => assetPath.startsWith(folderPath))
            .where(_isSupportedAssetPath)
            .map(
              (assetPath) => LocalTestMaterialFile(
                assetPath: assetPath,
                name: p.basename(assetPath),
                extension: p.extension(assetPath).toLowerCase(),
              ),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));

    return files;
  }

  Future<String> materializeToTempFile(LocalTestMaterialFile file) async {
    final byteData = await rootBundle.load(file.assetPath);
    final tempDir = await getTemporaryDirectory();
    final outputDir = Directory(p.join(tempDir.path, 'mentora_test_materials'));
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    final outputPath = p.join(outputDir.path, file.name);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(_toUint8List(byteData), flush: true);
    return outputPath;
  }

  bool _isSupportedAssetPath(String assetPath) {
    final extension = p.extension(assetPath).toLowerCase();
    return supportedExtensions.contains(extension);
  }

  Uint8List _toUint8List(ByteData byteData) {
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }
}
