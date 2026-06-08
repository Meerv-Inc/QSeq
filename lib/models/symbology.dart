/// The barcode symbologies the app can generate, plus their geometric traits
/// used by the sizing engine.
enum Symbology {
  qrCode('QR Code', is2D: true, quietZoneModules: 4),
  dataMatrix('Data Matrix', is2D: true, quietZoneModules: 1),
  gs1_128('GS1-128', is2D: false, quietZoneModules: 10),
  code128('Code 128', is2D: false, quietZoneModules: 10),
  code39('Code 39', is2D: false, quietZoneModules: 10),
  ean13('EAN-13', is2D: false, quietZoneModules: 11),
  upcA('UPC-A', is2D: false, quietZoneModules: 9);

  const Symbology(
    this.displayName, {
    required this.is2D,
    required this.quietZoneModules,
  });

  final String displayName;

  /// True for matrix symbologies (QR, Data Matrix) where a centre logo
  /// dead-space is meaningful; false for 1D where a logo must sit outside the
  /// bars.
  final bool is2D;

  /// Quiet-zone width in modules applied to each side when computing the outer
  /// perimeter. For 1D this is the horizontal quiet zone.
  final int quietZoneModules;

  /// Only QR exposes a user-selectable error-correction level.
  bool get supportsEcLevel => this == Symbology.qrCode;

  /// 1D symbologies carry GS1 Application Identifier data via FNC1.
  bool get isGs1 => this == Symbology.gs1_128;
}

/// QR error-correction levels with their nominal recoverable codeword fraction
/// (ISO/IEC 18004). These drive both capacity selection and the logo
/// dead-space budget.
enum QrEcLevel {
  low('L', 0.07),
  medium('M', 0.15),
  quartile('Q', 0.25),
  high('H', 0.30);

  const QrEcLevel(this.label, this.recoverableFraction);

  final String label;

  /// Approximate fraction of codewords that can be lost and still recovered.
  final double recoverableFraction;
}
