import 'dart:io';

import 'package:flutter/services.dart';

class AndroidFileShareService {
  AndroidFileShareService._();

  static const _channel = MethodChannel('mentora/file_share');

  static Future<void> shareFile({
    required String path,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('File sharing is only implemented on Android.');
    }

    await _channel.invokeMethod<void>('shareFile', {
      'path': path,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }
}
