// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import '../encoders/gs1.dart';
import '../encoders/gtin.dart';
import '../encoders/sgtin.dart';
import 'caption.dart';
import 'symbology.dart';

/// What kind of data the user is encoding. [sgtin] is the GS1 product source:
/// a GTIN that becomes a *serialised* GTIN (SGTIN) when [DataSourceInput.serialize]
/// is on. (The enum name is kept for project-file compatibility.)
enum DataSourceKind { rawText, sgtin }

/// The SGTIN output representations the app supports. [elementString] is the
/// `(01)…(21)…` form carried by a GS1-128 / DataMatrix symbol; [sgtin96] and
/// [sgtin198] are the two EPC binary encodings, rendered as EPC Tag URIs.
enum SgtinFormat {
  elementString('GS1-128'),
  digitalLink('GS1 Digital Link'),
  sgtin96('SGTIN-96'),
  sgtin198('SGTIN-198');

  const SgtinFormat(this.label);
  final String label;

  /// The EPC binary scheme this format encodes to, or null for the non-EPC
  /// representations (element string, Digital Link).
  SgtinScheme? get epcScheme => switch (this) {
        sgtin96 => SgtinScheme.sgtin96,
        sgtin198 => SgtinScheme.sgtin198,
        _ => null,
      };
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

  /// The GTIN length (8/12/13/14) the length selector is set to. Guides the
  /// input field's example/placeholder and the "generate a valid GTIN" action;
  /// the validator itself still accepts any valid GTIN length.
  final int gtinLength;

  /// When true, the GTIN carries a serial number — i.e. it is a *serialised*
  /// GTIN (SGTIN). This is the master switch the "Serialization" checkbox drives:
  /// it gates the serial, the EPC SGTIN-96/198 formats and the serialized run.
  /// When false the source is a plain class-level GTIN: `(01)<gtin>`, Digital
  /// Link `/01/<gtin>`, or a native retail EAN/UPC — no serial.
  final bool serialize;

  const DataSourceInput({
    this.kind = DataSourceKind.sgtin,
    this.rawText = 'https://example.com',
    this.gtin = '80614141123458',
    this.serial = '6789',
    this.sgtinFormat = SgtinFormat.digitalLink,
    this.companyPrefixLength = 7,
    this.digitalLinkDomain = 'https://id.gs1.org',
    this.gtinLength = 14,
    this.serialize = true,
  });

  DataSourceInput copyWith({
    DataSourceKind? kind,
    String? rawText,
    String? gtin,
    String? serial,
    SgtinFormat? sgtinFormat,
    int? companyPrefixLength,
    String? digitalLinkDomain,
    int? gtinLength,
    bool? serialize,
  }) {
    return DataSourceInput(
      kind: kind ?? this.kind,
      rawText: rawText ?? this.rawText,
      gtin: gtin ?? this.gtin,
      serial: serial ?? this.serial,
      sgtinFormat: sgtinFormat ?? this.sgtinFormat,
      companyPrefixLength: companyPrefixLength ?? this.companyPrefixLength,
      digitalLinkDomain: digitalLinkDomain ?? this.digitalLinkDomain,
      gtinLength: gtinLength ?? this.gtinLength,
      serialize: serialize ?? this.serialize,
    );
  }

  /// Resolves the encodable string for the current [kind].
  ResolvedData resolve() {
    try {
      return switch (kind) {
        DataSourceKind.rawText => rawText.isEmpty
            ? (data: null, error: 'Enter some text to encode')
            : (data: rawText, error: null),
        DataSourceKind.sgtin => (data: _encodeProduct(), error: null),
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
        return _encodeProduct(format: format, serial: serial);
      case DataSourceKind.rawText:
        return serial == null ? rawText : '$rawText$serial';
    }
  }

  /// Encodes the GS1 product source. When [serialize] is on it is a serialised
  /// GTIN (SGTIN) carrying the serial and able to use the EPC schemes; when off
  /// it is a plain class-level GTIN with no `(21)` serial and no EPC form.
  String _encodeProduct({SgtinFormat? format, String? serial}) {
    final fmt = format ?? sgtinFormat;
    if (serialize) {
      final s = Sgtin(gtin: gtin, serial: serial ?? this.serial);
      return switch (fmt) {
        SgtinFormat.elementString => s.toElementString(),
        SgtinFormat.digitalLink => s.toDigitalLink(domain: digitalLinkDomain),
        SgtinFormat.sgtin96 || SgtinFormat.sgtin198 => s.toEpcTagUri(
            companyPrefixLength: companyPrefixLength, scheme: fmt.epcScheme!),
      };
    }
    // Plain GTIN — no serial. The EPC schemes need a serial, so they fall back
    // to the Digital Link (the UI hides them when serialization is off). The
    // GTIN is normalised to the canonical 14-digit form (leading zeros).
    final g14 = Gtin.normalize14(gtin);
    return switch (fmt) {
      SgtinFormat.elementString => '(01)$g14',
      SgtinFormat.digitalLink ||
      SgtinFormat.sgtin96 ||
      SgtinFormat.sgtin198 =>
        _gtinDigitalLink(g14),
    };
  }

  String _gtinDigitalLink(String g14) {
    final host = digitalLinkDomain.endsWith('/')
        ? digitalLinkDomain.substring(0, digitalLinkDomain.length - 1)
        : digitalLinkDomain;
    return '$host/01/$g14';
  }

  /// The encodable payload for [sym], honouring each symbology's constraints:
  /// 2D and GS1-128 carry the full SGTIN form; retail 1D codes
  /// (EAN-13 / EAN-8 / UPC-A) carry the *native trailing* GTIN-N; other 1D codes
  /// carry the bare GTIN-14 (serial dropped). For free text it returns the text,
  /// with [serial] appended when given. Returns null when nothing valid can be
  /// encoded.
  String? payloadFor(Symbology sym, {String? serial}) {
    if (kind != DataSourceKind.sgtin) {
      final r = resolve();
      if (r.data == null) return null;
      return serial == null ? r.data : encodeWith(serial: serial);
    }
    try {
      if (sym.is2D) return encodeWith(serial: serial);
      if (sym == Symbology.gs1_128) {
        return encodeWith(format: SgtinFormat.elementString, serial: serial);
      }
      final g14 = Gtin.normalize14(gtin);
      final len = switch (sym) {
        Symbology.ean13 => 13,
        Symbology.ean8 => 8,
        Symbology.upcA => 12,
        _ => 14, // code128, code39 — bare GTIN-14, serial dropped
      };
      if (len == 14) return g14;
      // Retail symbols carry the native GTIN-N: the trailing N digits of the
      // GTIN-14 (a GTIN-8/12/13 normalises to leading zeros, so this round-trips
      // exactly); the check digit is recomputed so a longer GTIN still yields a
      // valid (truncated) symbol instead of overflowing.
      return Gtin.withCheckDigit(g14.substring(14 - len, 13));
    } catch (_) {
      return null;
    }
  }

  /// The serialized-number caption shown under the code. For an SGTIN it is the
  /// serial (bold); free text has no serial.
  LabelCaption caption() {
    return switch (kind) {
      DataSourceKind.sgtin =>
        serialize ? LabelCaption(bold: serial) : const LabelCaption(),
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
      if (serialize) {
        final s = Sgtin(gtin: gtin, serial: serial);
        return Gs1.encode([('01', s.gtin14), ('21', s.serial)]);
      }
      return Gs1.encode([('01', Gtin.normalize14(gtin))]);
    } on FormatException {
      return null;
    }
  }
}
