// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../models/caption.dart';
import '../models/encode_config.dart';
import '../models/symbology.dart';
import '../sizing/dpi.dart';
import '../sizing/qr_capacity.dart';
import 'barcode_factory.dart';
import 'qr_structure.dart';

/// Renders a symbol to a pixel-exact [ui.Image] and to PNG bytes carrying the
/// correct physical-resolution (pHYs) metadata, so print software reports the
/// intended physical size.
class RasterRenderer {
  RasterRenderer._();

  /// Paints [cfg] to an image. For matrix codes the logo (if any) is composited
  /// into the centre dead-space. When [caption] is non-empty its text is printed
  /// in a band below the code (the bold part in bold). Returns the image plus
  /// its DPI for PNG export.
  static Future<ui.Image> render(EncodeConfig cfg,
      {ui.Image? logo, LabelCaption? caption}) async {
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi);
    final symbol = cfg.symbology.is2D
        ? await _render2d(cfg, dots, logo)
        : await _render1d(cfg, dots);
    if (caption == null || caption.isEmpty) return symbol;
    return _addCaption(symbol, caption, cfg.dpi);
  }

  /// Composes [symbol] with a caption band underneath, returning a taller image.
  static Future<ui.Image> _addCaption(
      ui.Image symbol, LabelCaption cap, double dpi) async {
    // Full human-readable interpretation, wrapped to the symbol width and set
    // off below the code with a clear gap.
    final w = symbol.width;
    final sidePad = Dpi.mmToInch(1.5) * dpi;
    final gap = (Dpi.mmToInch(2.5) * dpi).round();
    final bottomPad = (Dpi.mmToInch(1.5) * dpi).round();
    final fontSize = Dpi.mmToInch(2.2) * dpi; // ~2.2 mm, readable
    const black = Color(0xFF000000);

    final tp = TextPainter(
      text: TextSpan(children: [
        if (cap.prefix.isNotEmpty)
          TextSpan(
              text: cap.prefix,
              style: TextStyle(
                  color: black,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                  height: 1.3)),
        if (cap.bold.isNotEmpty)
          TextSpan(
              text: cap.bold,
              style: TextStyle(
                  color: black,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  height: 1.3)),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 2 * sidePad);

    final textH = tp.height.ceil();
    final h = symbol.height + gap + textH + bottomPad;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawImage(symbol, Offset.zero, Paint());
    tp.paint(canvas, Offset((w - tp.width) / 2, symbol.height + gap.toDouble()));

    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  static Future<ui.Image> _render2d(
      EncodeConfig cfg, int dots, ui.Image? logo) async {
    // Force the QR version we computed so pixels land exactly on dots.
    final Barcode barcode;
    final int? typeNumber;
    if (cfg.symbology == Symbology.qrCode) {
      typeNumber = QrCapacity.minVersionForBytes(cfg.byteCount, cfg.ecLevel);
      barcode = Barcode.qrCode(
        typeNumber: typeNumber,
        errorCorrectLevel: BarcodeFactory.qrLevel(cfg.ecLevel),
      );
    } else {
      barcode = BarcodeFactory.build(cfg.symbology);
      typeNumber = null;
    }

    // Discover the real module count from one render pass.
    final probe = barcode.make(cfg.data, width: 1000, height: 1000).toList();
    final modules = _moduleCount(probe);
    final qz = cfg.symbology.quietZoneModules;
    final contentPx = (modules * dots).toDouble();
    final pad = (qz * dots).toDouble();
    final fullPx = contentPx + 2 * pad;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintWhite = Paint()..color = const Color(0xFFFFFFFF);
    final paintBlack = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, fullPx, fullPx), paintWhite);

    canvas.save();
    canvas.translate(pad, pad);
    for (final e in barcode.make(cfg.data,
        width: contentPx, height: contentPx)) {
      if (e is BarcodeBar && e.black) {
        canvas.drawRect(
            Rect.fromLTWH(e.left, e.top, e.width, e.height), paintBlack);
      }
    }
    canvas.restore();

    if (cfg.logoSideMm > 0) {
      final logoPx = Dpi.mmToInch(cfg.logoSideMm) * cfg.dpi;
      final center = fullPx / 2;
      final dst = Rect.fromCenter(
          center: Offset(center, center), width: logoPx, height: logoPx);
      final knockout = dst.inflate(dots.toDouble());

      // Structure-aware: never erase function-pattern modules (finder, timing,
      // alignment, format/version). Build a clip = knockout MINUS the function
      // cells that fall inside it, so those modules show through the logo.
      final isFunction = _functionPredicate(cfg, typeNumber, modules);
      final clip = _deadSpaceClip(
          knockout, isFunction, modules, dots.toDouble(), pad);

      canvas.save();
      canvas.clipPath(clip);
      // White knockout reserves the dead-space even when no logo image is set.
      canvas.drawRect(knockout, paintWhite);
      if (logo != null) {
        canvas.drawImageRect(
            logo,
            Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
            dst,
            Paint());
      }
      canvas.restore();
    }

    final picture = recorder.endRecording();
    return picture.toImage(fullPx.round(), fullPx.round());
  }

  /// Predicate telling whether matrix module (row, col) is a function pattern
  /// that must survive the dead-space. QR uses the full structure map; Data
  /// Matrix function patterns (L finder + timing) live on the perimeter.
  static bool Function(int row, int col) _functionPredicate(
      EncodeConfig cfg, int? qrVersion, int modules) {
    if (cfg.symbology == Symbology.qrCode && qrVersion != null) {
      final s = QrStructure(qrVersion);
      return s.isFunction;
    }
    // Data Matrix: solid left column + bottom row, dashed top row + right col.
    return (row, col) =>
        row == 0 || col == 0 || row == modules - 1 || col == modules - 1;
  }

  /// Builds a clip path covering [knockout] minus every function-pattern cell
  /// that intersects it (cells are in content space offset by [pad]).
  static ui.Path _deadSpaceClip(Rect knockout, bool Function(int, int) isFn,
      int modules, double dots, double pad) {
    var clip = ui.Path()..addRect(knockout);
    final firstCol = (((knockout.left - pad) / dots).floor()).clamp(0, modules - 1);
    final lastCol = (((knockout.right - pad) / dots).ceil()).clamp(0, modules - 1);
    final firstRow = (((knockout.top - pad) / dots).floor()).clamp(0, modules - 1);
    final lastRow = (((knockout.bottom - pad) / dots).ceil()).clamp(0, modules - 1);
    for (var r = firstRow; r <= lastRow; r++) {
      for (var c = firstCol; c <= lastCol; c++) {
        if (!isFn(r, c)) continue;
        final cell = Rect.fromLTWH(pad + c * dots, pad + r * dots, dots, dots);
        final hole = ui.Path()..addRect(cell);
        clip = ui.Path.combine(ui.PathOperation.difference, clip, hole);
      }
    }
    return clip;
  }

  static Future<ui.Image> _render1d(EncodeConfig cfg, int dots) async {
    final barcode = BarcodeFactory.build(cfg.symbology);
    final qz = cfg.symbology.quietZoneModules;
    final pad = (qz * dots).toDouble();

    // Probe to find the natural module width of the encoded data.
    final probe = barcode
        .make(cfg.data, width: 1000, height: 100, drawText: false)
        .whereType<BarcodeBar>()
        .toList();
    final unit = _minBarWidth(probe);
    final modulesWide = (1000 / unit).round();
    final contentPx = (modulesWide * dots).toDouble();

    final barHeightPx = (Dpi.mmToInch(cfg.barHeightMm) * cfg.dpi);
    final fontHeight = barHeightPx * 0.18;
    final textPad = barHeightPx * 0.04;
    final contentHeight = barHeightPx + fontHeight + textPad;
    final fullW = contentPx + 2 * pad;
    final fullH = contentHeight + 2 * pad;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintWhite = Paint()..color = const Color(0xFFFFFFFF);
    final paintBlack = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, fullW, fullH), paintWhite);

    canvas.save();
    canvas.translate(pad, pad);
    for (final e in barcode.make(cfg.data,
        width: contentPx,
        height: contentHeight,
        drawText: true,
        fontHeight: fontHeight,
        textPadding: textPad)) {
      if (e is BarcodeBar && e.black) {
        canvas.drawRect(
            Rect.fromLTWH(e.left, e.top, e.width, e.height), paintBlack);
      } else if (e is BarcodeText) {
        _paintText(canvas, e, paintBlack.color);
      }
    }
    canvas.restore();

    final picture = recorder.endRecording();
    return picture.toImage(fullW.round(), fullH.round());
  }

  static void _paintText(Canvas canvas, BarcodeText e, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: e.text,
        style: TextStyle(
            color: color, fontSize: e.height * 0.9, fontFamily: 'monospace'),
      ),
      textAlign: switch (e.align) {
        BarcodeTextAlign.left => TextAlign.left,
        BarcodeTextAlign.right => TextAlign.right,
        BarcodeTextAlign.center => TextAlign.center,
      },
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: e.width);
    final dx = switch (e.align) {
      BarcodeTextAlign.left => e.left,
      BarcodeTextAlign.right => e.left + e.width - tp.width,
      BarcodeTextAlign.center => e.left + (e.width - tp.width) / 2,
    };
    tp.paint(canvas, Offset(dx, e.top));
  }

  /// Square matrix module count, inferred from the smallest bar dimension.
  static int _moduleCount(List<BarcodeElement> elements) {
    final bars = elements.whereType<BarcodeBar>().toList();
    final unit = _minBarWidth(bars);
    return (1000 / unit).round();
  }

  static double _minBarWidth(List<BarcodeBar> bars) {
    var minW = double.infinity;
    for (final b in bars) {
      if (b.width > 0.0001 && b.width < minW) minW = b.width;
      if (b.height > 0.0001 && b.height < minW) minW = b.height;
    }
    return minW.isFinite ? minW : 1;
  }

  /// Encodes [image] to PNG, embedding a pHYs chunk so print software reads the
  /// intended [dpi] (and therefore the correct physical size).
  static Future<Uint8List> toPng(ui.Image image, double dpi) async {
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final decoded = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: byteData!.buffer,
      numChannels: 4,
    );
    final encoder = img.PngEncoder()
      ..pixelDimensions = img.PngPhysicalPixelDimensions.dpi(dpi.round());
    return encoder.encode(decoded, singleFrame: true);
  }
}
