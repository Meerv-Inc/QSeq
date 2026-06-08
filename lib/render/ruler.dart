// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

/// Draws exact-DPI measurement rulers — millimetres and inches with fine
/// (vernier) ticks — so a printed sheet can be checked against a physical
/// ruler. The same raster is composited onto PNG output and embedded into PDFs.
class Ruler {
  Ruler._();

  /// Thickness of a ruler band, in millimetres.
  static const double bandMm = 13;

  static const Color _black = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);

  static double _pxPerMm(double dpi) => dpi / 25.4;

  // --- public raster generators -------------------------------------------

  /// A horizontal ruler band [lengthMm] long.
  static Future<ui.Image> horizontal(double lengthMm, double dpi) {
    final ppm = _pxPerMm(dpi);
    final w = (lengthMm * ppm).round();
    final h = (bandMm * ppm).round();
    return _record(w, h, (canvas) => _paintHorizontal(canvas, w, h, dpi));
  }

  /// A vertical ruler band [lengthMm] tall.
  static Future<ui.Image> vertical(double lengthMm, double dpi) {
    final ppm = _pxPerMm(dpi);
    final w = (bandMm * ppm).round();
    final h = (lengthMm * ppm).round();
    return _record(w, h, (canvas) => _paintVertical(canvas, w, h, dpi));
  }

  /// A small vernier reference block (10 divisions over 9 mm → 0.1 mm reading).
  static Future<ui.Image> vernier(double dpi) {
    final ppm = _pxPerMm(dpi);
    final side = (bandMm * ppm).round();
    return _record(side, side, (canvas) => _paintVernier(canvas, side, dpi));
  }

  /// Composites bottom (x-axis) and right (y-axis) rulers plus a corner vernier
  /// onto [content]. Used for PNG export.
  static Future<ui.Image> addRulers(ui.Image content, double dpi) async {
    final ppm = _pxPerMm(dpi);
    final band = (bandMm * ppm).round();
    final w = content.width + band;
    final h = content.height + band;
    return _record(w, h, (canvas) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = _white);
      canvas.drawImage(content, Offset.zero, Paint());
      // Bottom x-axis ruler.
      canvas.save();
      canvas.translate(0, content.height.toDouble());
      _paintHorizontal(canvas, content.width, band, dpi);
      canvas.restore();
      // Right y-axis ruler.
      canvas.save();
      canvas.translate(content.width.toDouble(), 0);
      _paintVertical(canvas, band, content.height, dpi);
      canvas.restore();
      // Corner vernier.
      canvas.save();
      canvas.translate(content.width.toDouble(), content.height.toDouble());
      _paintVernier(canvas, band, dpi);
      canvas.restore();
    });
  }

  /// PNG bytes of an image (no DPI metadata needed; sized in the document).
  static Future<Uint8List> png(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final decoded = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: data!.buffer,
        numChannels: 4);
    return img.PngEncoder().encode(decoded);
  }

  // --- painters ------------------------------------------------------------

  static Future<ui.Image> _record(
      int w, int h, void Function(Canvas) paint) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = _white);
    paint(canvas);
    return recorder.endRecording().toImage(w, h);
  }

  static Paint _stroke(double dpi, double mm) => Paint()
    ..color = _black
    ..strokeWidth = (_pxPerMm(dpi) * mm).clamp(0.6, 6).toDouble();

  static void _paintHorizontal(Canvas canvas, int lengthPx, int bandPx,
      double dpi) {
    final ppm = _pxPerMm(dpi);
    final lengthMm = lengthPx / ppm;
    final thin = _stroke(dpi, 0.12);
    final thick = _stroke(dpi, 0.18);

    // Millimetre scale (top of band, ticks downward).
    for (var i = 0; i <= lengthMm.floor(); i++) {
      final x = i * ppm;
      final major = i % 10 == 0;
      final med = i % 5 == 0;
      final len = (major ? 3.6 : (med ? 2.3 : 1.3)) * ppm;
      canvas.drawLine(Offset(x, 0), Offset(x, len), major ? thick : thin);
      if (major && i > 0) {
        _label(canvas, '$i', x + 1.0 * ppm, 0.4 * ppm, ppm, false);
      }
    }
    _label(canvas, 'mm', 0.6 * ppm, 0.3 * ppm, ppm, false, bold: true);

    // Inch scale (bottom of band, ticks upward), 1/16" resolution.
    final sixteenths = (lengthMm / 25.4 * 16).floor();
    for (var j = 0; j <= sixteenths; j++) {
      final x = j * dpi / 16;
      final major = j % 16 == 0;
      final half = j % 8 == 0;
      final quarter = j % 4 == 0;
      final len = (major ? 3.6 : (half ? 2.6 : (quarter ? 1.9 : 1.1))) * ppm;
      canvas.drawLine(
          Offset(x, bandPx - len), Offset(x, bandPx.toDouble()),
          major ? thick : thin);
      if (major && j > 0) {
        _label(canvas, '${j ~/ 16}"', x + 1.0 * ppm, bandPx - 3.4 * ppm, ppm,
            false);
      }
    }
    _label(canvas, 'in', 0.6 * ppm, bandPx - 3.4 * ppm, ppm, false, bold: true);
  }

  static void _paintVertical(Canvas canvas, int bandPx, int lengthPx,
      double dpi) {
    final ppm = _pxPerMm(dpi);
    final lengthMm = lengthPx / ppm;
    final thin = _stroke(dpi, 0.12);
    final thick = _stroke(dpi, 0.18);

    // Millimetre scale (left edge, ticks rightward).
    for (var i = 0; i <= lengthMm.floor(); i++) {
      final y = i * ppm;
      final major = i % 10 == 0;
      final med = i % 5 == 0;
      final len = (major ? 3.6 : (med ? 2.3 : 1.3)) * ppm;
      canvas.drawLine(Offset(0, y), Offset(len, y), major ? thick : thin);
      if (major && i > 0) {
        _label(canvas, '$i', 0.4 * ppm, y + 0.3 * ppm, ppm, false);
      }
    }

    // Inch scale (right edge, ticks leftward).
    final sixteenths = (lengthMm / 25.4 * 16).floor();
    for (var j = 0; j <= sixteenths; j++) {
      final y = j * dpi / 16;
      final major = j % 16 == 0;
      final half = j % 8 == 0;
      final quarter = j % 4 == 0;
      final len = (major ? 3.6 : (half ? 2.6 : (quarter ? 1.9 : 1.1))) * ppm;
      canvas.drawLine(
          Offset(bandPx - len, y), Offset(bandPx.toDouble(), y),
          major ? thick : thin);
      if (major && j > 0) {
        _label(canvas, '${j ~/ 16}"', bandPx - 3.2 * ppm, y + 0.3 * ppm, ppm,
            false);
      }
    }
  }

  /// A vernier scale: 10 divisions spanning 9 mm, so alignment reads to 0.1 mm.
  static void _paintVernier(Canvas canvas, int sidePx, double dpi) {
    final ppm = _pxPerMm(dpi);
    final thin = _stroke(dpi, 0.12);
    final thick = _stroke(dpi, 0.2);
    final x0 = 1.0 * ppm;
    final yTop = 2.0 * ppm;
    canvas.drawLine(Offset(x0, yTop), Offset(x0 + 9 * ppm, yTop), thick);
    for (var k = 0; k <= 10; k++) {
      final x = x0 + k * 0.9 * ppm; // 10 divisions over 9 mm
      canvas.drawLine(Offset(x, yTop), Offset(x, yTop + 2.0 * ppm),
          k % 5 == 0 ? thick : thin);
      if (k % 5 == 0) {
        _label(canvas, '$k', x - 0.4 * ppm, yTop + 2.1 * ppm, ppm, false);
      }
    }
    _label(canvas, 'vernier 0.1mm', x0, yTop + 4.4 * ppm, ppm, false,
        bold: true);
  }

  static void _label(Canvas canvas, String text, double x, double y,
      double ppm, bool _,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _black,
          fontSize: 2.4 * ppm,
          fontFamily: 'monospace',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }
}
