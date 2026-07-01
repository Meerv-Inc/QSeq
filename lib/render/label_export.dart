// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Exports for the label designer: a print-true raster of one designed label
// (PNG / clipboard / single-label PDF), and vector label SHEETS — the
// designed label tiled per serial — for the batch PDF.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/batch.dart';
import '../models/encode_config.dart';
import '../models/label_spec.dart';
import '../state/app_controller.dart';
import 'barcode_factory.dart';
import 'pdf_ruler.dart';
import 'raster_renderer.dart';
import 'ruler.dart';

class LabelExport {
  LabelExport._();

  /// The spec with every enabled element arranged and symbol heights locked to
  /// the true aspect (mirrors what the designer shows).
  static LabelSpec arrange(AppSettings s, LabelSpec spec, {String? serial}) {
    final t = labelTexts(s.data, serial: serial);
    final n2 = s.mode.use2D && spec.twoDOn ? _natural(s, true, t.d2) : null;
    final n1 = s.mode.use1D && spec.oneDOn ? _natural(s, false, t.d1) : null;
    final out = spec.clone();
    final missing = labelElementKeys.any((k) =>
        _on(out, s, k) && !out.rects.containsKey(k));
    if (missing) autoArrangeLabel(out, n2, n1);
    final r2 = out.rects['twoD'];
    if (r2 != null && n2 != null) r2.h = r2.w * n2.h / n2.w;
    final r1 = out.rects['oneD'];
    if (r1 != null && n1 != null) r1.h = r1.w * n1.h / n1.w;
    return out;
  }

  static bool _on(LabelSpec spec, AppSettings s, String key) => switch (key) {
        'twoD' => s.mode.use2D && spec.twoDOn,
        'oneD' => s.mode.use1D && spec.oneDOn,
        _ => spec.on(key),
      };

  static ({double w, double h})? _natural(
          AppSettings s, bool twoD, String data) =>
      naturalLabelSymbolSize(
        symbology: twoD ? s.twoDSymbology : s.oneDSymbology,
        data: data,
        ecLevel: s.ecLevel,
        dpi: s.safeDpi,
        xDimensionMm: s.safeXDimensionMm,
        barHeightMm: s.safeBarHeightMm,
      );

  /// Renders the designed label to a print-true raster at [AppSettings.dpi].
  static Future<ui.Image> renderImage(AppSettings s, LabelSpec spec,
      {String? serial, ui.Image? logo}) async {
    final a = arrange(s, spec, serial: serial);
    final t = labelTexts(s.data, serial: serial);
    final k = s.safeDpi / 25.4; // px per mm
    final w = (a.wMm * k).round(), h = (a.hMm * k).round();
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF));

    if (a.bgImagePath != null) {
      final bg = await _loadImage(a.bgImagePath!);
      if (bg != null) {
        canvas.drawImageRect(
            bg,
            ui.Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
            ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            ui.Paint());
      }
    }

    Future<void> drawSymbol(String key, bool twoD, String data) async {
      final r = a.rects[key];
      if (r == null) return;
      final cfg = EncodeConfig(
        symbology: twoD ? s.twoDSymbology : s.oneDSymbology,
        data: data,
        ecLevel: s.ecLevel,
        pdf417EcLevel: s.pdf417EcLevel,
        dpi: s.safeDpi,
        xDimensionMm: s.safeXDimensionMm,
        barHeightMm: s.safeBarHeightMm,
        logoSideMm: twoD ? s.safeLogoSideMm : 0,
        logoSafetyMargin: s.safeLogoEcBudget,
      );
      final img = await RasterRenderer.render(cfg, logo: twoD ? logo : null);
      canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH(
              0, 0, img.width.toDouble(), img.height.toDouble()),
          ui.Rect.fromLTWH(r.x * k, r.y * k, r.w * k, r.h * k),
          ui.Paint()..filterQuality = ui.FilterQuality.high);
    }

    if (s.mode.use2D && a.twoDOn) await drawSymbol('twoD', true, t.d2);
    if (s.mode.use1D && a.oneDOn) await drawSymbol('oneD', false, t.d1);

    if (a.titleOn && a.title.isNotEmpty) {
      final r = a.rects['title'];
      if (r != null) {
        final font = math.max(1.5, r.h / 1.4) * k;
        final tp = TextPainter(
          text: TextSpan(
              text: a.title,
              style: TextStyle(
                  fontSize: font,
                  fontWeight: FontWeight.w600,
                  color: const ui.Color(0xFF000000))),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.w * k);
        tp.paint(canvas, ui.Offset(r.x * k + (r.w * k - tp.width) / 2, r.y * k));
      }
    }
    if (a.hriOn) {
      final r = a.rects['hri'];
      if (r != null) {
        final fontMm = a.hriFontMm > 0
            ? a.hriFontMm.clamp(0.8, 30.0)
            : math.max(1.2, math.min(3.2, r.h / 2.6));
        final tp = TextPainter(
          text: TextSpan(
              text: t.hri,
              style: TextStyle(
                  fontSize: fontMm * k,
                  fontFamily: 'monospace',
                  color: const ui.Color(0xFF000000))),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.w * k);
        tp.paint(canvas, ui.Offset(r.x * k + (r.w * k - tp.width) / 2, r.y * k));
      }
    }
    if (a.framePrinted) {
      _dashedRect(canvas, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          math.max(1.0, a.wMm * 0.002 * k));
    }
    return rec.endRecording().toImage(w, h);
  }

  static void _dashedRect(ui.Canvas canvas, ui.Rect rect, double sw) {
    final paint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = sw;
    final inset = rect.deflate(sw / 2);
    final path = ui.Path()..addRect(inset);
    const dash = 12.0, gap = 9.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  static Future<ui.Image?> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// One designed label as a PDF page at its exact physical size ([image] is
  /// the print-true raster, optionally already wrapped with rulers).
  static Future<Uint8List> singlePdf(ui.Image image, double dpi) async {
    final doc = pw.Document();
    final png = await RasterRenderer.toPng(image, dpi);
    final wMm = image.width / dpi * 25.4;
    final hMm = image.height / dpi * 25.4;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(
          wMm * PdfPageFormat.mm, hMm * PdfPageFormat.mm,
          marginAll: 0),
      build: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(pw.MemoryImage(png),
              width: wMm * PdfPageFormat.mm, height: hMm * PdfPageFormat.mm)),
    ));
    return doc.save();
  }

  /// Label SHEETS: the designed label tiled per batch item, as a vector
  /// multi-page PDF (page size stays exactly the chosen format).
  static Future<Uint8List> sheetPdf(
      AppSettings s, LabelSpec spec, Batch batch,
      {Uint8List? logoPng}) async {
    const mm = PdfPageFormat.mm;
    final a = arrange(s, spec, serial: batch.items.first.serial);
    final doc = pw.Document();

    final fmt = batch.page.isContinuous
        ? PdfPageFormat(
            batch.effectiveWidthMm * mm, batch.pageHeightMm * mm)
        : (batch.orientation == PageOrientation.landscape
            ? PdfPageFormat(
                batch.page.heightMm * mm, batch.page.widthMm * mm)
            : PdfPageFormat(
                batch.page.widthMm * mm, batch.page.heightMm * mm));

    const margin = 10.0, cellGap = 3.0;
    // Rulers (if enabled) are carved out of the existing margin budget — a
    // gutter on the right + bottom — so the grid and pagination are unchanged.
    final includeRulers = s.rulersInExports;
    final gutterMm = Ruler.bandMm + 3;
    final innerMm = includeRulers ? margin - gutterMm / 2 : margin;
    final outerMm = includeRulers ? innerMm + gutterMm : margin;
    final pageHmm =
        batch.page.isContinuous ? batch.pageHeightMm : batch.effectiveHeightMm;
    final ruler = includeRulers
        ? await PdfRuler.build(batch.effectiveWidthMm - innerMm - outerMm,
            pageHmm - innerMm - outerMm, s.safeDpi)
        : null;
    final cols = math.max(
        1,
        ((batch.effectiveWidthMm - innerMm - outerMm + cellGap) /
                (a.wMm + cellGap))
            .floor());

    final n2 = s.mode.use2D && a.twoDOn
        ? _natural(s, true, labelTexts(s.data).d2)
        : null;

    final twoDBarcode = s.mode.use2D && a.twoDOn
        ? BarcodeFactory.build(
            s.twoDSymbology,
            ecLevel: s.ecLevel,
            pdf417EcLevel: s.pdf417EcLevel,
          )
        : null;
    final oneDBarcode = s.mode.use1D && a.oneDOn
        ? BarcodeFactory.build(s.oneDSymbology)
        : null;

    pw.Widget cell(BatchItem it) {
      final t = labelTexts(s.data, serial: it.serial);
      final children = <pw.Widget>[];
      final r2 = a.rects['twoD'];
      if (twoDBarcode != null && r2 != null) {
        pw.Widget code = pw.BarcodeWidget(
            barcode: twoDBarcode,
            data: t.d2,
            width: r2.w * mm,
            height: r2.h * mm,
            drawText: false);
        if (logoPng != null && s.safeLogoSideMm > 0 && n2 != null && n2.w > 0) {
          final frac = (s.safeLogoSideMm / n2.w).clamp(0.0, 0.9);
          code = pw.Stack(alignment: pw.Alignment.center, children: [
            code,
            pw.Container(
                width: r2.w * frac * mm,
                height: r2.w * frac * mm,
                color: PdfColors.white,
                child: pw.Image(pw.MemoryImage(logoPng))),
          ]);
        }
        children.add(
            pw.Positioned(left: r2.x * mm, top: r2.y * mm, child: code));
      }
      final r1 = a.rects['oneD'];
      if (oneDBarcode != null && r1 != null) {
        children.add(pw.Positioned(
            left: r1.x * mm,
            top: r1.y * mm,
            child: pw.BarcodeWidget(
                barcode: oneDBarcode,
                data: t.d1,
                width: r1.w * mm,
                height: r1.h * mm,
                drawText: false)));
      }
      final rt = a.rects['title'];
      if (a.titleOn && a.title.isNotEmpty && rt != null) {
        final font = math.max(1.5, rt.h / 1.4);
        children.add(pw.Positioned(
            left: rt.x * mm,
            top: rt.y * mm,
            child: pw.SizedBox(
                width: rt.w * mm,
                child: pw.Text(a.title,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: font * mm,
                        fontWeight: pw.FontWeight.bold)))));
      }
      final rh = a.rects['hri'];
      if (a.hriOn && rh != null) {
        final fontMm = a.hriFontMm > 0
            ? a.hriFontMm.clamp(0.8, 30.0)
            : math.max(1.2, math.min(3.2, rh.h / 2.6));
        children.add(pw.Positioned(
            left: rh.x * mm,
            top: rh.y * mm,
            child: pw.SizedBox(
                width: rh.w * mm,
                child: pw.Text(t.hri,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: fontMm * mm)))));
      }
      return pw.Container(
        width: a.wMm * mm,
        height: a.hMm * mm,
        margin: const pw.EdgeInsets.all(cellGap / 2 * mm),
        decoration: a.framePrinted
            ? pw.BoxDecoration(
                border: pw.Border.all(width: 0.3, color: PdfColors.black))
            : null,
        child: pw.Stack(children: children),
      );
    }

    final rows = <List<BatchItem>>[];
    for (var i = 0; i < batch.items.length; i += cols) {
      rows.add(
          batch.items.sublist(i, math.min(i + cols, batch.items.length)));
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: fmt,
        margin: pw.EdgeInsets.only(
            left: innerMm * mm,
            top: innerMm * mm,
            right: outerMm * mm,
            bottom: outerMm * mm),
        // Bleed the ruler bands into the reserved right/bottom gutter so they
        // sit at the page edge without overlapping the labels.
        buildForeground: ruler == null
            ? null
            : (context) => pw.Stack(
                  overflow: pw.Overflow.visible,
                  children: [
                    pw.Positioned(
                        left: 0,
                        bottom: -gutterMm * mm,
                        child: ruler.horizontal),
                    pw.Positioned(
                        top: 0, right: -gutterMm * mm, child: ruler.vertical),
                    pw.Positioned(
                        right: -gutterMm * mm,
                        bottom: -gutterMm * mm,
                        child: ruler.vernier),
                  ],
                ),
      ),
      build: (context) => [
        for (final row in rows)
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final it in row) cell(it)]),
      ],
    ));
    return doc.save();
  }
}
