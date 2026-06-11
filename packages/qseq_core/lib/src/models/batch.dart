// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:math' as math;

import 'encode_config.dart';
import 'size_result.dart';
import 'symbology.dart';
import '../sizing/sizer.dart';

/// Paper sizes for batch sheets. Cut sheets have a finite height; flexographic
/// continuous webs have an infinite height ([heightMm] = `double.infinity`) —
/// codes flow down one endless page of the given web width.
enum PageFormat {
  a4('A4', 210, 297),
  letter('US Letter', 215.9, 279.4),
  a3('A3', 297, 420),
  legal('US Legal', 215.9, 355.6),
  flexo12in('Flexo 12 in × continuous', 304.8, double.infinity),
  flexo24in('Flexo 24 in × continuous', 609.6, double.infinity),
  flexo36in('Flexo 36 in × continuous', 914.4, double.infinity),
  flexo12cm('Flexo 12 cm × continuous', 120, double.infinity),
  flexo24cm('Flexo 24 cm × continuous', 240, double.infinity),
  flexo36cm('Flexo 36 cm × continuous', 360, double.infinity);

  const PageFormat(this.label, this.widthMm, this.heightMm);
  final String label;
  final double widthMm;
  final double heightMm;

  /// True for a flexographic continuous web (endless length).
  bool get isContinuous => !heightMm.isFinite;
}

/// Portrait (default) or landscape. Landscape swaps a cut sheet's width and
/// height; it has no effect on a continuous web (its length is already endless).
enum PageOrientation { portrait, landscape }

/// One sequentially-numbered cell in a batch. [prefix] renders in a normal
/// weight and [counter] (the incrementing digits) renders in bold. A cell can
/// carry a 1D payload, a 2D payload, or both (stacked 2D over 1D).
class BatchItem {
  final int index;
  final int number;
  final String prefix;
  final String counter;
  final String? oneDData;
  final String? twoDData;

  const BatchItem({
    required this.index,
    required this.number,
    required this.prefix,
    required this.counter,
    required this.oneDData,
    required this.twoDData,
  });

  String get serial => '$prefix$counter';
}

/// Generates a run of sequentially-numbered cells (1D and/or 2D) and computes
/// how they tile onto a printed page.
class Batch {
  final List<BatchItem> items;
  final EncodeConfig? oneDSample;
  final EncodeConfig? twoDSample;
  final SizeResult? oneDSize;
  final SizeResult? twoDSize;
  final PageFormat page;
  final PageOrientation orientation;
  final double marginMm;
  final double gapMm; // gap between the 2D and 1D within a cell
  final double cellGapMm; // gap between cells on the sheet
  final double captionMm;
  final int columnsOverride;

  Batch._({
    required this.items,
    required this.oneDSample,
    required this.twoDSample,
    required this.oneDSize,
    required this.twoDSize,
    required this.page,
    required this.orientation,
    required this.marginMm,
    required this.gapMm,
    required this.cellGapMm,
    required this.captionMm,
    required this.columnsOverride,
  });

  bool get hasOneD => oneDSample != null;
  bool get hasTwoD => twoDSample != null;

  factory Batch.build({
    required bool use1D,
    required bool use2D,
    required Symbology oneDSymbology,
    required Symbology twoDSymbology,
    required String prefix,
    required int start,
    required int count,
    required int padding,
    required String Function(String fullSerial) buildOneD,
    required String Function(String fullSerial) buildTwoD,
    required QrEcLevel ecLevel,
    required double dpi,
    required double xDimensionMm,
    required double barHeightMm,
    required double logoSideMm,
    required double logoEcBudget,
    required PageFormat page,
    PageOrientation orientation = PageOrientation.portrait,
    double marginMm = 16, // leaves room for the edge measurement rulers
    double gapMm = 2,
    double cellGapMm = 4,
    double captionMm = 5,
    int columnsOverride = 0,
  }) {
    final items = <BatchItem>[];
    for (var i = 0; i < count; i++) {
      final number = start + i;
      final counter = number.toString().padLeft(padding, '0');
      final full = '$prefix$counter';
      items.add(BatchItem(
        index: i,
        number: number,
        prefix: prefix,
        counter: counter,
        oneDData: use1D ? buildOneD(full) : null,
        twoDData: use2D ? buildTwoD(full) : null,
      ));
    }

    EncodeConfig? oneDSample;
    EncodeConfig? twoDSample;
    if (use1D && items.isNotEmpty) {
      oneDSample = EncodeConfig(
        symbology: oneDSymbology,
        data: items.first.oneDData!,
        dpi: dpi,
        xDimensionMm: xDimensionMm,
        barHeightMm: barHeightMm,
      );
    }
    if (use2D && items.isNotEmpty) {
      twoDSample = EncodeConfig(
        symbology: twoDSymbology,
        data: items.first.twoDData!,
        ecLevel: ecLevel,
        dpi: dpi,
        xDimensionMm: xDimensionMm,
        logoSideMm: logoSideMm,
        logoSafetyMargin: logoEcBudget,
      );
    }

    return Batch._(
      items: items,
      oneDSample: oneDSample,
      twoDSample: twoDSample,
      oneDSize: oneDSample == null ? null : Sizer.compute(oneDSample),
      twoDSize: twoDSample == null ? null : Sizer.compute(twoDSample),
      page: page,
      orientation: orientation,
      marginMm: marginMm,
      gapMm: gapMm,
      cellGapMm: cellGapMm,
      captionMm: captionMm,
      columnsOverride: columnsOverride,
    );
  }

  double get cellWidthMm => math.max(
        oneDSize?.outer.widthMm ?? 0,
        twoDSize?.outer.widthMm ?? 0,
      );

  // HRI caption metrics — these must track batch_pdf.dart, which renders the
  // full encoded string under each code at 5 pt, wrapped to the cell width.
  // rows/perPage/pageCount all derive from cellHeightMm, so a flat caption
  // budget (the old behaviour) badly under-counted multi-line Digital Links and
  // made the on-screen page count, the page-browser slicing and the
  // serialization-log page labels disagree with the exported PDF.
  static const double _hriPt = 5.0;
  static const double _hriLineMm = _hriPt * 1.4 / 2.835; // ≈ 2.47 mm per line
  static const double _hriCharMm = _hriPt * 0.62 / 2.835; // ≈ 1.09 mm per char

  /// Estimated wrapped-HRI line count for [data] at the cell width, mirroring
  /// the 5 pt caption batch_pdf renders. Slightly conservative (rounds up) so
  /// the estimate never under-fills relative to the PDF.
  int _hriLines(String? data) {
    if (data == null || data.isEmpty) return 0;
    final cpl = math.max(8, (cellWidthMm / _hriCharMm).floor());
    return math.max(1, (data.length / cpl).ceil());
  }

  // MultiPage flows on the tallest cell in each row and serials vary in length
  // (e.g. 0009 → 0010 adds a digit), so size the caption bands from the longest
  // payload in the whole run rather than just the first item.
  int get _maxTwoDLines =>
      hasTwoD ? items.fold(0, (m, it) => math.max(m, _hriLines(it.twoDData))) : 0;
  int get _maxOneDLines =>
      hasOneD ? items.fold(0, (m, it) => math.max(m, _hriLines(it.oneDData))) : 0;

  double get cellHeightMm {
    final twoH = twoDSize?.outer.heightMm ?? 0;
    final oneH = oneDSize?.outer.heightMm ?? 0;
    // Mirror batch_pdf.dart's per-band gaps exactly: 2 mm before the 2D HRI;
    // 4 mm before the 1D code and 2 mm before its HRI.
    final twoCap = hasTwoD ? 2 + _maxTwoDLines * _hriLineMm : 0.0;
    final oneCap = hasOneD ? 4 + 2 + _maxOneDLines * _hriLineMm : 0.0;
    return twoH + twoCap + oneH + oneCap;
  }

  /// Landscape applies only to finite cut sheets — a continuous web has no
  /// second finite dimension to swap.
  bool get _landscape =>
      orientation == PageOrientation.landscape && !page.isContinuous;

  /// Page width after applying the chosen orientation.
  double get effectiveWidthMm => _landscape ? page.heightMm : page.widthMm;

  /// Page height after orientation (unchanged for a continuous web).
  double get effectiveHeightMm => _landscape ? page.widthMm : page.heightMm;

  int get columns {
    if (columnsOverride > 0) return columnsOverride;
    // Each cell is rendered with a half-gap margin on every side, so a column
    // occupies cellWidth + cellGap of the content width. Pack only as many as
    // fit fully inside the content area, leaving the ruler gutter clear (codes
    // were spilling onto the rulers when one extra column was assumed).
    final usable = effectiveWidthMm - 2 * marginMm;
    final n = (usable / (cellWidthMm + cellGapMm)).floor();
    return n < 1 ? 1 : n;
  }

  int get rows {
    // A continuous web has no page break, so every cell stacks down one page.
    if (page.isContinuous) {
      final c = columns;
      return items.isEmpty ? 1 : (items.length / c).ceil();
    }
    // Same full-footprint packing vertically, so the bottom row never rides
    // onto the horizontal ruler.
    final usable = effectiveHeightMm - 2 * marginMm;
    final n = (usable / (cellHeightMm + cellGapMm)).floor();
    return n < 1 ? 1 : n;
  }

  /// Cells per printed page — all of them on a continuous web (one endless page).
  int get perPage =>
      page.isContinuous ? (items.isEmpty ? 1 : items.length) : columns * rows;

  int get pageCount => items.isEmpty
      ? 0
      : page.isContinuous
          ? 1
          : (items.length / perPage).ceil();

  /// Physical height of one page in mm. For a continuous web this is the height
  /// the content actually occupies (margins + stacked rows + gaps) rather than
  /// an infinite sheet, so exporters and rulers have a finite extent to draw.
  double get pageHeightMm {
    if (!page.isContinuous) return effectiveHeightMm;
    // Each cell reserves cellGapMm of vertical margin (half top, half bottom),
    // so budget a full gap per row to guarantee everything lands on one page.
    return 2 * marginMm + rows * (cellHeightMm + cellGapMm);
  }

  /// A representative size result for the cell (the 2D if present, else 1D).
  SizeResult? get sampleSize => twoDSize ?? oneDSize;
}
