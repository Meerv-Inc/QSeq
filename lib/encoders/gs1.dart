// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/// Helpers for turning GS1 Application Identifier (AI) data into the raw bytes
/// a GS1-128 or GS1 DataMatrix symbol actually encodes.
///
/// The human-readable element string uses parentheses — `(01)...(21)...` — but
/// the encoded data uses the FNC1 function character: one in the first position
/// (the GS1 mode flag) and one after every variable-length field that is not
/// the last field in the message.
class Gs1 {
  Gs1._();

  /// The character the `barcode` package interprets as FNC1 (GS1 mode).
  /// `barcode` uses Unicode 0xF1 inside the data string as the FNC1 marker.
  static const String fnc1 = 'ñ';

  /// AIs whose value is fixed-length and therefore never need a trailing FNC1.
  /// Length is the *value* length (excluding the AI digits themselves).
  static const Map<String, int> _fixedLengthValue = {
    '00': 18,
    '01': 14,
    '02': 14,
    '11': 6,
    '12': 6,
    '13': 6,
    '15': 6,
    '17': 6,
    '20': 2,
  };

  /// Returns true if [ai] has a predefined fixed value length.
  static bool isFixedLength(String ai) => _fixedLengthValue.containsKey(ai);

  /// Builds the raw encodable data string for an ordered list of (AI, value)
  /// pairs, inserting a leading FNC1 and FNC1 separators after variable-length
  /// fields that are followed by more data.
  ///
  /// Example: `[('01','80614141123454'), ('21','6789')]` →
  /// `<FNC1>0180614141123454216789` (no trailing FNC1: 21 is the last field).
  static String encode(List<(String ai, String value)> pairs) {
    final buf = StringBuffer(fnc1);
    for (var i = 0; i < pairs.length; i++) {
      final (ai, value) = pairs[i];
      buf.write(ai);
      buf.write(value);
      final isLast = i == pairs.length - 1;
      if (!isFixedLength(ai) && !isLast) {
        buf.write(fnc1);
      }
    }
    return buf.toString();
  }

  /// Human-readable element string with parenthesised AIs, e.g.
  /// `(01)80614141123454(21)6789`.
  static String elementString(List<(String ai, String value)> pairs) =>
      pairs.map((p) => '(${p.$1})${p.$2}').join();

  /// The 82-character set ("AI-82") GS1 permits in alphanumeric AI values —
  /// batch/lot, serial, CPV and similar fields: digits, upper- and lower-case
  /// letters and a fixed punctuation subset
  /// (`! " % & ' ( ) * + , - . / : ; < = > ? _`).
  static final Set<int> ai82Chars = {
    for (final c in [
      0x21,
      0x22,
      0x25,
      0x26,
      0x27,
      0x28,
      0x29,
      0x2A,
      0x2B,
      0x2C,
      0x2D,
      0x2E,
      0x2F,
      0x3A,
      0x3B,
      0x3C,
      0x3D,
      0x3E,
      0x3F,
      0x5F,
    ])
      c,
    for (var c = 0x30; c <= 0x39; c++) c, // 0–9
    for (var c = 0x41; c <= 0x5A; c++) c, // A–Z
    for (var c = 0x61; c <= 0x7A; c++) c, // a–z
  };

  /// Returns true if every character of [value] is in the AI-82 set.
  static bool isAi82(String value) => value.codeUnits.every(ai82Chars.contains);
}
