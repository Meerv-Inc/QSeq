/// Unit conversions tying module counts, X-dimension, DPI and physical size
/// together. This is the engine behind the live "outer perimeter" readout.
class Dpi {
  Dpi._();

  static const double mmPerInch = 25.4;

  static double mmToInch(double mm) => mm / mmPerInch;
  static double inchToMm(double inch) => inch * mmPerInch;

  /// Number of printer dots used to render one module (one X-dimension),
  /// rounded to a whole number of dots and never below 1.
  ///
  /// [xDimensionMm] is the narrowest element width; [dpi] the print resolution.
  static int moduleDots(double xDimensionMm, double dpi) {
    final dots = (mmToInch(xDimensionMm) * dpi).round();
    return dots < 1 ? 1 : dots;
  }

  /// The realised X-dimension in millimetres after rounding the module to a
  /// whole number of dots — the *actual* printed module size.
  static double effectiveXDimensionMm(double xDimensionMm, double dpi) =>
      inchToMm(moduleDots(xDimensionMm, dpi) / dpi);
}

/// A physical extent in both millimetres and inches, plus the pixel grid that
/// produces it at a given DPI.
class PhysicalSize {
  final double widthMm;
  final double heightMm;
  final int widthPx;
  final int heightPx;
  final double dpi;

  const PhysicalSize({
    required this.widthMm,
    required this.heightMm,
    required this.widthPx,
    required this.heightPx,
    required this.dpi,
  });

  double get widthInch => Dpi.mmToInch(widthMm);
  double get heightInch => Dpi.mmToInch(heightMm);

  /// Builds a [PhysicalSize] from a module grid: [widthModules] × [heightModules]
  /// modules, each [moduleDots] printer dots, at [dpi].
  factory PhysicalSize.fromModules({
    required int widthModules,
    required int heightModules,
    required int moduleDots,
    required double dpi,
  }) {
    final wpx = widthModules * moduleDots;
    final hpx = heightModules * moduleDots;
    return PhysicalSize(
      widthMm: Dpi.inchToMm(wpx / dpi),
      heightMm: Dpi.inchToMm(hpx / dpi),
      widthPx: wpx,
      heightPx: hpx,
      dpi: dpi,
    );
  }

  String get mm =>
      '${widthMm.toStringAsFixed(2)} × ${heightMm.toStringAsFixed(2)} mm';
  String get inch =>
      '${widthInch.toStringAsFixed(3)} × ${heightInch.toStringAsFixed(3)} in';
  String get px => '$widthPx × $heightPx px';
}
