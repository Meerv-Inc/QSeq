// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

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
