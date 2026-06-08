import 'symbology.dart';

/// Everything the sizing/rendering engine needs to produce one symbol.
class EncodeConfig {
  final Symbology symbology;

  /// The raw string to encode (already assembled from the data source —
  /// SGTIN element string, Digital Link URI, EPC URI, NSN payload or free text).
  final String data;

  final QrEcLevel ecLevel;

  /// Print resolution in dots per inch.
  final double dpi;

  /// Narrowest element width (module / X-dimension) in millimetres.
  final double xDimensionMm;

  /// Bar height in millimetres for 1D symbologies.
  final double barHeightMm;

  /// Square logo side length in millimetres (0 = no logo).
  final double logoSideMm;

  /// Safety margin applied to the EC recoverable fraction (0–1).
  final double logoSafetyMargin;

  const EncodeConfig({
    required this.symbology,
    required this.data,
    this.ecLevel = QrEcLevel.medium,
    this.dpi = 300,
    this.xDimensionMm = 0.5,
    this.barHeightMm = 15,
    this.logoSideMm = 0,
    this.logoSafetyMargin = 0.5,
  });

  EncodeConfig copyWith({
    Symbology? symbology,
    String? data,
    QrEcLevel? ecLevel,
    double? dpi,
    double? xDimensionMm,
    double? barHeightMm,
    double? logoSideMm,
    double? logoSafetyMargin,
  }) {
    return EncodeConfig(
      symbology: symbology ?? this.symbology,
      data: data ?? this.data,
      ecLevel: ecLevel ?? this.ecLevel,
      dpi: dpi ?? this.dpi,
      xDimensionMm: xDimensionMm ?? this.xDimensionMm,
      barHeightMm: barHeightMm ?? this.barHeightMm,
      logoSideMm: logoSideMm ?? this.logoSideMm,
      logoSafetyMargin: logoSafetyMargin ?? this.logoSafetyMargin,
    );
  }

  /// Number of bytes to encode (UTF-8).
  int get byteCount => data.isEmpty ? 0 : _utf8Length(data);

  static int _utf8Length(String s) {
    var len = 0;
    for (final r in s.runes) {
      if (r <= 0x7F) {
        len += 1;
      } else if (r <= 0x7FF) {
        len += 2;
      } else if (r <= 0xFFFF) {
        len += 3;
      } else {
        len += 4;
      }
    }
    return len;
  }
}
