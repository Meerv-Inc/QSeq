// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;

/// PDF417 error-correction levels (ISO/IEC 15438). Level *n* adds
/// `2^(n+1)` Reed–Solomon error-correction codewords — level 0 is the
/// minimum (2 codewords), level 8 the maximum (512 codewords).
enum Pdf417EcLevel {
  level0,
  level1,
  level2,
  level3,
  level4,
  level5,
  level6,
  level7,
  level8;

  /// Number of error-correction codewords this level adds.
  int get eccWordCount => 1 << (index + 1);

  String get label =>
      'Level $index${this == Pdf417EcLevel.level2 ? ' (default)' : ''}';
}

/// PDF417 symbol dimensioning.
///
/// Unlike QR/Data Matrix, PDF417 has no published, encoder-independent
/// capacity table: the codeword count for a message depends on which
/// compaction mode (numeric / text / byte) the encoder chooses per run of
/// characters, a heuristic decision internal to the encoder implementation.
/// A hand-rolled capacity estimate can diverge from the real encoder in
/// either direction — including a *smaller* height, which would silently
/// under-report a symbol's printed size. So instead of approximating,
/// [moduleGrid] runs the exact same `barcode` package encoder QSeq renders
/// with, and reads the real resulting geometry back.
class Pdf417Capacity {
  Pdf417Capacity._();

  /// Row height, in module widths — how many "modules tall" each of a
  /// PDF417 symbol's rows renders as. Fixed (not user-configurable) at a
  /// value comfortably inside the 2–3x guidance most scanners expect.
  static const double moduleHeight = 3;

  /// Target width:height ratio the encoder's column/row search optimises
  /// for. Fixed at a common PDF417 default (roughly landscape).
  static const double preferredRatio = 3.0;

  /// Encodes [data] as PDF417 at [ecLevel] and returns its natural module
  /// footprint (before quiet zones), or null if it doesn't fit within
  /// PDF417's row/column bounds.
  ///
  /// `Barcode2DMatrix` (the encoder's raw output type) isn't part of the
  /// `barcode` package's public export surface, so its `width`/`height`/
  /// `ratio` fields are read via `dynamic` — the same technique this
  /// module's tests use to cross-check against the encoder directly.
  static ({int widthModules, int heightModules})? moduleGrid(
    String data,
    Pdf417EcLevel ecLevel,
  ) {
    final barcode = bc.Barcode.pdf417(
      securityLevel: bc.Pdf417SecurityLevel.values[ecLevel.index],
      moduleHeight: moduleHeight,
      preferredRatio: preferredRatio,
    );
    try {
      final dynamic matrix = (barcode as dynamic).convert(
        Uint8List.fromList(utf8.encode(data)),
      );
      final width = matrix.width as int;
      final height = matrix.height as int;
      final ratio = matrix.ratio as double;
      return (widthModules: width, heightModules: (height * ratio).round());
    } on bc.BarcodeException {
      return null;
    }
  }
}
