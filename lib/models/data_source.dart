import '../encoders/gs1.dart';
import '../encoders/nsn.dart';
import '../encoders/sgtin.dart';
import 'caption.dart';

/// What kind of data the user is encoding.
enum DataSourceKind { rawText, sgtin, nsn }

/// The three SGTIN output representations the app supports.
enum SgtinFormat {
  elementString('GS1 element string'),
  digitalLink('GS1 Digital Link'),
  epcTagUri('EPC Tag URI');

  const SgtinFormat(this.label);
  final String label;
}

/// The outcome of resolving a data source: either an encodable string or a
/// human-readable error to show in the UI.
typedef ResolvedData = ({String? data, String? error});

/// Holds every input field and knows how to turn them into the string that gets
/// encoded into a symbol.
class DataSourceInput {
  final DataSourceKind kind;
  final String rawText;

  // SGTIN inputs
  final String gtin;
  final String serial;
  final SgtinFormat sgtinFormat;
  final int companyPrefixLength;
  final String digitalLinkDomain;

  // NSN input
  final String nsn;

  const DataSourceInput({
    this.kind = DataSourceKind.sgtin,
    this.rawText = 'https://example.com',
    this.gtin = '80614141123458',
    this.serial = '6789',
    this.sgtinFormat = SgtinFormat.digitalLink,
    this.companyPrefixLength = 7,
    this.digitalLinkDomain = 'https://id.gs1.org',
    this.nsn = '9515-00-003-6945',
  });

  DataSourceInput copyWith({
    DataSourceKind? kind,
    String? rawText,
    String? gtin,
    String? serial,
    SgtinFormat? sgtinFormat,
    int? companyPrefixLength,
    String? digitalLinkDomain,
    String? nsn,
  }) {
    return DataSourceInput(
      kind: kind ?? this.kind,
      rawText: rawText ?? this.rawText,
      gtin: gtin ?? this.gtin,
      serial: serial ?? this.serial,
      sgtinFormat: sgtinFormat ?? this.sgtinFormat,
      companyPrefixLength: companyPrefixLength ?? this.companyPrefixLength,
      digitalLinkDomain: digitalLinkDomain ?? this.digitalLinkDomain,
      nsn: nsn ?? this.nsn,
    );
  }

  /// Resolves the encodable string for the current [kind].
  ResolvedData resolve() {
    try {
      return switch (kind) {
        DataSourceKind.rawText => rawText.isEmpty
            ? (data: null, error: 'Enter some text to encode')
            : (data: rawText, error: null),
        DataSourceKind.sgtin => (data: _resolveSgtin(), error: null),
        DataSourceKind.nsn => (data: Nsn(nsn).payload, error: null),
      };
    } on FormatException catch (e) {
      return (data: null, error: e.message);
    } on ArgumentError catch (e) {
      return (data: null, error: e.message.toString());
    }
  }

  /// Encodes the payload for an explicit [format] and/or [serial] override —
  /// used by combined labels (1D = element string, 2D = Digital Link) and by
  /// serialized runs (serial replaced per item). Throws on invalid input.
  String encodeWith({SgtinFormat? format, String? serial}) {
    switch (kind) {
      case DataSourceKind.sgtin:
        final s = Sgtin(gtin: gtin, serial: serial ?? this.serial);
        return switch (format ?? sgtinFormat) {
          SgtinFormat.elementString => s.toElementString(),
          SgtinFormat.digitalLink =>
            s.toDigitalLink(domain: digitalLinkDomain),
          SgtinFormat.epcTagUri =>
            s.toEpcTagUri(companyPrefixLength: companyPrefixLength),
        };
      case DataSourceKind.rawText:
        return serial == null ? rawText : '$rawText$serial';
      case DataSourceKind.nsn:
        return serial ?? Nsn(nsn).payload;
    }
  }

  String _resolveSgtin() {
    final sgtin = Sgtin(gtin: gtin, serial: serial);
    return switch (sgtinFormat) {
      // The encodable GS1-128/DataMatrix data uses the parenthesised AI form;
      // the `barcode` package converts it to FNC1-delimited data.
      SgtinFormat.elementString => sgtin.toElementString(),
      SgtinFormat.digitalLink =>
        sgtin.toDigitalLink(domain: digitalLinkDomain),
      SgtinFormat.epcTagUri =>
        sgtin.toEpcTagUri(companyPrefixLength: companyPrefixLength),
    };
  }

  /// The serialized-number caption shown under the code. For an SGTIN it is the
  /// serial (bold); for an NSN the dashed number; free text has no serial.
  LabelCaption caption() {
    return switch (kind) {
      DataSourceKind.sgtin => LabelCaption(bold: serial),
      DataSourceKind.nsn =>
        LabelCaption(prefix: Nsn.tryParse(nsn)?.formatted ?? nsn),
      DataSourceKind.rawText => const LabelCaption(),
    };
  }

  /// The raw FNC1-delimited bytes for an SGTIN element string, when a caller
  /// needs the true encoded payload (e.g. byte-count display for DataMatrix).
  String? gs1RawOrNull() {
    if (kind != DataSourceKind.sgtin ||
        sgtinFormat != SgtinFormat.elementString) {
      return null;
    }
    try {
      final s = Sgtin(gtin: gtin, serial: serial);
      return Gs1.encode([('01', s.gtin14), ('21', s.serial)]);
    } on FormatException {
      return null;
    }
  }
}
