// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import '../models/encode_config.dart';
import '../models/size_result.dart';
import '../models/symbology.dart';
import 'datamatrix_capacity.dart';
import 'dpi.dart';
import 'linear_metrics.dart';
import 'logo_ec.dart';
import 'pdf417_capacity.dart';
import 'qr_capacity.dart';

/// Pure function that turns an [EncodeConfig] into a [SizeResult]: chooses the
/// smallest symbol that holds the data, computes the printed outer perimeter at
/// the requested DPI, and evaluates the logo dead-space against the EC budget.
class Sizer {
  Sizer._();

  static SizeResult compute(EncodeConfig cfg) {
    return switch (cfg.symbology) {
      Symbology.qrCode => _qr(cfg),
      Symbology.dataMatrix => _dataMatrix(cfg),
      Symbology.pdf417 => _pdf417(cfg),
      _ => _linear(cfg),
    };
  }

  static SizeResult _qr(EncodeConfig cfg) {
    final warnings = <String>[];
    final version = QrCapacity.minVersionForBytes(cfg.byteCount, cfg.ecLevel);
    if (version == null) {
      return _overflow(
        cfg,
        'Data exceeds QR capacity at EC ${cfg.ecLevel.label}',
      );
    }
    final modules = QrCapacity.moduleCount(version);
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi);
    final side = modules + 2 * cfg.symbology.quietZoneModules;
    final outer = PhysicalSize.fromModules(
      widthModules: side,
      heightModules: side,
      moduleDots: dots,
      dpi: cfg.dpi,
    );
    // The symbol proper (without quiet zone) is what the logo sits on.
    final symbolSideMm = Dpi.inchToMm(modules * dots / cfg.dpi);
    final budget = _logo(
      cfg,
      symbolSideMm,
      cfg.ecLevel.recoverableFraction,
      warnings,
      is2D: true,
    );
    return SizeResult(
      symbology: cfg.symbology,
      outer: outer,
      moduleDots: dots,
      geometryLabel: 'Version $version · $modules×$modules modules',
      bytesRequested: cfg.byteCount,
      bytesCapacity: QrCapacity.byteCapacity(version, cfg.ecLevel),
      logoBudget: budget,
      fits: true,
      warnings: warnings,
    );
  }

  static SizeResult _dataMatrix(EncodeConfig cfg) {
    final warnings = <String>[];
    final size = DataMatrixCapacity.minSizeForBytes(cfg.byteCount);
    if (size == null) {
      return _overflow(cfg, 'Data exceeds the largest Data Matrix symbol');
    }
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi);
    final side = size.modules + 2 * cfg.symbology.quietZoneModules;
    final outer = PhysicalSize.fromModules(
      widthModules: side,
      heightModules: side,
      moduleDots: dots,
      dpi: cfg.dpi,
    );
    final symbolSideMm = Dpi.inchToMm(size.modules * dots / cfg.dpi);
    // Data Matrix correction is fixed by symbol size, not user-selectable.
    final budget = _logo(
      cfg,
      symbolSideMm,
      size.correctionFraction,
      warnings,
      is2D: true,
    );
    warnings.add(
      'Data Matrix correction is fixed at ${(size.correctionFraction * 100).round()}% (ECC 200) — not adjustable.',
    );
    return SizeResult(
      symbology: cfg.symbology,
      outer: outer,
      moduleDots: dots,
      geometryLabel: 'Size ${size.modules}×${size.modules}',
      bytesRequested: cfg.byteCount,
      bytesCapacity: size.byteCapacity,
      logoBudget: budget,
      fits: true,
      warnings: warnings,
    );
  }

  static SizeResult _pdf417(EncodeConfig cfg) {
    final warnings = <String>[];
    final grid = Pdf417Capacity.moduleGrid(cfg.data, cfg.pdf417EcLevel);
    if (grid == null) {
      return _overflow(
        cfg,
        'Data exceeds PDF417 capacity at ${cfg.pdf417EcLevel.label}',
      );
    }
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi);
    final outer = PhysicalSize.fromModules(
      widthModules: grid.widthModules + 2 * cfg.symbology.quietZoneModules,
      heightModules: grid.heightModules + 2 * cfg.symbology.quietZoneModules,
      moduleDots: dots,
      dpi: cfg.dpi,
    );
    if (cfg.logoSideMm > 0) {
      warnings.add(
        "PDF417's stacked-row structure has no safe centre dead-space — a "
        'logo is not applied.',
      );
    }
    return SizeResult(
      symbology: cfg.symbology,
      outer: outer,
      moduleDots: dots,
      geometryLabel:
          '${cfg.pdf417EcLevel.label} · '
          '${grid.widthModules}×${grid.heightModules} modules',
      bytesRequested: cfg.byteCount,
      // PDF417's real capacity is compaction-mode dependent, not a fixed
      // number for a given geometry — no capacity figure is shown, same as
      // the fixed-content-free 1D symbologies below.
      bytesCapacity: null,
      logoBudget: null,
      fits: true,
      warnings: warnings,
    );
  }

  static SizeResult _linear(EncodeConfig cfg) {
    final warnings = <String>[];
    final fixedContent =
        cfg.symbology == Symbology.ean13 ||
        cfg.symbology == Symbology.ean8 ||
        cfg.symbology == Symbology.upcA;
    final modWidth = LinearMetrics.moduleWidth(cfg.symbology, cfg.data);
    final dots = Dpi.moduleDots(cfg.xDimensionMm, cfg.dpi);
    // Quiet zones can be asymmetric (EAN-13: 11 left, 7 right), so sum the two
    // sides rather than doubling one.
    final totalWidthModules =
        modWidth +
        cfg.symbology.quietZoneModules +
        cfg.symbology.quietZoneRightModules;
    final widthPx = totalWidthModules * dots;
    final heightPx = (Dpi.mmToInch(cfg.barHeightMm) * cfg.dpi).round();
    final outer = PhysicalSize(
      widthMm: Dpi.inchToMm(widthPx / cfg.dpi),
      heightMm: Dpi.inchToMm(heightPx / cfg.dpi),
      widthPx: widthPx,
      heightPx: heightPx,
      dpi: cfg.dpi,
    );
    if (!fixedContent) {
      warnings.add(
        'Width is an estimate; the encoder\'s mode choices may shift it by a few modules.',
      );
    }
    if (cfg.logoSideMm > 0) {
      warnings.add(
        'A logo must not overlap the bars of a 1D code — it is placed in the caption/quiet band only.',
      );
    }
    return SizeResult(
      symbology: cfg.symbology,
      outer: outer,
      moduleDots: dots,
      geometryLabel: '${cfg.symbology.displayName} · $modWidth modules wide',
      bytesRequested: cfg.byteCount,
      bytesCapacity: null,
      logoBudget: null,
      fits: true,
      warnings: warnings,
    );
  }

  static LogoBudget? _logo(
    EncodeConfig cfg,
    double symbolSideMm,
    double recoverable,
    List<String> warnings, {
    required bool is2D,
  }) {
    if (cfg.logoSideMm <= 0) return null;
    final budget = LogoEc.evaluate(
      logoSideMm: cfg.logoSideMm,
      symbolSideMm: symbolSideMm,
      recoverableFraction: recoverable,
      safetyMargin: cfg.logoSafetyMargin,
    );
    if (!budget.fits) {
      warnings.add(
        'Logo covers ${(budget.logoAreaFraction * 100).toStringAsFixed(1)}% of the symbol — over the ${(budget.budgetFraction * 100).toStringAsFixed(1)}% budget. Max safe logo ≈ ${budget.maxSafeLogoMm.toStringAsFixed(1)} mm.',
      );
    }
    return budget;
  }

  static SizeResult _overflow(EncodeConfig cfg, String message) => SizeResult(
    symbology: cfg.symbology,
    outer: PhysicalSize(
      widthMm: 0,
      heightMm: 0,
      widthPx: 0,
      heightPx: 0,
      dpi: cfg.dpi,
    ),
    moduleDots: 0,
    geometryLabel: '—',
    bytesRequested: cfg.byteCount,
    bytesCapacity: null,
    logoBudget: null,
    fits: false,
    warnings: [message],
  );
}
