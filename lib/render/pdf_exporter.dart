// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/caption.dart';
import '../models/encode_config.dart';
import '../models/size_result.dart';
import '../models/symbology.dart';
import 'barcode_factory.dart';
import 'pdf_ruler.dart';

/// Exports a symbol as a vector PDF sized to its physical dimensions, so it
/// prints at exactly the computed millimetre size.
class PdfExporter {
  PdfExporter._();

  static Future<Uint8List> export(
    EncodeConfig cfg,
    SizeResult size, {
    Uint8List? logoPng,
    LabelCaption? caption,
  }) async {
    final doc = pw.Document();
    final wMm = size.outer.widthMm;
    final hMm = size.outer.heightMm;
    final hasCaption = caption != null && caption.isNotEmpty;
    // Wrap the full HRI to the code width; estimate the band height from the
    // number of wrapped lines (monospace).
    const fontPt = 6.0;
    const charWmm = fontPt * 0.62 / 2.835;
    const lineHmm = fontPt * 1.4 / 2.835;
    final charsPerLine =
        hasCaption ? (wMm / charWmm).floor().clamp(8, 9999) : 1;
    final lines =
        hasCaption ? (caption.text.length / charsPerLine).ceil().clamp(1, 99) : 0;
    final captionMm = hasCaption ? lines * lineHmm + 2 : 0.0;
    final barcode = cfg.symbology == Symbology.qrCode
        ? BarcodeFactory.build(cfg.symbology, ecLevel: cfg.ecLevel)
        : BarcodeFactory.build(cfg.symbology);

    final barcodeWidget = pw.BarcodeWidget(
      barcode: barcode,
      data: cfg.data,
      drawText: !cfg.symbology.is2D,
    );

    pw.Widget content = barcodeWidget;
    if (cfg.symbology.is2D && logoPng != null && cfg.logoSideMm > 0) {
      final logoMm = cfg.logoSideMm;
      content = pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          barcodeWidget,
          pw.Container(
            width: (logoMm + 1) * PdfPageFormat.mm,
            height: (logoMm + 1) * PdfPageFormat.mm,
            color: PdfColors.white,
            child: pw.Image(pw.MemoryImage(logoPng)),
          ),
        ],
      );
    }

    if (hasCaption) {
      content = pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: wMm * PdfPageFormat.mm,
            height: hMm * PdfPageFormat.mm,
            child: content,
          ),
          pw.Container(
            width: wMm * PdfPageFormat.mm,
            height: captionMm * PdfPageFormat.mm,
            alignment: pw.Alignment.topCenter,
            child: pw.RichText(
              textAlign: pw.TextAlign.center,
              text: pw.TextSpan(children: [
                if (caption.prefix.isNotEmpty)
                  pw.TextSpan(text: caption.prefix),
                if (caption.bold.isNotEmpty)
                  pw.TextSpan(
                      text: caption.bold,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ], style: const pw.TextStyle(fontSize: fontPt)),
            ),
          ),
        ],
      );
    }

    // Measurement rulers along the bottom (x) and right (y) edges.
    final contentWmm = wMm;
    final contentHmm = hMm + captionMm;
    final ruler = await PdfRuler.build(contentWmm, contentHmm, cfg.dpi);
    const gapMm = 3.0; // gap so rulers never touch the code
    final pageWmm = contentWmm + gapMm + ruler.bandMm;
    final pageHmm = contentHmm + gapMm + ruler.bandMm;

    final page = pw.Stack(children: [
      pw.Positioned(left: 0, top: 0, child: content),
      pw.Positioned(left: 0, bottom: 0, child: ruler.horizontal),
      pw.Positioned(right: 0, top: 0, child: ruler.vertical),
      pw.Positioned(right: 0, bottom: 0, child: ruler.vernier),
    ]);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWmm * PdfPageFormat.mm,
          pageHmm * PdfPageFormat.mm,
          marginAll: 0,
        ),
        build: (_) => pw.FullPage(ignoreMargins: true, child: page),
      ),
    );
    return doc.save();
  }
}
