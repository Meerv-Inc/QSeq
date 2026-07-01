// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'gs1.dart';
import 'gtin.dart';

/// The two EPC binary encoding schemes defined for an SGTIN. They differ in how
/// the serial is carried: [sgtin96] packs a *numeric* serial into at most 38
/// bits, while [sgtin198] carries an *alphanumeric* serial of up to 20 chars.
enum SgtinScheme {
  sgtin96('sgtin-96'),
  sgtin198('sgtin-198');

  const SgtinScheme(this.tag);

  /// The token used in the EPC Tag URI scheme position, e.g. `sgtin-96`.
  final String tag;
}

/// A Serialised GTIN: a GTIN-14 plus a serial number.
///
/// This is the domain object the three SGTIN output encoders consume
/// ([Sgtin.toElementString], [Sgtin.toDigitalLink], [Sgtin.toEpcTagUri]).
class Sgtin {
  /// 14-digit, check-digit-valid GTIN.
  final String gtin14;

  /// Serial number. For an EPC SGTIN-198 this is an alphanumeric string up to
  /// 20 chars; for SGTIN-96 it is numeric up to 38 bits. We keep it as a
  /// string and let the individual encoders enforce their own constraints.
  final String serial;

  const Sgtin._(this.gtin14, this.serial);

  /// Creates an [Sgtin], normalising the GTIN to 14 digits and validating the
  /// serial is non-empty.
  factory Sgtin({required String gtin, required String serial}) {
    final normalized = Gtin.normalize14(gtin);
    if (serial.isEmpty) {
      throw const FormatException('SGTIN serial must not be empty');
    }
    return Sgtin._(normalized, serial);
  }

  /// The packaging-level indicator digit (N1 of the GTIN-14).
  String get indicatorDigit => gtin14[0];

  // --- Output representations -------------------------------------------------

  /// GS1 element string in human-readable form: `(01)<gtin>(21)<serial>`.
  ///
  /// This is the form printed under GS1-128 / GS1 DataMatrix symbols. The raw
  /// bytes actually encoded (with FNC1 separators) are produced by the
  /// renderer, not here.
  String toElementString() => '(01)$gtin14(21)$serial';

  /// GS1 Digital Link URI, e.g.
  /// `https://id.gs1.org/01/<gtin>/21/<serial>`.
  ///
  /// [domain] lets a brand owner substitute their own resolver host. The serial
  /// is percent-encoded per RFC 3986 (the `(21)` value is otherwise free-form).
  String toDigitalLink({String domain = 'https://id.gs1.org'}) {
    final host = domain.endsWith('/')
        ? domain.substring(0, domain.length - 1)
        : domain;
    return '$host/01/$gtin14/21/${Uri.encodeComponent(serial)}';
  }

  /// EPC Tag URI for the chosen binary [scheme], e.g.
  /// `urn:epc:tag:sgtin-198:1.<companyPrefix>.<indicator+itemRef>.<serial>`.
  ///
  /// [companyPrefixLength] is the length (6–12) of the GS1 Company Prefix
  /// embedded in the GTIN; it cannot be inferred from the digits alone and must
  /// be supplied by the user. [filter] (0–7) is the EPC filter value (default 1
  /// = retail point-of-sale item). The indicator digit is moved to the front of
  /// the item-reference field, per GS1 EPC Tag Data Standard §7. The serial is
  /// validated against the [scheme]'s constraints ([checkSerialForScheme]).
  String toEpcTagUri({
    required int companyPrefixLength,
    SgtinScheme scheme = SgtinScheme.sgtin198,
    int filter = 1,
  }) {
    if (companyPrefixLength < 6 || companyPrefixLength > 12) {
      throw ArgumentError.value(
        companyPrefixLength,
        'companyPrefixLength',
        'GS1 Company Prefix length must be between 6 and 12',
      );
    }
    if (filter < 0 || filter > 7) {
      throw ArgumentError.value(filter, 'filter', 'EPC filter must be 0–7');
    }
    checkSerialForScheme(serial, scheme);
    final indicator = gtin14[0];
    // GTIN-14 layout: N1=indicator, N2..N13 = companyPrefix+itemRef, N14=check.
    final companyPrefix = gtin14.substring(1, 1 + companyPrefixLength);
    final itemRef = gtin14.substring(1 + companyPrefixLength, 13);
    final indicatorAndItemRef = '$indicator$itemRef';
    return 'urn:epc:tag:${scheme.tag}:$filter.$companyPrefix.$indicatorAndItemRef.'
        '${_escapeEpcComponent(serial)}';
  }

  /// Largest numeric serial encodable in SGTIN-96: 2^38 − 1.
  static final BigInt _sgtin96MaxSerial = BigInt.from(274877906943);

  /// Validates [serial] against the constraints of [scheme], throwing a
  /// [FormatException] with a human-readable message if it does not fit. Used
  /// by [toEpcTagUri] and by the UI to pre-flight a serial before encoding.
  static void checkSerialForScheme(String serial, SgtinScheme scheme) {
    switch (scheme) {
      case SgtinScheme.sgtin96:
        if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(serial)) {
          throw const FormatException(
            'SGTIN-96 serial must be digits with no leading zero',
          );
        }
        if (BigInt.parse(serial) > _sgtin96MaxSerial) {
          throw const FormatException(
            'SGTIN-96 serial exceeds 38 bits (max 274877906943)',
          );
        }
      case SgtinScheme.sgtin198:
        if (serial.length > 20) {
          throw const FormatException(
            'SGTIN-198 serial must be 20 characters or fewer',
          );
        }
        for (final unit in serial.codeUnits) {
          if (!Gs1.ai82Chars.contains(unit)) {
            throw FormatException(
              'SGTIN-198 serial has an unsupported character',
              String.fromCharCode(unit),
            );
          }
        }
    }
  }

  /// Percent-escapes the characters the EPC Tag Data Standard reserves inside a
  /// URI component — `"`, `%`, `&`, `/`, `<`, `>`, `?` — so a serial carrying one
  /// of them yields a well-formed URN instead of a structurally invalid one
  /// (e.g. a `/` in the serial would otherwise break the three-field grammar).
  /// Other GS1 AI-21 characters (including `.`) are left as-is: the SGTIN URI
  /// has a fixed three-field layout, so a literal dot in the trailing serial is
  /// unambiguous.
  static String _escapeEpcComponent(String s) {
    const escapes = {
      '"': '%22',
      '%': '%25',
      '&': '%26',
      '/': '%2F',
      '<': '%3C',
      '>': '%3E',
      '?': '%3F',
    };
    final out = StringBuffer();
    for (final ch in s.split('')) {
      out.write(escapes[ch] ?? ch);
    }
    return out.toString();
  }
}
