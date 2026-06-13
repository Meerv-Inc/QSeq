// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import '../models/symbology.dart';

/// Estimates the module width of 1D symbologies.
///
/// 1D widths depend on the encoder's mode decisions (e.g. Code 128 switching to
/// the double-density numeric "Code C"), so these are well-founded estimates
/// labelled as such in the UI; the rendered symbol from the `barcode` package
/// is the authoritative artefact.
class LinearMetrics {
  LinearMetrics._();

  /// Total module width (excluding quiet zones) for [symbology] encoding
  /// [data]. Height is handled separately via the user's bar-height input.
  static int moduleWidth(Symbology symbology, String data) {
    return switch (symbology) {
      Symbology.code128 || Symbology.gs1_128 => _code128(data),
      Symbology.code39 => _code39(data),
      Symbology.ean13 => 95, // fixed structure
      Symbology.ean8 => 67, // fixed structure (3+28+5+28+3)
      Symbology.upcA => 95, // fixed structure
      _ => throw ArgumentError('${symbology.displayName} is not 1D'),
    };
  }

  /// Code 128: 11 modules per symbol character (start + data + checksum) plus a
  /// 13-module stop. Numeric runs encode two digits per character (Code C), so
  /// we take the cheaper of one-char-per-byte and two-digits-per-char.
  static int _code128(String data) {
    final digitsOnly = RegExp(r'^\d+$').hasMatch(data);
    final dataChars =
        digitsOnly ? (data.length / 2).ceil() : data.length;
    final symbolChars = 1 /*start*/ + dataChars + 1 /*checksum*/;
    return 11 * symbolChars + 13 /*stop*/;
  }

  /// Code 39 at a narrow:wide ratio of 1:3. Each character spans 13 narrow
  /// modules (3 wide × 3 + 6 narrow) plus a 1-module inter-character gap. The
  /// `*` start and stop characters add two more.
  static int _code39(String data) {
    const perChar = 13 + 1; // element widths + inter-character gap
    final chars = data.length + 2; // start/stop guards
    return perChar * chars - 1; // no trailing gap after the final character
  }
}
