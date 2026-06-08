import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/batch.dart';
import 'barcode_factory.dart';
import 'pdf_ruler.dart';

/// Renders a [Batch] as a multi-page PDF: a grid of sequentially-numbered
/// cells (a 2D code over a 1D code, either, or both), each captioned with its
/// serial — the incrementing digits in **bold**.
class BatchPdf {
  BatchPdf._();

  static Future<Uint8List> build(Batch batch, {Uint8List? logoPng}) async {
    final doc = pw.Document();
    final fmt =
        batch.page == PageFormat.a4 ? PdfPageFormat.a4 : PdfPageFormat.letter;
    final margin = batch.marginMm * PdfPageFormat.mm;
    final cols = batch.columns;
    final dpi = (batch.twoDSample ?? batch.oneDSample)!.dpi;

    // Page-edge measurement rulers (x and y) drawn on every page.
    final contentWmm = batch.page.widthMm - 2 * batch.marginMm;
    final contentHmm = batch.page.heightMm - 2 * batch.marginMm;
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
      }

      if (batch.hasOneD && it.oneDData != null) {
        final s = batch.oneDSize!.outer;
        if (children.isNotEmpty) {
          children.add(pw.SizedBox(height: batch.gapMm * PdfPageFormat.mm));
        }
        children.add(pw.BarcodeWidget(
          barcode: oneDBarcode!,
          data: it.oneDData!,
          width: s.widthMm * PdfPageFormat.mm,
          height: s.heightMm * PdfPageFormat.mm,
          drawText: false,
        ));
      }

      children.add(pw.SizedBox(height: 2));
      children.add(pw.RichText(
        textAlign: pw.TextAlign.center,
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: it.prefix,
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.normal)),
          pw.TextSpan(
              text: it.counter,
              style:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ]),
      ));

      return pw.Container(
        width: batch.cellWidthMm * PdfPageFormat.mm,
        margin: pw.EdgeInsets.all(batch.cellGapMm / 2 * PdfPageFormat.mm),
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: children),
      );
    }

    const mm = PdfPageFormat.mm;
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: fmt,
          margin: pw.EdgeInsets.all(margin),
          buildForeground: (context) => pw.Stack(children: [
            pw.Positioned(
                left: margin, bottom: 2 * mm, child: ruler.horizontal),
            pw.Positioned(top: margin, right: 2 * mm, child: ruler.vertical),
            pw.Positioned(right: 2 * mm, bottom: 2 * mm, child: ruler.vernier),
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
}
