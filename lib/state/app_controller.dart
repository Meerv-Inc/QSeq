// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../encoders/sgtin.dart';
import '../models/batch.dart';
import '../models/combined_label.dart';
import '../models/data_source.dart';
import '../models/encode_config.dart';
import '../models/size_result.dart';
import '../models/symbology.dart';
import '../sizing/sizer.dart';

/// The workspace: which symbol families are produced (1D, 2D, or both) and
/// whether the output is a single item or a serialized sheet.
enum AppMode {
  oneD('1D'),
  oneDSerial('1D — Serialized sheet'),
  twoD('2D'),
  twoDSerial('2D — Serialized sheet'),
  combo('1D + 2D label'),
  comboSerial('1D + 2D — Serialized sheet');

  const AppMode(this.label);
  final String label;

  bool get use1D =>
      this == oneD || this == oneDSerial || this == combo || this == comboSerial;
  bool get use2D =>
      this == twoD || this == twoDSerial || this == combo || this == comboSerial;
  bool get isSerialized =>
      this == oneDSerial || this == twoDSerial || this == comboSerial;
  bool get isCombo => use1D && use2D;
}

/// Sentinel so copyWith can distinguish "leave logoImagePath" from "clear it".
const Object _unset = Object();

/// Immutable snapshot of every user-controlled setting.
class AppSettings {
  final AppMode mode;
  final Symbology oneDSymbology; // gs1_128 / code128 / code39 / ean13 / upcA
  final Symbology twoDSymbology; // qrCode / dataMatrix
  final DataSourceInput data;
  final QrEcLevel ecLevel;
  final double dpi;
  final double xDimensionMm;
  final double barHeightMm;
  final double logoSideMm;

  /// Fraction (0–1) of the symbol's error-correction capacity the centre logo
  /// is allowed to consume. Lower = smaller, safer logo; higher = larger,
  /// riskier. Presented in the UI as a percentage.
  final double logoEcBudget;
  final String? logoImagePath;

  // Combined-label layout
  final LabelArrangement arrangement;
  final double labelGapMm;
  final double labelPaddingMm;

  // Serialized-sheet specifics
  final String batchPrefix;
  final int batchStart;
  final int batchCount;
  final int batchPadding;
  final int batchColumns; // 0 = auto-fit
  final PageFormat pageFormat;

  const AppSettings({
    this.mode = AppMode.twoD,
    this.oneDSymbology = Symbology.gs1_128,
    this.twoDSymbology = Symbology.qrCode,
    this.data = const DataSourceInput(),
    this.ecLevel = QrEcLevel.medium,
    this.dpi = 300,
    this.xDimensionMm = 0.5,
    this.barHeightMm = 15,
    this.logoSideMm = 0,
    this.logoEcBudget = 0.5,
    this.logoImagePath,
    this.arrangement = LabelArrangement.stacked,
    this.labelGapMm = 3,
    this.labelPaddingMm = 2,
    this.batchPrefix = '',
    this.batchStart = 1,
    this.batchCount = 24,
    this.batchPadding = 5,
    this.batchColumns = 0,
    this.pageFormat = PageFormat.a4,
  });

  AppSettings copyWith({
    AppMode? mode,
    Symbology? oneDSymbology,
    Symbology? twoDSymbology,
    DataSourceInput? data,
    QrEcLevel? ecLevel,
    double? dpi,
    double? xDimensionMm,
    double? barHeightMm,
    double? logoSideMm,
    double? logoEcBudget,
    Object? logoImagePath = _unset,
    LabelArrangement? arrangement,
    double? labelGapMm,
    double? labelPaddingMm,
    String? batchPrefix,
    int? batchStart,
    int? batchCount,
    int? batchPadding,
    int? batchColumns,
    PageFormat? pageFormat,
  }) {
    return AppSettings(
      mode: mode ?? this.mode,
      oneDSymbology: oneDSymbology ?? this.oneDSymbology,
      twoDSymbology: twoDSymbology ?? this.twoDSymbology,
      data: data ?? this.data,
      ecLevel: ecLevel ?? this.ecLevel,
      dpi: dpi ?? this.dpi,
      xDimensionMm: xDimensionMm ?? this.xDimensionMm,
      barHeightMm: barHeightMm ?? this.barHeightMm,
      logoSideMm: logoSideMm ?? this.logoSideMm,
      logoEcBudget: logoEcBudget ?? this.logoEcBudget,
      logoImagePath: identical(logoImagePath, _unset)
          ? this.logoImagePath
          : logoImagePath as String?,
      arrangement: arrangement ?? this.arrangement,
      labelGapMm: labelGapMm ?? this.labelGapMm,
      labelPaddingMm: labelPaddingMm ?? this.labelPaddingMm,
      batchPrefix: batchPrefix ?? this.batchPrefix,
      batchStart: batchStart ?? this.batchStart,
      batchCount: batchCount ?? this.batchCount,
      batchPadding: batchPadding ?? this.batchPadding,
      batchColumns: batchColumns ?? this.batchColumns,
      pageFormat: pageFormat ?? this.pageFormat,
    );
  }

  /// The active symbology for a single (non-combo) static workspace.
  Symbology get activeSymbology =>
      mode.use2D ? twoDSymbology : oneDSymbology;

  /// The resolved encodable string (or an error) for a static single workspace.
  ResolvedData get resolved => data.resolve();

  /// The static single-symbol [EncodeConfig] (1D-only or 2D-only, not serial).
  EncodeConfig get singleConfig => EncodeConfig(
        symbology: activeSymbology,
        data: resolved.data ?? '',
        ecLevel: ecLevel,
        dpi: dpi,
        xDimensionMm: xDimensionMm,
        barHeightMm: barHeightMm,
        logoSideMm: logoSideMm,
        logoSafetyMargin: logoEcBudget,
      );
}

/// The mutable controller. Every setter returns a fresh [AppSettings] so
/// dependent providers recompute the sizing live.
class AppController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void update(AppSettings Function(AppSettings) fn) => state = fn(state);

  /// Replaces the entire settings snapshot (used when opening a project file).
  void set(AppSettings next) => state = next;
}

final appControllerProvider =
    NotifierProvider<AppController, AppSettings>(AppController.new);

/// Live size readout for a static single-symbol workspace (1D or 2D only).
final singleSizeProvider = Provider<SizeResult?>((ref) {
  final s = ref.watch(appControllerProvider);
  if (s.mode.isSerialized || s.mode.isCombo) return null;
  if (s.resolved.data == null) return null;
  return Sizer.compute(s.singleConfig);
});

/// The static combined label (null unless in 1D+2D static mode).
final combinedLabelProvider = Provider<CombinedLabel?>((ref) {
  final s = ref.watch(appControllerProvider);
  if (s.mode != AppMode.combo) return null;
  try {
    final sgtin = Sgtin(gtin: s.data.gtin, serial: s.data.serial);
    return CombinedLabel.fromSgtin(
      sgtin: sgtin,
      twoDSymbology: s.twoDSymbology,
      digitalLinkDomain: s.data.digitalLinkDomain,
      dpi: s.dpi,
      xDimensionMm: s.xDimensionMm,
      barHeightMm: s.barHeightMm,
      ecLevel: s.ecLevel,
      arrangement: s.arrangement,
      gapMm: s.labelGapMm,
      paddingMm: s.labelPaddingMm,
      logoSideMm: s.logoSideMm,
    );
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
});

/// Builds the serialized sheet for the current settings (or null).
Batch? buildBatchFor(AppSettings s) {
  if (!s.mode.isSerialized) return null;
  final count = s.batchCount.clamp(1, 5000);
  final padding = s.batchPadding.clamp(0, 12);
  try {
    return Batch.build(
      use1D: s.mode.use1D,
      use2D: s.mode.use2D,
      oneDSymbology: s.oneDSymbology,
      twoDSymbology: s.twoDSymbology,
      prefix: s.batchPrefix,
      start: s.batchStart,
      count: count,
      padding: padding,
      // In a combined cell the 1D carries the element string and the 2D the
      // Digital Link; standalone 1D/2D honour the chosen SGTIN format.
      buildOneD: (serial) => s.mode.isCombo
          ? s.data.encodeWith(format: SgtinFormat.elementString, serial: serial)
          : s.data.encodeWith(serial: serial),
      buildTwoD: (serial) => s.mode.isCombo
          ? s.data.encodeWith(format: SgtinFormat.digitalLink, serial: serial)
          : s.data.encodeWith(serial: serial),
      ecLevel: s.ecLevel,
      dpi: s.dpi,
      xDimensionMm: s.xDimensionMm,
      barHeightMm: s.barHeightMm,
      logoSideMm: s.logoSideMm,
      logoEcBudget: s.logoEcBudget,
      page: s.pageFormat,
      gapMm: s.labelGapMm,
      columnsOverride: s.batchColumns,
    );
  } catch (_) {
    return null;
  }
}

/// The serialized sheet (null unless in a serialized mode with valid data).
final batchProvider = Provider<Batch?>((ref) {
  final s = ref.watch(appControllerProvider);
  return buildBatchFor(s);
});

/// Every encoded payload in the current workspace — drives the Serialization
/// Log. Shows the full GS1 Digital Link carried in the 2D code when present
/// (falling back to the 1D element string, then the serial).
final serialLogProvider = Provider<List<String>>((ref) {
  final s = ref.watch(appControllerProvider);
  if (s.mode.isSerialized) {
    final batch = ref.watch(batchProvider);
    if (batch == null) return const [];
    return batch.items
        .map((e) => e.twoDData ?? e.oneDData ?? e.serial)
        .toList();
  }
  if (s.mode.isCombo) {
    final label = ref.watch(combinedLabelProvider);
    if (label != null) return [label.twoD.data];
  }
  return s.resolved.data != null ? [s.resolved.data!] : const [];
});
