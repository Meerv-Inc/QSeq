// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/// NATO Stock Number (NSN) — a 13-digit code identifying a standardised item of
/// supply in the NATO codification system.
///
/// Structure (13 digits):
///
/// ```
///   9515   00    003 6945
///   └NSC┘  └NCB┘ └─NIIN item─┘
///   └────NSC───┘ └────NIIN (9 digits)────┘
/// ```
///
/// * NSC  (4 digits) — NATO Supply Classification = Supply Group (2) + Class (2)
/// * NCB  (2 digits) — National Codification Bureau (e.g. 00/01 = USA)
/// * NIIN (9 digits) — NATO Item Identification Number = NCB (2) + item no. (7)
///
/// There is **no check digit** in the NATO codification standard: the final
/// seven digits are non-significant, sequentially assigned numbers. We therefore
/// validate structure only and never compute/verify a check digit.
///
/// NSNs are conventionally marked with Code 39 (MIL-STD-129) and, increasingly,
/// Data Matrix (MIL-STD-130 IUID). The encodable [payload] is the plain 13-digit
/// string; [formatted] is the dashed human-readable form.
class Nsn {
  /// The 13 significant digits, no separators.
  final String digits;

  const Nsn._(this.digits);

  /// Parses an NSN from either the plain (`9515000036945`) or dashed
  /// (`9515-00-003-6945`) form. Throws [FormatException] on bad input.
  factory Nsn(String input) {
    final stripped = input.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{13}$').hasMatch(stripped)) {
      throw FormatException(
          'NSN must be exactly 13 digits (got ${stripped.length})', input);
    }
    return Nsn._(stripped);
  }

  /// Returns null instead of throwing when [input] is not a valid NSN.
  static Nsn? tryParse(String input) {
    try {
      return Nsn(input);
    } on FormatException {
      return null;
    }
  }

  /// NATO Supply Classification (first 4 digits).
  String get nsc => digits.substring(0, 4);

  /// NATO Supply Group (first 2 digits of the NSC).
  String get supplyGroup => digits.substring(0, 2);

  /// NATO Supply Class (digits 3–4).
  String get supplyClass => digits.substring(2, 4);

  /// National Codification Bureau code (digits 5–6).
  String get ncb => digits.substring(4, 6);

  /// NATO Item Identification Number — the last 9 digits (NCB + item number).
  String get niin => digits.substring(4, 13);

  /// The 7-digit non-significant item number (digits 7–13).
  String get itemNumber => digits.substring(6, 13);

  /// Dashed human-readable form, e.g. `9515-00-003-6945`.
  String get formatted =>
      '$nsc-$ncb-${digits.substring(6, 9)}-${digits.substring(9, 13)}';

  /// The string actually encoded into a barcode: the plain 13 digits.
  String get payload => digits;

  @override
  String toString() => formatted;
}
