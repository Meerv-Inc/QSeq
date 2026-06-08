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

  /// Wraps the barcode [inner] SVG (W×[h]) in an outer SVG with a caption band.
  static String _wrapWithCaption(
      String inner, double width, double h, LabelCaption cap) {
    final band = (h * 0.16).clamp(14.0, 60.0);
    final total = h + band;
    final fontSize = band * 0.62;
    final y = h + band * 0.7;
    final prefix = _esc(cap.prefix);
    final bold = _esc(cap.bold);
    final tspans = [
      if (prefix.isNotEmpty) '<tspan>$prefix</tspan>',
      if (bold.isNotEmpty) '<tspan font-weight="bold">$bold</tspan>',
    ].join();
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$width" height="$total" viewBox="0 0 $width $total">'
        '$inner'
        '<text x="${width / 2}" y="$y" text-anchor="middle" '
        'font-family="monospace" font-size="$fontSize" fill="#000000">'
        '$tspans</text>'
        '</svg>';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
