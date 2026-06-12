// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../encoders/sgtin.dart';
import '../models/batch.dart';
import '../models/combined_label.dart';
import '../models/data_source.dart';
import '../models/encode_config.dart';
import '../models/label_spec.dart';
import '../models/size_result.dart';
import '../models/symbology.dart';
import '../sizing/sizer.dart';

/// The workspace: which symbol families are produced (1D, 2D, or both) and
/// whether the output is a single item or a page-tiled sheet. Sheet-of-copies
/// and serialized workspaces both increment the serial per item (mirroring the
/// web app); copies sheets just take their count from a separate Copies field.
enum AppMode {
  twoD('2D'),
  oneD('1D'),
  combo('1D + 2D label'),
  twoDSheet('2D — Sheet of copies'),
  oneDSheet('1D — Sheet of copies'),
  twoDSerial('2D — Serialized sheet'),
  oneDSerial('1D — Serialized sheet'),
  comboSerial('1D + 2D — Serialized sheet');

  const AppMode(this.label);
  final String label;

  bool get use1D =>
      this == oneD ||
      this == oneDSheet ||
      this == oneDSerial ||
      this == combo ||
      this == comboSerial;
  bool get use2D =>
      this == twoD ||
      this == twoDSheet ||
      this == twoDSerial ||
      this == combo ||
      this == comboSerial;

  /// Sheet of copies: page-tiled like a serialized sheet (and incremented the
  /// same way), but counted by the Copies field.
  bool get isCopies => this == oneDSheet || this == twoDSheet;
  bool get isSerialized =>
      isCopies ||
      this == oneDSerial ||
      this == twoDSerial ||
      this == comboSerial;
  bool get isCombo => use1D && use2D;
}

/// Sentinel so copyWith can distinguish "leave logoImagePath" from "clear it".
const Object _unset = Object();

/// Share of a 2D symbol's error-correction capacity a centre logo is auto-sized
/// to consume when the "Logo" checkbox is ticked.
const double kLogoAutoEcShare = 0.15;

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

  /// The auto-size share of EC capacity picked in the Logo dropdown
  /// (0.15–0.5); ignored when [logoManual] is on.
  final double logoEcShare;

  /// Manual dead-space mode: [logoSideMm] is user-entered instead of
  /// auto-sized from [logoEcShare].
  final bool logoManual;

  // Rulers
  final bool rulersOnScreen;
  final bool rulersInExports;

  /// Label designer overlay: lay the workspace's code(s) out on a sized label
  /// (single modes → one label; sheet modes → label sheets in the PDF).
  final bool labelOn;

  // Combined-label layout
  final LabelArrangement arrangement;
  final double labelGapMm;
  final double labelPaddingMm;

  // Sheet specifics. Serialization derives its prefix/start/zero-pad from the
  // data serial itself (trailing digits increment, leading text is the
  // prefix); only the counts live here.
  final int batchCount;
  final int batchCopies; // sheet-of-copies count
  final int batchColumns; // 0 = auto-fit
  final PageFormat pageFormat;
  final PageOrientation pageOrientation;

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
    this.logoEcShare = kLogoAutoEcShare,
    this.logoManual = false,
    this.rulersOnScreen = true,
    this.rulersInExports = true,
    this.labelOn = false,
    this.arrangement = LabelArrangement.stacked,
    this.labelGapMm = 3,
    this.labelPaddingMm = 2,
    this.batchCount = 24,
    this.batchCopies = 12,
    this.batchColumns = 0,
    this.pageFormat = PageFormat.letter,
    this.pageOrientation = PageOrientation.portrait,
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
    double? logoEcShare,
    bool? logoManual,
    bool? rulersOnScreen,
    bool? rulersInExports,
    bool? labelOn,
    LabelArrangement? arrangement,
    double? labelGapMm,
    double? labelPaddingMm,
    int? batchCount,
    int? batchCopies,
    int? batchColumns,
    PageFormat? pageFormat,
    PageOrientation? pageOrientation,
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
      logoEcShare: logoEcShare ?? this.logoEcShare,
      logoManual: logoManual ?? this.logoManual,
      rulersOnScreen: rulersOnScreen ?? this.rulersOnScreen,
      rulersInExports: rulersInExports ?? this.rulersInExports,
      labelOn: labelOn ?? this.labelOn,
      arrangement: arrangement ?? this.arrangement,
      labelGapMm: labelGapMm ?? this.labelGapMm,
      labelPaddingMm: labelPaddingMm ?? this.labelPaddingMm,
      batchCount: batchCount ?? this.batchCount,
      batchCopies: batchCopies ?? this.batchCopies,
      batchColumns: batchColumns ?? this.batchColumns,
      pageFormat: pageFormat ?? this.pageFormat,
      pageOrientation: pageOrientation ?? this.pageOrientation,
    );
  }

  /// The active symbology for a single (non-combo) static workspace.
  Symbology get activeSymbology =>
      mode.use2D ? twoDSymbology : oneDSymbology;

  /// The resolved encodable string (or an error) for a static single workspace.
  ResolvedData get resolved => data.resolve();

  // Sanitised views of the free-entry numeric settings, each clamped to a range
  // the render/size engine can handle without crashing — a zero/negative size
  // or an absurd DPI would otherwise yield an empty or memory-exhausting image.
  // The raw fields are left exactly as typed so the input controls never fight
  // the user mid-edit; only these consumption-side getters clamp.
  static double _safe(double v, double lo, double hi, double fallback) =>
      v.isFinite ? v.clamp(lo, hi).toDouble() : fallback;

  double get safeDpi => _safe(dpi, 36, 1200, 300);
  double get safeXDimensionMm => _safe(xDimensionMm, 0.05, 5, 0.5);
  double get safeBarHeightMm => _safe(barHeightMm, 1, 300, 15);
  double get safeLogoSideMm => _safe(logoSideMm, 0, 1000, 0);
  double get safeLogoEcBudget => _safe(logoEcBudget, 0.05, 0.95, 0.5);
  double get safeLabelGapMm => _safe(labelGapMm, 0, 100, 3);
  double get safeLabelPaddingMm => _safe(labelPaddingMm, 0, 100, 2);

  /// The static single-symbol [EncodeConfig] (1D-only or 2D-only, not serial).
  EncodeConfig get singleConfig => EncodeConfig(
        symbology: activeSymbology,
        data: resolved.data ?? '',
        ecLevel: ecLevel,
        dpi: safeDpi,
        xDimensionMm: safeXDimensionMm,
        barHeightMm: safeBarHeightMm,
        logoSideMm: safeLogoSideMm,
        logoSafetyMargin: safeLogoEcBudget,
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

/// Dark / light theme. Defaults to following the system.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// The label designer spec (overlay state lives in [AppSettings.labelOn]).
class LabelSpecController extends Notifier<LabelSpec> {
  @override
  LabelSpec build() => LabelSpec();

  /// Clone-mutate-replace so dependents rebuild.
  void mutate(void Function(LabelSpec) fn) {
    final next = state.clone();
    fn(next);
    state = next;
  }

  void set(LabelSpec next) => state = next;
}

final labelSpecProvider =
    NotifierProvider<LabelSpecController, LabelSpec>(LabelSpecController.new);

/// Which label element is selected in the designer (a [labelElementKeys] key).
class LabelSelectionController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? key) => state = key;
}

final labelSelectionProvider = NotifierProvider<LabelSelectionController,
    String?>(LabelSelectionController.new);

/// The open project file and its save status, shown in the title bar.
class ProjectMeta {
  final String? path; // null = untitled (never saved)
  final bool dirty;
  const ProjectMeta({this.path, this.dirty = false});
  String get name {
    final p = path;
    if (p == null) return 'Untitled';
    final cut = p.replaceAll('\\', '/').split('/').last;
    return cut.isEmpty ? 'Untitled' : cut;
  }
}

class ProjectMetaController extends Notifier<ProjectMeta> {
  @override
  ProjectMeta build() {
    // Any settings or label-designer change marks the project dirty.
    ref.listen(appControllerProvider, (prev, next) {
      if (prev != next) markDirty();
    });
    ref.listen(labelSpecProvider, (prev, next) {
      if (!identical(prev, next)) markDirty();
    });
    return const ProjectMeta();
  }

  void markDirty() {
    if (!state.dirty) state = ProjectMeta(path: state.path, dirty: true);
  }

  void saved(String path) => state = ProjectMeta(path: path, dirty: false);
  void opened(String path) => state = ProjectMeta(path: path, dirty: false);
}

final projectMetaProvider = NotifierProvider<ProjectMetaController,
    ProjectMeta>(ProjectMetaController.new);

/// Which printed page the serialized-sheet preview is showing (0-based). Read
/// clamped to the live page count; stays put across edits unless out of range.
class BatchPageController extends Notifier<int> {
  @override
  int build() => 0;
  void set(int page) => state = page;
}

final batchPageProvider =
    NotifierProvider<BatchPageController, int>(BatchPageController.new);

/// On-screen zoom for the serialized-sheet preview. 0 means "auto-fit" (the
/// whole printed sheet is scaled to fit the stage); any positive value is an
/// explicit zoom where 1.0 is true physical scale.
class BatchZoomController extends Notifier<double> {
  @override
  double build() => 0;
  // Cap matches the auto-fit zoom ceiling (3.0) so an explicit zoom can always
  // reach what auto-fit shows for a small sheet.
  void set(double z) => state = z <= 0 ? 0 : z.clamp(0.1, 3.0);
}

final batchZoomProvider =
    NotifierProvider<BatchZoomController, double>(BatchZoomController.new);

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
      dpi: s.safeDpi,
      xDimensionMm: s.safeXDimensionMm,
      barHeightMm: s.safeBarHeightMm,
      ecLevel: s.ecLevel,
      arrangement: s.arrangement,
      gapMm: s.safeLabelGapMm,
      paddingMm: s.safeLabelPaddingMm,
      logoSideMm: s.safeLogoSideMm,
    );
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
});

/// Builds the serialized sheet for the current settings (or null).
/// The run is derived from the data serial itself — its trailing digits are
/// the incrementing counter (6789, 6790, …), any leading text is the fixed
/// prefix, and leading zeros are preserved (AB0099 → AB0100) — mirroring the
/// web app.
Batch? buildBatchFor(AppSettings s) {
  if (!s.mode.isSerialized) return null;
  final count = (s.mode.isCopies ? s.batchCopies : s.batchCount).clamp(1, 2000);
  final m = RegExp(r'^(.*?)(\d{1,12})$').firstMatch(s.data.serial);
  try {
    return Batch.build(
      use1D: s.mode.use1D,
      use2D: s.mode.use2D,
      oneDSymbology: s.oneDSymbology,
      twoDSymbology: s.twoDSymbology,
      prefix: m == null ? s.data.serial : m.group(1)!,
      start: m == null ? 1 : int.parse(m.group(2)!),
      count: count,
      padding: m == null ? 0 : m.group(2)!.length,
      // In a combined cell the 1D carries the element string and the 2D the
      // Digital Link; standalone 1D/2D honour the chosen SGTIN format.
      buildOneD: (serial) => s.mode.isCombo
          ? s.data.encodeWith(format: SgtinFormat.elementString, serial: serial)
          : s.data.encodeWith(serial: serial),
      buildTwoD: (serial) => s.mode.isCombo
          ? s.data.encodeWith(format: SgtinFormat.digitalLink, serial: serial)
          : s.data.encodeWith(serial: serial),
      ecLevel: s.ecLevel,
      dpi: s.safeDpi,
      xDimensionMm: s.safeXDimensionMm,
      barHeightMm: s.safeBarHeightMm,
      logoSideMm: s.safeLogoSideMm,
      logoEcBudget: s.safeLogoEcBudget,
      page: s.pageFormat,
      orientation: s.pageOrientation,
      gapMm: s.safeLabelGapMm,
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

/// The active 2D config for the current workspace, or null.
EncodeConfig? _activeTwoD(Ref ref, AppSettings s) {
  if (!s.mode.use2D) return null;
  if (s.mode.isSerialized) return ref.watch(batchProvider)?.twoDSample;
  if (s.mode.isCombo) return ref.watch(combinedLabelProvider)?.twoD;
  if (s.resolved.data != null) return s.singleConfig;
  return null;
}

/// The centre-logo side (mm) that consumes exactly [AppSettings.logoEcShare]
/// of the active 2D symbol's error-correction capacity. Drives the "Logo"
/// checkbox and the EC-share dropdown. 0 when there is no 2D symbol to host
/// one (a 1D-only workspace, or no valid data yet).
final autoLogoSideProvider = Provider<double>((ref) {
  final s = ref.watch(appControllerProvider);
  final twoD = _activeTwoD(ref, s);
  if (twoD == null) return 0;
  // A symbol's size is independent of its centre logo, so probe the sizer with
  // a token logo at the chosen share — the max-safe side it reports back is
  // exactly the dead-space that fills that share of the EC budget.
  final budget = Sizer.compute(
          twoD.copyWith(logoSideMm: 1, logoSafetyMargin: s.logoEcShare))
      .logoBudget;
  return budget?.maxSafeLogoMm ?? 0;
});

/// Fraction of the 2D symbol's full error-correction capacity the current
/// dead-space consumes (can exceed 1.0 — the code is then unscannable).
/// Null when no logo or no 2D symbol.
final logoShareUsedProvider = Provider<double?>((ref) {
  final s = ref.watch(appControllerProvider);
  if (s.logoSideMm <= 0) return null;
  final twoD = _activeTwoD(ref, s);
  if (twoD == null) return null;
  final b = Sizer.compute(twoD).logoBudget;
  if (b == null || twoD.logoSafetyMargin <= 0) return null;
  // budgetFraction = recoverable × safetyMargin, so invert the margin.
  final recoverable = b.budgetFraction / twoD.logoSafetyMargin;
  if (recoverable <= 0) return null;
  return b.logoAreaFraction / recoverable;
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
