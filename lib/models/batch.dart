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

/// Paper sizes for batch sheets.
enum PageFormat {
  a4('A4', 210, 297),
  letter('US Letter', 215.9, 279.4);

  const PageFormat(this.label, this.widthMm, this.heightMm);
  final String label;
  final double widthMm;
  final double heightMm;
}

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

  double get cellHeightMm {
    final twoH = twoDSize?.outer.heightMm ?? 0;
    final oneH = oneDSize?.outer.heightMm ?? 0;
    final innerGap = (hasOneD && hasTwoD) ? gapMm : 0;
    return twoH + oneH + innerGap + captionMm;
  }

  int get columns {
    if (columnsOverride > 0) return columnsOverride;
    final usable = page.widthMm - 2 * marginMm + cellGapMm;
    final n = (usable / (cellWidthMm + cellGapMm)).floor();
    return n < 1 ? 1 : n;
  }

  int get rows {
    final usable = page.heightMm - 2 * marginMm + cellGapMm;
    final n = (usable / (cellHeightMm + cellGapMm)).floor();
    return n < 1 ? 1 : n;
  }

  int get perPage => columns * rows;

  int get pageCount => items.isEmpty ? 0 : (items.length / perPage).ceil();

  /// A representative size result for the cell (the 2D if present, else 1D).
  SizeResult? get sampleSize => twoDSize ?? oneDSize;
}
