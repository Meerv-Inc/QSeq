// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'gs1.dart';
import 'gtin.dart';

/// The GS1 identifier types [Gs1Keys] can build, beyond the (S)GTIN already
/// covered by [Gtin]/[Sgtin]. Grouped by construction pattern:
///
/// - **Numeric key + optional trailing serial, all in one AI value**: GRAI,
///   GDTI, GCN — a GS1-mod-10-checked numeric key (like a GTIN) that may be
///   followed directly by a serial, with no separate AI 21.
/// - **Complete numeric key, GS1 check digit, no serial**: GLN, SSCC, GSRN,
///   GSIN — the "instance-ness" is already baked into the reference digits.
/// - **Opaque alphanumeric, no check digit**: GIAI, GINC, CPID, GMN —
///   company-assigned free text; QSeq validates length/charset but does not
///   compute a check character (GMN's real check-character-pair algorithm is
///   a distinct, non-mod-10 scheme and is out of scope here).
enum Gs1KeyType {
  grai('8003', 'GRAI', 'Global Returnable Asset Identifier'),
  gdti('253', 'GDTI', 'Global Document Type Identifier'),
  gcn('255', 'GCN', 'Global Coupon Number'),
  gln('414', 'GLN', 'Global Location Number'),
  sscc('00', 'SSCC', 'Serial Shipping Container Code'),
  gsrnProvider('8017', 'GSRN - Provider', 'Global Service Relation Number'),
  gsrnRecipient('8018', 'GSRN - Recipient', 'Global Service Relation Number'),
  gsin('402', 'GSIN', 'Global Shipment Identification Number'),
  giai('8004', 'GIAI', 'Global Individual Asset Identifier'),
  ginc('401', 'GINC', 'Global Identification Number for Consignment'),
  cpid('8010', 'CPID', 'Component/Part Identifier'),
  gmn('8013', 'GMN', 'Global Model Number');

  const Gs1KeyType(this.ai, this.shortTitle, this.fullTitle);

  /// The GS1 Application Identifier this key type is carried under.
  final String ai;

  /// Short label, e.g. "GRAI" — used in compact UI.
  final String shortTitle;

  /// Full GS1 name, e.g. "Global Returnable Asset Identifier".
  final String fullTitle;

  /// True for the "numeric key + optional serial" group (GRAI/GDTI/GCN),
  /// whose builders in [Gs1Keys] accept an optional trailing `serial`.
  bool get supportsSerial =>
      this == Gs1KeyType.grai ||
      this == Gs1KeyType.gdti ||
      this == Gs1KeyType.gcn;
}

/// A built GS1 identifier: the AI it belongs under and its complete value
/// (already check-digited and, where applicable, serial-appended).
class Gs1Identifier {
  final Gs1KeyType type;
  final String value;

  const Gs1Identifier({required this.type, required this.value});

  /// Human-readable element string, e.g. `(8003)00614141000012345XYZ001`.
  String toElementString() => '(${type.ai})$value';

  /// GS1 Digital Link URI, e.g.
  /// `https://id.gs1.org/8003/00614141000012345XYZ001`.
  String toDigitalLink({String domain = 'https://id.gs1.org'}) {
    final host = domain.endsWith('/')
        ? domain.substring(0, domain.length - 1)
        : domain;
    return '$host/${type.ai}/${Uri.encodeComponent(value)}';
  }
}

/// Builds GS1 identifiers for the types listed in [Gs1KeyType]. Every builder
/// throws [FormatException]/[ArgumentError] on invalid input rather than
/// producing a malformed code.
class Gs1Keys {
  Gs1Keys._();

  /// Computes `prefix + reference` as an [totalLength]-digit check-digited
  /// numeric key (GS1 mod-10, via [Gtin.withCheckDigit]).
  static String _numericKey(
    String prefix,
    String reference,
    int totalLength,
    String label,
  ) {
    final data = '$prefix$reference';
    if (!Gtin.isAllDigits(data)) {
      throw FormatException('$label must be numeric', data);
    }
    if (data.length != totalLength - 1) {
      throw FormatException(
        '$label prefix + reference must total ${totalLength - 1} digits '
        '(got ${data.length})',
        data,
      );
    }
    return Gtin.withCheckDigit(data);
  }

  static void _checkSerial(
    String? serial, {
    required bool numericOnly,
    required int maxLength,
    required String label,
  }) {
    if (serial == null || serial.isEmpty) return;
    if (serial.length > maxLength) {
      throw FormatException(
        '$label serial must be $maxLength characters or fewer',
        serial,
      );
    }
    final ok = numericOnly ? Gtin.isAllDigits(serial) : Gs1.isAi82(serial);
    if (!ok) {
      throw FormatException(
        '$label serial has an unsupported character',
        serial,
      );
    }
  }

  static void _checkOpaque(
    String value, {
    required int maxLength,
    required String label,
  }) {
    if (value.isEmpty) throw FormatException('$label value must not be empty');
    if (value.length > maxLength) {
      throw FormatException(
        '$label must be $maxLength characters or fewer',
        value,
      );
    }
    if (!Gs1.isAi82(value)) {
      throw FormatException('$label has an unsupported character', value);
    }
  }

  // --- Numeric key + optional serial ---------------------------------------

  /// GRAI (AI 8003): `0` + [companyPrefix] + [assetType] must total 13
  /// digits; a GS1 check digit is appended (14 digits total), then an
  /// optional alphanumeric [serial] (≤16 chars) for an individual asset.
  static Gs1Identifier grai({
    required String companyPrefix,
    required String assetType,
    String? serial,
  }) {
    final key = _numericKey('0$companyPrefix', assetType, 14, 'GRAI');
    _checkSerial(serial, numericOnly: false, maxLength: 16, label: 'GRAI');
    return Gs1Identifier(
      type: Gs1KeyType.grai,
      value: serial == null || serial.isEmpty ? key : '$key$serial',
    );
  }

  /// GDTI (AI 253): [companyPrefix] + [docType] must total 12 digits; a GS1
  /// check digit is appended (13 digits total), then an optional
  /// alphanumeric [serial] (≤17 chars).
  static Gs1Identifier gdti({
    required String companyPrefix,
    required String docType,
    String? serial,
  }) {
    final key = _numericKey(companyPrefix, docType, 13, 'GDTI');
    _checkSerial(serial, numericOnly: false, maxLength: 17, label: 'GDTI');
    return Gs1Identifier(
      type: Gs1KeyType.gdti,
      value: serial == null || serial.isEmpty ? key : '$key$serial',
    );
  }

  /// GCN (AI 255): [companyPrefix] + [couponRef] must total 12 digits; a
  /// GS1 check digit is appended (13 digits total), then an optional
  /// *numeric* [serial] (≤12 digits — unlike GRAI/GDTI, GCN's serial
  /// component is digits-only per the GS1 spec).
  static Gs1Identifier gcn({
    required String companyPrefix,
    required String couponRef,
    String? serial,
  }) {
    final key = _numericKey(companyPrefix, couponRef, 13, 'GCN');
    _checkSerial(serial, numericOnly: true, maxLength: 12, label: 'GCN');
    return Gs1Identifier(
      type: Gs1KeyType.gcn,
      value: serial == null || serial.isEmpty ? key : '$key$serial',
    );
  }

  // --- Complete numeric key, no serial ---------------------------------------

  /// GLN (AI 414): [companyPrefix] + [locationRef] must total 12 digits;
  /// a GS1 check digit is appended (13 digits total).
  static Gs1Identifier gln({
    required String companyPrefix,
    required String locationRef,
  }) => Gs1Identifier(
    type: Gs1KeyType.gln,
    value: _numericKey(companyPrefix, locationRef, 13, 'GLN'),
  );

  /// SSCC (AI 00): [extensionDigit] (0–9) + [companyPrefix] + [serialRef]
  /// must total 17 digits; a GS1 check digit is appended (18 digits total).
  static Gs1Identifier sscc({
    required int extensionDigit,
    required String companyPrefix,
    required String serialRef,
  }) {
    if (extensionDigit < 0 || extensionDigit > 9) {
      throw ArgumentError.value(
        extensionDigit,
        'extensionDigit',
        'SSCC extension digit must be 0-9',
      );
    }
    return Gs1Identifier(
      type: Gs1KeyType.sscc,
      value: _numericKey(
        '$extensionDigit$companyPrefix',
        serialRef,
        18,
        'SSCC',
      ),
    );
  }

  /// GSRN (AI 8017 provider / 8018 recipient): [companyPrefix] +
  /// [serviceRef] must total 17 digits; a GS1 check digit is appended (18
  /// digits total). [recipient] selects AI 8018 instead of 8017.
  static Gs1Identifier gsrn({
    required String companyPrefix,
    required String serviceRef,
    bool recipient = false,
  }) => Gs1Identifier(
    type: recipient ? Gs1KeyType.gsrnRecipient : Gs1KeyType.gsrnProvider,
    value: _numericKey(companyPrefix, serviceRef, 18, 'GSRN'),
  );

  /// GSIN (AI 402): [companyPrefix] + [shipperRef] must total 16 digits;
  /// a GS1 check digit is appended (17 digits total).
  static Gs1Identifier gsin({
    required String companyPrefix,
    required String shipperRef,
  }) => Gs1Identifier(
    type: Gs1KeyType.gsin,
    value: _numericKey(companyPrefix, shipperRef, 17, 'GSIN'),
  );

  // --- Opaque alphanumeric, no check digit -----------------------------------

  /// GIAI (AI 8004): [companyPrefix] + [assetRef], AI-82 charset, ≤30
  /// characters total. No check digit — the reference itself is the unique
  /// individual-asset identifier.
  static Gs1Identifier giai({
    required String companyPrefix,
    required String assetRef,
  }) {
    final value = '$companyPrefix$assetRef';
    _checkOpaque(value, maxLength: 30, label: 'GIAI');
    return Gs1Identifier(type: Gs1KeyType.giai, value: value);
  }

  /// GINC (AI 401): a free-form consignment identifier, AI-82 charset, ≤30
  /// characters. GS1 does not define an internal structure for it.
  static Gs1Identifier ginc({required String value}) {
    _checkOpaque(value, maxLength: 30, label: 'GINC');
    return Gs1Identifier(type: Gs1KeyType.ginc, value: value);
  }

  /// CPID (AI 8010): [companyPrefix] + [componentRef], AI-82 charset, ≤30
  /// characters total. No check digit.
  static Gs1Identifier cpid({
    required String companyPrefix,
    required String componentRef,
  }) {
    final value = '$companyPrefix$componentRef';
    _checkOpaque(value, maxLength: 30, label: 'CPID');
    return Gs1Identifier(type: Gs1KeyType.cpid, value: value);
  }

  /// GMN (AI 8013): a free-form model number, AI-82 charset, ≤25
  /// characters. GS1 defines a two-character check-character-pair scheme
  /// for GMN that is a distinct, non-mod-10 algorithm; QSeq does not
  /// compute it and only validates length/charset here.
  static Gs1Identifier gmn({required String value}) {
    _checkOpaque(value, maxLength: 25, label: 'GMN');
    return Gs1Identifier(type: Gs1KeyType.gmn, value: value);
  }
}

/// A plain-language explanation of [type]: its full GS1 name, a typical
/// real-world use case, and a breakdown of which fields make up its value
/// and how many digits/characters each contributes — for display under a
/// "GS1 identifier type" picker. [type] null describes the GTIN/SGTIN this
/// whole module is an alternative to.
String gs1KeyStructureDescription(Gs1KeyType? type) => switch (type) {
  null =>
    'GTIN (Global Trade Item Number) — identifies a trade item (a '
        'product or service) at any packaging level, from a single '
        'retail unit to a case or pallet. Structure: GS1 Company Prefix '
        '+ Item Reference + 1 check digit (8, 12, 13 or 14 digits '
        'total). SGTIN adds an optional alphanumeric Serial (≤20 '
        'chars, AI 21) when Serialization is on.',
  Gs1KeyType.grai =>
    'GRAI (Global Returnable Asset Identifier) — identifies a '
        'returnable/reusable asset, e.g. a pallet, keg, tote or gas '
        "cylinder, as it moves between parties. Structure: fixed '0' + "
        'Company Prefix + Asset Type (prefix + asset type = 12 digits) '
        '+ 1 check digit = 14 digits total, plus an optional '
        'alphanumeric Serial (≤16 chars) for an individual asset.',
  Gs1KeyType.gdti =>
    'GDTI (Global Document Type Identifier) — identifies a type of '
        'document, e.g. an insurance policy, boarding pass or ID card; '
        'the optional serial identifies one specific instance of it. '
        'Structure: Company Prefix + Doc Type (= 12 digits) + 1 check '
        'digit = 13 digits total, plus an optional alphanumeric Serial '
        '(≤17 chars).',
  Gs1KeyType.gcn =>
    'GCN (Global Coupon Number) — identifies a specific coupon offer '
        'so it can be validated and redeemed exactly once. Structure: '
        'Company Prefix + Coupon Ref (= 12 digits) + 1 check digit = '
        '13 digits total, plus an optional numeric-only Serial (≤12 '
        'digits).',
  Gs1KeyType.gln =>
    'GLN (Global Location Number) — identifies a physical location or '
        'a legal/functional entity, e.g. a warehouse, store or company '
        'department. Structure: Company Prefix + Location Ref (= 12 '
        'digits) + 1 check digit = 13 digits total. No serial.',
  Gs1KeyType.sscc =>
    'SSCC (Serial Shipping Container Code) — identifies one specific '
        'logistics unit, e.g. a pallet or shipping carton, for '
        'tracking through the supply chain. Structure: 1 extension '
        'digit (0–9) + Company Prefix + Serial Ref (extension + '
        'prefix + ref = 17 digits) + 1 check digit = 18 digits total.',
  Gs1KeyType.gsrnProvider || Gs1KeyType.gsrnRecipient =>
    'GSRN (Global Service Relation Number) — identifies a service '
        'relationship, e.g. a loyalty card, patient or subscription; '
        'Provider identifies who delivers the service, Recipient '
        'identifies who receives it. Structure: Company Prefix + '
        'Service Ref (= 17 digits) + 1 check digit = 18 digits total.',
  Gs1KeyType.gsin =>
    'GSIN (Global Shipment Identification Number) — identifies an '
        'entire shipment made up of one or more logistics units '
        '(SSCCs) moving together from shipper to consignee. '
        'Structure: Company Prefix + Shipper Ref (= 16 digits) + 1 '
        'check digit = 17 digits total.',
  Gs1KeyType.giai =>
    'GIAI (Global Individual Asset Identifier) — identifies one '
        'specific fixed or individual asset, e.g. equipment, a '
        'computer or a tool, for asset management and maintenance '
        'tracking. Structure: Company Prefix + Individual Asset Ref, '
        'up to 30 alphanumeric characters total. No check digit — the '
        'reference itself is the unique identifier.',
  Gs1KeyType.ginc =>
    'GINC (Global Identification Number for Consignment) — '
        'identifies a consignment: freight brought together for '
        'transport under one transport document, e.g. a groupage/LCL '
        'shipment. Structure: a free-form identifier, up to 30 '
        'alphanumeric characters. GS1 defines no internal structure.',
  Gs1KeyType.cpid =>
    'CPID (Component/Part Identifier) — identifies a component or '
        'part within a product; used in some industries (e.g. '
        'aerospace, automotive) for traceability down to the part '
        'level. Structure: Company Prefix + Component/Part Ref, up to '
        '30 alphanumeric characters total. No check digit.',
  Gs1KeyType.gmn =>
    'GMN (Global Model Number) — identifies a product model/catalog '
        'entry, notably for medical devices under EU MDR/IVDR '
        'regulatory requirements. Structure: a free-form model '
        "number, up to 25 alphanumeric characters. (GS1's official "
        'check-character pair is not computed by QSeq.)',
};
