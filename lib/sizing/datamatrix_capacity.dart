/// One square Data Matrix (ECC 200) symbol size.
class DmSize {
  /// Modules along one side of the full symbol (includes finder/timing).
  final int modules;

  /// Number of data codewords (≈ byte capacity in base-256 mode).
  final int dataCodewords;

  /// Number of Reed–Solomon error-correction codewords (fixed by the standard).
  final int ecCodewords;

  const DmSize(this.modules, this.dataCodewords, this.ecCodewords);

  /// Approximate byte capacity. Base-256 mode spends ~1–2 codewords on the
  /// latch/length header, so we subtract a small fixed overhead.
  int get byteCapacity => (dataCodewords - 2).clamp(1, dataCodewords);

  /// The fixed built-in correction fraction = EC / (data + EC). Unlike QR this
  /// is not user-selectable.
  double get correctionFraction =>
      ecCodewords / (dataCodewords + ecCodewords);
}

/// Square Data Matrix ECC 200 size and capacity table (ISO/IEC 16022).
class DataMatrixCapacity {
  DataMatrixCapacity._();

  /// Square symbol sizes ordered smallest → largest.
  static const List<DmSize> squareSizes = [
    DmSize(10, 3, 5),
    DmSize(12, 5, 7),
    DmSize(14, 8, 10),
    DmSize(16, 12, 12),
    DmSize(18, 18, 14),
    DmSize(20, 22, 18),
    DmSize(22, 30, 20),
    DmSize(24, 36, 24),
    DmSize(26, 44, 28),
    DmSize(32, 62, 36),
    DmSize(36, 86, 42),
    DmSize(40, 114, 48),
    DmSize(44, 144, 56),
    DmSize(48, 174, 68),
    DmSize(52, 204, 84),
    DmSize(64, 280, 112),
    DmSize(72, 368, 144),
    DmSize(80, 456, 192),
    DmSize(88, 576, 224),
    DmSize(96, 696, 272),
    DmSize(104, 816, 336),
    DmSize(120, 1050, 408),
    DmSize(132, 1304, 496),
    DmSize(144, 1558, 620),
  ];

  /// Smallest square size whose byte capacity holds [byteCount], or null if it
  /// exceeds the largest symbol.
  static DmSize? minSizeForBytes(int byteCount) {
    for (final s in squareSizes) {
      if (s.byteCapacity >= byteCount) return s;
    }
    return null;
  }
}
