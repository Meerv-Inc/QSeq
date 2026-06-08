import '../encoders/sgtin.dart';
import '../sizing/dpi.dart';
import '../sizing/sizer.dart';
import 'encode_config.dart';
import 'size_result.dart';
import 'symbology.dart';

/// How the 1D and 2D symbols are arranged on the combined label.
enum LabelArrangement {
  stacked('Stacked'),
  sideBySide('Side by side');

  const LabelArrangement(this.label);
  final String label;
}

/// A label that pairs a 1D symbol (GS1-128 carrying the SGTIN element string)
/// with a 2D symbol (QR or Data Matrix carrying the GS1 Digital Link) for the
/// *same* item — the larger label combining both, as used on logistics units.
class CombinedLabel {
  final EncodeConfig oneD;
  final EncodeConfig twoD;
  final SizeResult oneDSize;
  final SizeResult twoDSize;
  final LabelArrangement arrangement;
  final double gapMm;
  final double paddingMm;

  const CombinedLabel({
    required this.oneD,
    required this.twoD,
    required this.oneDSize,
    required this.twoDSize,
    required this.arrangement,
    required this.gapMm,
    required this.paddingMm,
  });

  /// Builds both symbols from a shared SGTIN plus shared print settings.
  factory CombinedLabel.fromSgtin({
    required Sgtin sgtin,
    required Symbology twoDSymbology, // qrCode or dataMatrix
    required String digitalLinkDomain,
    required double dpi,
    required double xDimensionMm,
    required double barHeightMm,
    required QrEcLevel ecLevel,
    required LabelArrangement arrangement,
    required double gapMm,
    required double paddingMm,
    double logoSideMm = 0,
  }) {
    final oneD = EncodeConfig(
      symbology: Symbology.gs1_128,
      data: sgtin.toElementString(),
      dpi: dpi,
      xDimensionMm: xDimensionMm,
      barHeightMm: barHeightMm,
    );
    final twoD = EncodeConfig(
      symbology: twoDSymbology,
      data: sgtin.toDigitalLink(domain: digitalLinkDomain),
      dpi: dpi,
      xDimensionMm: xDimensionMm,
      ecLevel: ecLevel,
      logoSideMm: logoSideMm,
    );
    return CombinedLabel(
      oneD: oneD,
      twoD: twoD,
      oneDSize: Sizer.compute(oneD),
      twoDSize: Sizer.compute(twoD),
      arrangement: arrangement,
      gapMm: gapMm,
      paddingMm: paddingMm,
    );
  }

  /// The overall outer size of the label including the gap and outer padding.
  PhysicalSize get outer {
    final dpi = oneD.dpi;
    final a = oneDSize.outer;
    final b = twoDSize.outer;
    final padPx = (Dpi.mmToInch(paddingMm) * dpi).round();
    final gapPx = (Dpi.mmToInch(gapMm) * dpi).round();

    final int wPx;
    final int hPx;
    if (arrangement == LabelArrangement.stacked) {
      wPx = [a.widthPx, b.widthPx].reduce((x, y) => x > y ? x : y) + 2 * padPx;
      hPx = a.heightPx + b.heightPx + gapPx + 2 * padPx;
    } else {
      wPx = a.widthPx + b.widthPx + gapPx + 2 * padPx;
      hPx = [a.heightPx, b.heightPx].reduce((x, y) => x > y ? x : y) + 2 * padPx;
    }
    return PhysicalSize(
      widthMm: Dpi.inchToMm(wPx / dpi),
      heightMm: Dpi.inchToMm(hPx / dpi),
      widthPx: wPx,
      heightPx: hPx,
      dpi: dpi,
    );
  }

  /// Aggregated warnings from both symbols.
  List<String> get warnings => [...oneDSize.warnings, ...twoDSize.warnings];
}
