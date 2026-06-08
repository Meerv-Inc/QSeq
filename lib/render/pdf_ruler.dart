import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ruler.dart';

/// Ready-to-place PDF ruler widgets generated as exact-DPI raster images.
class PdfRuler {
  final pw.Widget horizontal; // x-axis, [contentWmm] wide
  final pw.Widget vertical; // y-axis, [contentHmm] tall
  final pw.Widget vernier; // corner block
  final double bandMm;

  const PdfRuler({
    required this.horizontal,
    required this.vertical,
    required this.vernier,
    required this.bandMm,
  });

  static Future<PdfRuler> build(
      double contentWmm, double contentHmm, double dpi) async {
    final h = pw.MemoryImage(await Ruler.png(await Ruler.horizontal(contentWmm, dpi)));
    final v = pw.MemoryImage(await Ruler.png(await Ruler.vertical(contentHmm, dpi)));
    final c = pw.MemoryImage(await Ruler.png(await Ruler.vernier(dpi)));
    return PdfRuler(
      horizontal: pw.Image(h,
          width: contentWmm * PdfPageFormat.mm,
          height: Ruler.bandMm * PdfPageFormat.mm),
      vertical: pw.Image(v,
          width: Ruler.bandMm * PdfPageFormat.mm,
          height: contentHmm * PdfPageFormat.mm),
      vernier: pw.Image(c,
          width: Ruler.bandMm * PdfPageFormat.mm,
          height: Ruler.bandMm * PdfPageFormat.mm),
      bandMm: Ruler.bandMm,
    );
  }
}
