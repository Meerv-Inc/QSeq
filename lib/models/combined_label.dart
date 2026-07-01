// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import '../encoders/sgtin.dart';
import '../sizing/dpi.dart';
import '../sizing/pdf417_capacity.dart';
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
    required Symbology twoDSymbology, // qrCode, dataMatrix or pdf417
    required String digitalLinkDomain,
    required double dpi,
    required double xDimensionMm,
    required double barHeightMm,
    required QrEcLevel ecLevel,
    required LabelArrangement arrangement,
    required double gapMm,
    required double paddingMm,
    double logoSideMm = 0,
    Pdf417EcLevel pdf417EcLevel = Pdf417EcLevel.level2,
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
      pdf417EcLevel: pdf417EcLevel,
      logoSideMm: logoSideMm,
    );
    return CombinedLabel(
      oneD: oneD,
      twoD: twoD,
      oneDSize: Sizer.compute(oneD),
      twoDSize: Sizer.compute(twoD),
      // PDF417 is already wide on its own; side by side with a 1D code
      // would make the combined label excessively wide, so force the
      // vertical layout regardless of the user's Arrangement choice.
      arrangement: twoDSymbology == Symbology.pdf417
          ? LabelArrangement.stacked
          : arrangement,
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
