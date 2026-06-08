import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

/// Copies a rendered symbol to the system clipboard as a PNG image.
class ClipboardExport {
  ClipboardExport._();

  /// Writes [pngBytes] to the clipboard. Returns false if the platform has no
  /// clipboard support.
  static Future<bool> copyPng(Uint8List pngBytes) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return false;
    final item = DataWriterItem()..add(Formats.png(pngBytes));
    await clipboard.write([item]);
    return true;
  }
}
