// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

/// Copies a rendered symbol to the system clipboard as a PNG image. Uses the
/// platform-channel `pasteboard` plugin (macOS / Windows / Linux) — no native
/// Rust toolchain, so it doesn't block iOS / Android builds.
class ClipboardExport {
  ClipboardExport._();

  /// Writes [pngBytes] to the clipboard. Returns false if the platform has no
  /// image-clipboard support (e.g. mobile).
  static Future<bool> copyPng(Uint8List pngBytes) async {
    try {
      await Pasteboard.writeImage(pngBytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}
