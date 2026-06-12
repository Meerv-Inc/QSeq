// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// No-op download stub used during server prerender (no browser APIs). The real
// implementation lives in download_web.dart and is selected on JS targets.
import 'dart:typed_data';

void downloadText(String filename, String text, String mime) {}

void downloadBytes(String filename, Uint8List bytes, String mime) {}

Future<void> downloadSvgPng(
    String filename, String svg, int wPx, int hPx) async {}
