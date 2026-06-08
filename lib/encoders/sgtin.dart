import 'gtin.dart';

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

  /// EPC Tag URI (pure-identity URN):
  /// `urn:epc:id:sgtin:<companyPrefix>.<indicator+itemRef>.<serial>`.
  ///
  /// [companyPrefixLength] is the length (6–12) of the GS1 Company Prefix
  /// embedded in the GTIN; it cannot be inferred from the digits alone and must
  /// be supplied by the user. The indicator digit is moved to the front of the
  /// item-reference field, per GS1 EPC Tag Data Standard §7.
  String toEpcTagUri({required int companyPrefixLength}) {
    if (companyPrefixLength < 6 || companyPrefixLength > 12) {
      throw ArgumentError.value(companyPrefixLength, 'companyPrefixLength',
          'GS1 Company Prefix length must be between 6 and 12');
    }
    final indicator = gtin14[0];
    // GTIN-14 layout: N1=indicator, N2..N13 = companyPrefix+itemRef, N14=check.
    final companyPrefix = gtin14.substring(1, 1 + companyPrefixLength);
    final itemRef = gtin14.substring(1 + companyPrefixLength, 13);
    final indicatorAndItemRef = '$indicator$itemRef';
    return 'urn:epc:id:sgtin:$companyPrefix.$indicatorAndItemRef.$serial';
  }
}
