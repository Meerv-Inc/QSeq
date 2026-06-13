// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// No-op browser-IO stubs used during server prerender (no browser APIs). The
// real implementations live in download_web.dart, selected on JS targets.
import 'dart:typed_data';

void downloadText(String filename, String text, String mime) {}

void downloadBytes(String filename, Uint8List bytes, String mime) {}

Future<void> downloadSvgPng(
    String filename, String svg, int wPx, int hPx) async {}

/// Rasterizes an SVG to a PNG data URL ([transparent] skips the white base).
Future<String?> rasterizeSvg(String svg, int wPx, int hPx,
        {bool transparent = false}) async =>
    null;

/// Opens a file picker; returns a data URL ([asText] false) or text content.
Future<String?> pickFile({String accept = '*/*', bool asText = false}) async =>
    null;

/// One PDF page: physical size + a full-page PNG data URL.
class PdfPageImage {
  final double wMm;
  final double hMm;
  final String pngDataUrl;
  const PdfPageImage(this.wMm, this.hMm, this.pngDataUrl);
}

/// Builds and downloads a PDF via jsPDF. False when jsPDF is unavailable.
Future<bool> savePdfPages(String filename, List<PdfPageImage> pages,
        [void Function(int done, int total)? onProgress]) async =>
    false;
