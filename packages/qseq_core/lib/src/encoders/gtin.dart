// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:math';

/// GTIN (Global Trade Item Number) helpers.
///
/// Supports GTIN-8/12/13/14. Everything is normalised to a 14-digit GTIN-14
/// internally (left-padded with zeros), which is the canonical form used for
/// GS1 Application Identifier (01), GS1 Digital Link and EPC conversions.
class Gtin {
  Gtin._();

  /// The GTIN lengths (including the trailing check digit) GS1 defines.
  static const lengths = [8, 12, 13, 14];

  static final Random _rng = Random();

  /// Returns true if [value] is all ASCII digits.
  static bool isAllDigits(String value) =>
      value.isNotEmpty && RegExp(r'^\d+$').hasMatch(value);

  /// Computes the GS1 mod-10 check digit for a string of *data* digits
  /// (i.e. without the trailing check digit). The right-most data digit is
  /// weighted by 3, then alternating 1, 3, 1 ... moving left.
  static int checkDigit(String dataDigits) {
    if (!isAllDigits(dataDigits)) {
      throw ArgumentError('GTIN data must be numeric: "$dataDigits"');
    }
    var sum = 0;
    final n = dataDigits.length;
    for (var i = 0; i < n; i++) {
      final digit = dataDigits.codeUnitAt(i) - 0x30;
      final fromRight = n - 1 - i; // 0 == right-most data digit
      final weight = (fromRight % 2 == 0) ? 3 : 1;
      sum += digit * weight;
    }
    return (10 - (sum % 10)) % 10;
  }

  /// Validates that the final digit of [gtin] is a correct check digit.
  static bool isValid(String gtin) {
    if (!isAllDigits(gtin) || gtin.length < 8) return false;
    final data = gtin.substring(0, gtin.length - 1);
    final provided = gtin.codeUnitAt(gtin.length - 1) - 0x30;
    return checkDigit(data) == provided;
  }

  /// Normalises any valid GTIN-8/12/13/14 to a 14-digit GTIN-14.
  ///
  /// Throws [FormatException] if the value is not numeric, has an unsupported
  /// length, or has an incorrect check digit.
  static String normalize14(String gtin) {
    final trimmed = gtin.trim();
    if (!isAllDigits(trimmed)) {
      throw FormatException('GTIN must be numeric', trimmed);
    }
    if (![8, 12, 13, 14].contains(trimmed.length)) {
      throw FormatException(
          'GTIN must be 8, 12, 13 or 14 digits', trimmed, trimmed.length);
    }
    if (!isValid(trimmed)) {
      throw FormatException('GTIN check digit is invalid', trimmed);
    }
    return trimmed.padLeft(14, '0');
  }

  /// Builds a complete GTIN by appending the computed check digit to
  /// [dataDigits] (the GTIN without its check digit).
  static String withCheckDigit(String dataDigits) =>
      '$dataDigits${checkDigit(dataDigits)}';

  /// A fixed, check-digit-valid example GTIN of [length] (8/12/13/14), handy
  /// for UI hints. Unlike [generate] it is deterministic, so it doesn't flicker
  /// when used as placeholder text rebuilt on every frame.
  static String example(int length) {
    const bodies = {
      8: '9638507',
      12: '03600029145',
      13: '400638133393',
      14: '1234567890123',
    };
    final body = bodies[length];
    if (body == null) {
      throw ArgumentError.value(
          length, 'length', 'GTIN length must be 8, 12, 13 or 14');
    }
    return withCheckDigit(body);
  }

  /// Generates a random, check-digit-valid GTIN of [length] (8/12/13/14).
  ///
  /// The leading data digit is kept non-zero so the value renders at the
  /// requested length, the remaining body digits are random, and the final
  /// digit is the computed GS1 check digit. Pass [rng] for deterministic
  /// output in tests.
  static String generate(int length, {Random? rng}) {
    if (!lengths.contains(length)) {
      throw ArgumentError.value(
          length, 'length', 'GTIN length must be 8, 12, 13 or 14');
    }
    final r = rng ?? _rng;
    final body = StringBuffer();
    for (var i = 0; i < length - 1; i++) {
      body.write(i == 0 ? 1 + r.nextInt(9) : r.nextInt(10));
    }
    return withCheckDigit(body.toString());
  }
}
