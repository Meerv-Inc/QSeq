// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// Pure bridge from the generator's form state to qseq_core (DataSourceInput +
// Sizer) and the `barcode` package (SVG). Pure Dart — runs on the server during
// prerender AND in the browser, so the symbol appears in the prerendered HTML.
import 'package:barcode/barcode.dart';
import 'package:qseq_core/qseq_core.dart';

class GenInput {
  final bool oneD; // false = 2D workspace
  final DataSourceInput data; // qseq_core: encodes SGTIN/NSN/text
  final Symbology twoD; // qrCode | dataMatrix
  final Symbology oneDSym; // gs1_128 | code128 | code39 | ean13 | upcA
  final QrEcLevel ec;
  final double dpi;
  final double xdim;
  final double barh;

  const GenInput({
    required this.oneD,
    required this.data,
    required this.twoD,
    required this.oneDSym,
    required this.ec,
    required this.dpi,
    required this.xdim,
    required this.barh,
  });

  Symbology get symbology => oneD ? oneDSym : twoD;
}

class GenOutput {
  final String? svg;
  final SizeResult? size;
  final String data;
  final String? error;
  const GenOutput({this.svg, this.size, this.data = '', this.error});
}

Barcode _barcode(GenInput i) {
  if (!i.oneD) {
    return i.twoD == Symbology.qrCode
        ? Barcode.qrCode(errorCorrectLevel: _ec(i.ec))
        : Barcode.dataMatrix();
  }
  switch (i.oneDSym) {
    case Symbology.gs1_128:
      return Barcode.gs128();
    case Symbology.code128:
      return Barcode.code128();
    case Symbology.code39:
      return Barcode.code39();
    case Symbology.ean13:
      return Barcode.ean13();
    case Symbology.upcA:
      return Barcode.upcA();
    default:
      return Barcode.code128();
  }
}

BarcodeQRCorrectionLevel _ec(QrEcLevel l) => switch (l) {
      QrEcLevel.low => BarcodeQRCorrectionLevel.low,
      QrEcLevel.medium => BarcodeQRCorrectionLevel.medium,
      QrEcLevel.quartile => BarcodeQRCorrectionLevel.quartile,
      QrEcLevel.high => BarcodeQRCorrectionLevel.high,
    };

/// Produces the symbol SVG + the print-true sizing readout, or an error.
GenOutput generate(GenInput i) {
  final resolved = i.data.resolve();
  if (resolved.error != null) return GenOutput(error: resolved.error);
  final data = resolved.data ?? '';
  if (data.isEmpty) return const GenOutput(error: 'No data to encode.');
  try {
    final bc = _barcode(i);
    final is1d = i.oneD;
    final svg = bc.toSvg(
      data,
      width: is1d ? 360 : 300,
      height: is1d ? 130 : 300,
      drawText: is1d,
      color: 0x000000,
    );
    SizeResult? size;
    try {
      size = Sizer.compute(EncodeConfig(
        symbology: i.symbology,
        data: data,
        ecLevel: i.ec,
        dpi: i.dpi,
        xDimensionMm: i.xdim,
        barHeightMm: i.barh,
      ));
    } catch (_) {}
    return GenOutput(svg: svg, size: size, data: data);
  } catch (e) {
    return GenOutput(
      data: data,
      error: e is FormatException ? e.message : e.toString(),
    );
  }
}

class SheetOutput {
  final String? svg;
  final int count;
  final double width;
  final double height;
  final String? error;
  const SheetOutput(
      {this.svg, this.count = 0, this.width = 0, this.height = 0, this.error});
}

String _xml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Composes a serialized sheet: [count] codes (each serial = prefix + a
/// zero-padded incrementing number) tiled into one SVG, captioned with the
/// serial. Pure Dart — same on server and client.
SheetOutput buildSheet(
  GenInput i, {
  required String prefix,
  required int start,
  required int count,
  required int pad,
  int cols = 6,
}) {
  if (count < 1) return const SheetOutput(error: 'Count must be at least 1.');
  count = count.clamp(1, 2000);
  final is1d = i.oneD;
  final codeW = is1d ? 200.0 : 120.0;
  final codeH = is1d ? 86.0 : 120.0;
  const capH = 16.0;
  const padCell = 12.0;
  final cellW = codeW + padCell;
  final cellH = codeH + capH + padCell;
  final rows = (count / cols).ceil();
  final totalW = cols * cellW;
  final totalH = rows * cellH;
  final bc = _barcode(i);
  final b = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" width="$totalW" '
        'height="$totalH" viewBox="0 0 $totalW $totalH">')
    ..write('<rect width="$totalW" height="$totalH" fill="#ffffff"/>');
  try {
    for (var n = 0; n < count; n++) {
      final serial = '$prefix${(start + n).toString().padLeft(pad, '0')}';
      final data = i.data.encodeWith(serial: serial);
      final cell =
          bc.toSvg(data, width: codeW, height: codeH, drawText: is1d, color: 0x000000);
      final x = (n % cols) * cellW + padCell / 2;
      final y = (n ~/ cols) * cellH + padCell / 2;
      b
        ..write('<g transform="translate($x,$y)">')
        ..write(cell)
        ..write('<text x="${codeW / 2}" y="${codeH + 12}" font-family="monospace" '
            'font-size="11" text-anchor="middle" fill="#000">${_xml(serial)}</text>')
        ..write('</g>');
    }
  } catch (e) {
    return SheetOutput(error: e is FormatException ? e.message : e.toString());
  }
  b.write('</svg>');
  return SheetOutput(
      svg: b.toString(), count: count, width: totalW, height: totalH);
}
