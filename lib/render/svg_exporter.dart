// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:convert';
import 'dart:typed_data';

import '../models/caption.dart';
import '../models/encode_config.dart';
import '../models/symbology.dart';
import 'barcode_factory.dart';

/// Produces scalable SVG output. For matrix codes a centre logo can be embedded
/// as a base64 PNG with a white knockout behind it.
class SvgExporter {
  SvgExporter._();

  /// Returns an SVG string for [cfg]. [logoPng] (optional) is embedded centred
  /// at [cfg.logoSideMm] scaled into the symbol's coordinate space.
  /// [logoFraction] is the logo side as a fraction of the symbol side (0–1),
  /// taken from the computed [SizeResult] so SVG matches the raster preview.
  static String export(
    EncodeConfig cfg, {
    double width = 600,
    double? height,
    Uint8List? logoPng,
    double logoFraction = 0.2,
    LabelCaption? caption,
  }) {
    final h = height ?? (cfg.symbology.is2D ? width : width * 0.4);
    final barcode = cfg.symbology == Symbology.qrCode
        ? BarcodeFactory.build(cfg.symbology, ecLevel: cfg.ecLevel)
        : BarcodeFactory.build(cfg.symbology);

    var svg = barcode.toSvg(
      cfg.data,
      width: width,
      height: h,
      drawText: !cfg.symbology.is2D,
    );

    if (cfg.symbology.is2D && logoPng != null && cfg.logoSideMm > 0) {
      // Logo side as a fraction of the symbol: reuse the on-screen ratio by
      // mapping logoSideMm against the symbol's physical side via the caller's
      // proportion (logoSideMm relative to a nominal symbol size is applied as
      // a fraction of `width`). We size it as the requested fraction of width.
      final side = width * logoFraction.clamp(0.0, 0.5);
      final x = (width - side) / 2;
      final y = (h - side) / 2;
      final b64 = base64Encode(logoPng);
      final overlay = '<rect x="${x - 2}" y="${y - 2}" '
          'width="${side + 4}" height="${side + 4}" fill="#ffffff"/>'
          '<image x="$x" y="$y" width="$side" height="$side" '
          'href="data:image/png;base64,$b64"/>';
      svg = svg.replaceFirst('</svg>', '$overlay</svg>');
    }

    if (caption != null && caption.isNotEmpty) {
      svg = _wrapWithCaption(svg, width, h, caption);
    }
    return svg;
  }

  /// Wraps the barcode [inner] SVG (W×[h]) in an outer SVG with the full HRI
  /// caption below it, broken onto as many lines as needed.
  static String _wrapWithCaption(
      String inner, double width, double h, LabelCaption cap) {
    final full = cap.text;
    final fontSize = (width * 0.03).clamp(9.0, 20.0);
    final charW = fontSize * 0.62;
    final cpl = ((width * 0.96) / charW).floor().clamp(8, 99999);
    final lines = <String>[];
    for (var i = 0; i < full.length; i += cpl) {
      lines.add(full.substring(i, (i + cpl).clamp(0, full.length)));
    }
    final lineH = fontSize * 1.4;
    final gap = fontSize * 0.8;
    final band = gap + lines.length * lineH + fontSize * 0.5;
    final total = h + band;
    final texts = StringBuffer();
    for (var k = 0; k < lines.length; k++) {
      final y = h + gap + (k + 1) * lineH - lineH * 0.25;
      texts.write('<text x="${width / 2}" y="$y" text-anchor="middle" '
          'font-family="monospace" font-size="$fontSize" fill="#000000">'
          '${_esc(lines[k])}</text>');
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$width" height="$total" viewBox="0 0 $width $total">'
        '$inner$texts</svg>';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
