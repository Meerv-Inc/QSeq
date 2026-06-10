// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/// The barcode symbologies the app can generate, plus their geometric traits
/// used by the sizing engine.
enum Symbology {
  qrCode('QR Code', is2D: true, quietZoneModules: 4),
  dataMatrix('Data Matrix', is2D: true, quietZoneModules: 1),
  gs1_128('GS1-128', is2D: false, quietZoneModules: 10),
  code128('Code 128', is2D: false, quietZoneModules: 10),
  code39('Code 39', is2D: false, quietZoneModules: 10),
  // EAN-13's quiet zones are asymmetric per GS1: 11 modules left, 7 right.
  ean13('EAN-13', is2D: false, quietZoneModules: 11, quietZoneRightOverride: 7),
  upcA('UPC-A', is2D: false, quietZoneModules: 9);

  const Symbology(
    this.displayName, {
    required this.is2D,
    required this.quietZoneModules,
    this.quietZoneRightOverride,
  });

  final String displayName;

  /// True for matrix symbologies (QR, Data Matrix) where a centre logo
  /// dead-space is meaningful; false for 1D where a logo must sit outside the
  /// bars.
  final bool is2D;

  /// Quiet-zone width in modules on the leading (left) edge — and the symmetric
  /// per-side value for symbologies whose two quiet zones are equal. For 2D this
  /// is applied to all four sides.
  final int quietZoneModules;

  /// Set only when the trailing (right) quiet zone differs from the leading one
  /// — EAN-13 (11 left, 7 right). Null means symmetric. Read via
  /// [quietZoneRightModules].
  final int? quietZoneRightOverride;

  /// Quiet-zone width in modules on the trailing (right) edge. Equal to
  /// [quietZoneModules] unless the symbology declares an asymmetric zone.
  int get quietZoneRightModules => quietZoneRightOverride ?? quietZoneModules;

  /// Only QR exposes a user-selectable error-correction level.
  bool get supportsEcLevel => this == Symbology.qrCode;

  /// 1D symbologies carry GS1 Application Identifier data via FNC1.
  bool get isGs1 => this == Symbology.gs1_128;
}

/// QR error-correction levels with their nominal recoverable codeword fraction
/// (ISO/IEC 18004). These drive both capacity selection and the logo
/// dead-space budget.
enum QrEcLevel {
  low('L', 0.07),
  medium('M', 0.15),
  quartile('Q', 0.25),
  high('H', 0.30);

  const QrEcLevel(this.label, this.recoverableFraction);

  final String label;

  /// Approximate fraction of codewords that can be lost and still recovered.
  final double recoverableFraction;
}
