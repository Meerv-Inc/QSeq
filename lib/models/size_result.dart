import '../sizing/dpi.dart';
import '../sizing/logo_ec.dart';
import 'symbology.dart';

/// The computed outcome of sizing one symbol: its physical footprint, the
/// capacity picture, the logo/EC budget (2D only) and any warnings to surface.
class SizeResult {
  final Symbology symbology;

  /// Outer physical size *including* the quiet zone — the headline readout.
  final PhysicalSize outer;

  /// Printer dots per module after rounding.
  final int moduleDots;

  /// Human label for the chosen symbol geometry, e.g. "Version 7 · 45×45
  /// modules" or "Size 24×24" or "Code 128 · 134 modules".
  final String geometryLabel;

  /// Bytes the user asked to encode.
  final int bytesRequested;

  /// Capacity of the selected symbol (null for fixed-content 1D like EAN/UPC).
  final int? bytesCapacity;

  /// Logo-vs-EC budget for matrix symbologies; null for 1D.
  final LogoBudget? logoBudget;

  /// True when the data fits the symbology.
  final bool fits;

  /// Non-fatal advisories (logo over budget, 1D logo caveat, estimate notes).
  final List<String> warnings;

  const SizeResult({
    required this.symbology,
    required this.outer,
    required this.moduleDots,
    required this.geometryLabel,
    required this.bytesRequested,
    required this.bytesCapacity,
    required this.logoBudget,
    required this.fits,
    required this.warnings,
  });
}
