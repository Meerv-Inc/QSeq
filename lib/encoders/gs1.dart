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
}
