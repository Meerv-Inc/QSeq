// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/batch.dart';
import 'barcode_factory.dart';
import 'pdf_ruler.dart';
import 'ruler.dart';

/// Renders a [Batch] as a multi-page PDF: a grid of sequentially-numbered
/// cells (a 2D code over a 1D code, either, or both), each captioned with its
/// serial — the incrementing digits in **bold**.
class BatchPdf {
  BatchPdf._();

  static Future<Uint8List> build(Batch batch, {Uint8List? logoPng}) async {
    final doc = pw.Document();
    final fmt = _pdfFormat(batch);
    final cols = batch.columns;
    final dpi = (batch.twoDSample ?? batch.oneDSample)!.dpi;

    // Reserve a gutter on the right + bottom for the rulers so they never
    // overlay the codes (3 mm gap between content and ruler). Total reserved
    // width stays 2*marginMm so the grid (and batch.columns) still fits.
    const mm = PdfPageFormat.mm;
    final gutterMm = Ruler.bandMm + 3;
    final innerMm = batch.marginMm - gutterMm / 2;
    final outerMm = innerMm + gutterMm;
    final contentWmm = batch.effectiveWidthMm - innerMm - outerMm;
    // pageHeightMm is the finite content length even for a continuous web.
    final contentHmm = batch.pageHeightMm - innerMm - outerMm;
    final ruler = await PdfRuler.build(contentWmm, contentHmm, dpi);

    final twoDBarcode = batch.hasTwoD
        ? (batch.twoDSample!.symbology.supportsEcLevel
            ? BarcodeFactory.build(batch.twoDSample!.symbology,
                ecLevel: batch.twoDSample!.ecLevel)
            : BarcodeFactory.build(batch.twoDSample!.symbology))
        : null;
    final oneDBarcode = batch.hasOneD
        ? BarcodeFactory.build(batch.oneDSample!.symbology)
        : null;

    final rows = <List<BatchItem>>[];
    for (var i = 0; i < batch.items.length; i += cols) {
      rows.add(
          batch.items.sublist(i, (i + cols).clamp(0, batch.items.length)));
    }

    pw.Widget cell(BatchItem it) {
      final children = <pw.Widget>[];

      // Full HRI under a code: the whole encoded string, with the incrementing
      // serial in bold, wrapped to the cell width.
      pw.Widget hri(String data) {
        final tail = data.endsWith(it.counter) ? it.counter : '';
        final head =
            tail.isEmpty ? data : data.substring(0, data.length - tail.length);
        return pw.RichText(
          textAlign: pw.TextAlign.center,
          text: pw.TextSpan(children: [
            pw.TextSpan(text: head),
            if (tail.isNotEmpty)
              pw.TextSpan(
                  text: tail,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ], style: const pw.TextStyle(fontSize: 5)),
        );
      }

      if (batch.hasTwoD && it.twoDData != null) {
        final s = batch.twoDSize!.outer;
        pw.Widget twoD = pw.BarcodeWidget(
          barcode: twoDBarcode!,
          data: it.twoDData!,
          width: s.widthMm * PdfPageFormat.mm,
          height: s.heightMm * PdfPageFormat.mm,
          drawText: false,
        );
        if (logoPng != null && batch.twoDSample!.logoSideMm > 0) {
          final logoMm = batch.twoDSample!.logoSideMm;
          twoD = pw.Stack(alignment: pw.Alignment.center, children: [
            twoD,
            pw.Container(
              width: (logoMm + 1) * PdfPageFormat.mm,
              height: (logoMm + 1) * PdfPageFormat.mm,
              color: PdfColors.white,
              child: pw.Image(pw.MemoryImage(logoPng)),
            ),
          ]);
        }
        children.add(twoD);
        children.add(pw.SizedBox(height: 2 * PdfPageFormat.mm));
        children.add(hri(it.twoDData!));
      }

      if (batch.hasOneD && it.oneDData != null) {
        final s = batch.oneDSize!.outer;
        children.add(pw.SizedBox(height: 4 * PdfPageFormat.mm));
        children.add(pw.BarcodeWidget(
          barcode: oneDBarcode!,
          data: it.oneDData!,
          width: s.widthMm * PdfPageFormat.mm,
          height: s.heightMm * PdfPageFormat.mm,
          drawText: false,
        ));
        children.add(pw.SizedBox(height: 2 * PdfPageFormat.mm));
        children.add(hri(it.oneDData!));
      }

      return pw.Container(
        width: batch.cellWidthMm * PdfPageFormat.mm,
        margin: pw.EdgeInsets.all(batch.cellGapMm / 2 * PdfPageFormat.mm),
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: children),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: fmt,
          margin: pw.EdgeInsets.only(
              left: innerMm * mm,
              top: innerMm * mm,
              right: outerMm * mm,
              bottom: outerMm * mm),
          buildForeground: (context) => pw.Stack(children: [
            pw.Positioned(
                left: innerMm * mm, bottom: innerMm * mm, child: ruler.horizontal),
            pw.Positioned(
                top: innerMm * mm, right: innerMm * mm, child: ruler.vertical),
            pw.Positioned(
                right: innerMm * mm, bottom: innerMm * mm, child: ruler.vernier),
          ]),
        ),
        build: (context) => [
          for (final row in rows)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final it in row) cell(it)],
            ),
        ],
      ),
    );
    return doc.save();
  }

  /// Maps a [PageFormat] to a PDF page format. Cut sheets use the standard
  /// constants; a flexographic continuous web becomes a custom page sized to its
  /// web width × the finite length the codes actually occupy (one endless page).
  static PdfPageFormat _pdfFormat(Batch batch) {
    const mm = PdfPageFormat.mm;
    // A continuous web is sized to its web width × the finite length the codes
    // occupy; orientation does not apply (its length is already endless).
    if (batch.page.isContinuous) {
      return PdfPageFormat(batch.effectiveWidthMm * mm, batch.pageHeightMm * mm);
    }
    final base = switch (batch.page) {
      PageFormat.a4 => PdfPageFormat.a4,
      PageFormat.letter => PdfPageFormat.letter,
      PageFormat.a3 => PdfPageFormat.a3,
      PageFormat.legal => PdfPageFormat.legal,
      _ => PdfPageFormat(batch.page.widthMm * mm, batch.page.heightMm * mm),
    };
    return batch.orientation == PageOrientation.landscape
        ? base.landscape
        : base;
  }
}
