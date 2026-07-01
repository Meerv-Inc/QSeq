// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'gs1.dart';
import 'gtin.dart';

/// The role a GS1 Application Identifier plays inside a GS1 Digital Link URI.
///
/// [identifier] AIs are the primary key and must be the first AI/value pair
/// in the path. [qualifier] AIs are additional path segments that narrow the
/// identifier (e.g. serial, batch/lot) and must appear in a fixed order.
/// [attribute] AIs carry non-identifying data and appear as query-string
/// parameters (e.g. `?17=251231` for an expiry date).
enum Gs1AiRole { identifier, qualifier, attribute }

/// One entry in the (intentionally focused, not exhaustive — see
/// [Gs1AiTable]) GS1 Application Identifier registry: the rules needed to
/// validate a value carried by that AI in a GS1 Digital Link.
class Gs1AiDef {
  final String code;
  final String title;
  final Gs1AiRole role;

  /// Exact required value length, or null if the value is variable-length.
  final int? fixedLength;

  /// Maximum value length, for variable-length AIs.
  final int? maxLength;

  /// True if the value must be all digits; false if it may use the GS1
  /// AI-82 alphanumeric character set ([Gs1.isAi82]).
  final bool numeric;

  /// True if a GS1 mod-10 check digit applies (validated with [Gtin.isValid]
  /// over the leading [checkDigitPrefixLength] characters of the value).
  final bool checkDigit;

  /// For composite AIs (e.g. ITIP, GDTI, GCN, GRAI) whose value is a
  /// check-digited numeric key followed by a free-form serial, the length of
  /// that leading numeric key. Null means the check digit spans the whole
  /// value (GTIN, SSCC, GLN, GSIN, GSRN).
  final int? checkDigitPrefixLength;

  /// For a [Gs1AiRole.qualifier], the set of primary identifier AI codes it
  /// is valid under.
  final Set<String> qualifierFor;

  /// For a [Gs1AiRole.qualifier], its position in the canonical GS1 Digital
  /// Link qualifier order (lower sorts first). Ignored for other roles.
  final int qualifierOrder;

  const Gs1AiDef({
    required this.code,
    required this.title,
    required this.role,
    this.fixedLength,
    this.maxLength,
    this.numeric = true,
    this.checkDigit = false,
    this.checkDigitPrefixLength,
    this.qualifierFor = const {},
    this.qualifierOrder = 0,
  });

  /// Validates [value] against this AI's rules, returning a human-readable
  /// problem description, or null if the value is valid.
  String? validate(String value) {
    if (value.isEmpty) return '$title ($code) value must not be empty';
    if (fixedLength != null && value.length != fixedLength) {
      return '$title ($code) must be exactly $fixedLength characters '
          '(got ${value.length})';
    }
    if (maxLength != null && value.length > maxLength!) {
      return '$title ($code) must be $maxLength characters or fewer '
          '(got ${value.length})';
    }
    final charsetOk = numeric ? Gtin.isAllDigits(value) : Gs1.isAi82(value);
    if (!charsetOk) {
      return numeric
          ? '$title ($code) must be numeric'
          : '$title ($code) has an unsupported character';
    }
    if (checkDigit) {
      final prefixLen = checkDigitPrefixLength ?? value.length;
      if (value.length < prefixLen ||
          !Gtin.isValid(value.substring(0, prefixLen))) {
        return '$title ($code) check digit is invalid';
      }
    }
    return null;
  }
}

/// A focused registry of GS1 Application Identifiers relevant to GS1 Digital
/// Link validation: the primary identification keys the standard defines,
/// the GTIN/ITIP key qualifiers, and a practical set of data attributes.
///
/// This is not the full ~100+ entry GS1 AI registry (as shipped by e.g.
/// evrythng/digital-link.js) — it covers what a Digital Link actually needs
/// to be structurally validated. The table is a plain map so more AIs can be
/// added later without changing [DigitalLink]'s parsing logic.
class Gs1AiTable {
  Gs1AiTable._();

  static const Map<String, Gs1AiDef> byCode = {
    // --- Primary identifiers -------------------------------------------------
    '00': Gs1AiDef(
      code: '00',
      title: 'SSCC',
      role: Gs1AiRole.identifier,
      fixedLength: 18,
      checkDigit: true,
    ),
    '01': Gs1AiDef(
      code: '01',
      title: 'GTIN',
      role: Gs1AiRole.identifier,
      fixedLength: 14,
      checkDigit: true,
    ),
    '253': Gs1AiDef(
      code: '253',
      title: 'GDTI',
      role: Gs1AiRole.identifier,
      maxLength: 30,
      numeric: false,
      checkDigit: true,
      checkDigitPrefixLength: 13,
    ),
    '255': Gs1AiDef(
      code: '255',
      title: 'GCN',
      role: Gs1AiRole.identifier,
      maxLength: 25,
      numeric: false,
      checkDigit: true,
      checkDigitPrefixLength: 13,
    ),
    '401': Gs1AiDef(
      code: '401',
      title: 'GINC',
      role: Gs1AiRole.identifier,
      maxLength: 30,
      numeric: false,
    ),
    '402': Gs1AiDef(
      code: '402',
      title: 'GSIN',
      role: Gs1AiRole.identifier,
      fixedLength: 17,
      checkDigit: true,
    ),
    '414': Gs1AiDef(
      code: '414',
      title: 'GLN',
      role: Gs1AiRole.identifier,
      fixedLength: 13,
      checkDigit: true,
    ),
    '415': Gs1AiDef(
      code: '415',
      title: 'GLN (Invoicing Party)',
      role: Gs1AiRole.identifier,
      fixedLength: 13,
      checkDigit: true,
    ),
    '417': Gs1AiDef(
      code: '417',
      title: 'GLN (Party)',
      role: Gs1AiRole.identifier,
      fixedLength: 13,
      checkDigit: true,
    ),
    '8003': Gs1AiDef(
      code: '8003',
      title: 'GRAI',
      role: Gs1AiRole.identifier,
      maxLength: 30,
      numeric: false,
      checkDigit: true,
      checkDigitPrefixLength: 14,
    ),
    '8004': Gs1AiDef(
      code: '8004',
      title: 'GIAI',
      role: Gs1AiRole.identifier,
      maxLength: 30,
      numeric: false,
    ),
    '8006': Gs1AiDef(
      code: '8006',
      title: 'ITIP',
      role: Gs1AiRole.identifier,
      fixedLength: 18,
      checkDigit: true,
      checkDigitPrefixLength: 14,
    ),
    '8010': Gs1AiDef(
      code: '8010',
      title: 'CPID',
      role: Gs1AiRole.identifier,
      maxLength: 30,
      numeric: false,
    ),
    '8013': Gs1AiDef(
      code: '8013',
      title: 'GMN',
      role: Gs1AiRole.identifier,
      maxLength: 25,
      numeric: false,
    ),
    '8017': Gs1AiDef(
      code: '8017',
      title: 'GSRN - Provider',
      role: Gs1AiRole.identifier,
      fixedLength: 18,
      checkDigit: true,
    ),
    '8018': Gs1AiDef(
      code: '8018',
      title: 'GSRN - Recipient',
      role: Gs1AiRole.identifier,
      fixedLength: 18,
      checkDigit: true,
    ),

    // --- Qualifiers (path-only; canonical order CPV -> lot -> serial) -------
    '22': Gs1AiDef(
      code: '22',
      title: 'CPV',
      role: Gs1AiRole.qualifier,
      maxLength: 20,
      numeric: false,
      qualifierFor: {'01', '8006'},
      qualifierOrder: 0,
    ),
    '10': Gs1AiDef(
      code: '10',
      title: 'BATCH/LOT',
      role: Gs1AiRole.qualifier,
      maxLength: 20,
      numeric: false,
      qualifierFor: {'01', '8006'},
      qualifierOrder: 1,
    ),
    '21': Gs1AiDef(
      code: '21',
      title: 'SERIAL NUMBER',
      role: Gs1AiRole.qualifier,
      maxLength: 20,
      numeric: false,
      qualifierFor: {'01', '8006'},
      qualifierOrder: 2,
    ),

    // --- Attributes (query-string only) --------------------------------------
    '11': Gs1AiDef(
      code: '11',
      title: 'PROD DATE',
      role: Gs1AiRole.attribute,
      fixedLength: 6,
    ),
    '13': Gs1AiDef(
      code: '13',
      title: 'PACK DATE',
      role: Gs1AiRole.attribute,
      fixedLength: 6,
    ),
    '15': Gs1AiDef(
      code: '15',
      title: 'BEST BEFORE',
      role: Gs1AiRole.attribute,
      fixedLength: 6,
    ),
    '16': Gs1AiDef(
      code: '16',
      title: 'SELL BY',
      role: Gs1AiRole.attribute,
      fixedLength: 6,
    ),
    '17': Gs1AiDef(
      code: '17',
      title: 'USE BY / EXPIRY',
      role: Gs1AiRole.attribute,
      fixedLength: 6,
    ),
    '20': Gs1AiDef(
      code: '20',
      title: 'VARIANT',
      role: Gs1AiRole.attribute,
      fixedLength: 2,
    ),
    '30': Gs1AiDef(
      code: '30',
      title: 'VAR. COUNT',
      role: Gs1AiRole.attribute,
      maxLength: 8,
    ),
    '422': Gs1AiDef(
      code: '422',
      title: 'COUNTRY OF ORIGIN',
      role: Gs1AiRole.attribute,
      fixedLength: 3,
    ),
  };
}

/// The severity of a [DigitalLinkIssue].
enum DigitalLinkSeverity { error, warning }

/// One problem found while parsing/validating a GS1 Digital Link.
class DigitalLinkIssue {
  final DigitalLinkSeverity severity;
  final String message;

  const DigitalLinkIssue(this.severity, this.message);

  @override
  String toString() => message;
}

/// One AI/value pair decoded from a GS1 Digital Link, with its registry entry
/// ([def]) when the AI is recognized (null otherwise).
class Gs1AiValue {
  final String ai;
  final String value;
  final Gs1AiDef? def;

  const Gs1AiValue(this.ai, this.value, this.def);

  String get title => def?.title ?? 'Unknown AI';
}

/// The outcome of [DigitalLink.parse]: everything decoded from the URI, plus
/// every structural or format problem found. Parsing never throws — a
/// malformed input still yields a result, just one with `issues` populated,
/// so a caller (e.g. a validator UI) can show every problem at once instead
/// of stopping at the first one.
class DigitalLinkResult {
  /// The parsed URI, or null if [input] wasn't parseable as a URI at all.
  final Uri? uri;

  /// Path segments preceding the primary identifier (e.g. a custom resolver
  /// prefix), joined with `/`. Empty if the identifier is the first segment.
  final String pathStem;

  final Gs1AiValue? identifier;
  final List<Gs1AiValue> qualifiers;

  /// GS1 AI attributes carried as query-string parameters, keyed by AI code.
  final Map<String, Gs1AiValue> attributes;

  /// Non-GS1 query-string parameters (custom/tracking params etc.).
  final Map<String, String> other;

  final List<DigitalLinkIssue> issues;

  /// An ordered, human-readable trace of every parsing/validation step that
  /// was performed and its outcome — e.g. "Identifier AI 01 (GTIN) =
  /// '80614141123458' — length 14 == 14, numeric, check digit 8 matches".
  /// Meant to drive a validation-log UI that shows *why* a link passed or
  /// failed, not just the final verdict.
  final List<String> trace;

  const DigitalLinkResult({
    required this.uri,
    required this.pathStem,
    required this.identifier,
    required this.qualifiers,
    required this.attributes,
    required this.other,
    required this.issues,
    required this.trace,
  });

  /// True iff no [DigitalLinkSeverity.error] issue was found. Warnings alone
  /// (e.g. an unrecognized AI) do not make a link invalid.
  bool get isValid =>
      issues.every((i) => i.severity != DigitalLinkSeverity.error);
}

/// Parses and validates a GS1 Digital Link URI, modeled on the parse
/// structure of `evrythng/digital-link.js` (identifier / key qualifiers /
/// attributes / other), adapted to Dart's [Uri] and QSeq's existing GS1
/// helpers ([Gtin], [Gs1]).
class DigitalLink {
  DigitalLink._();

  /// Parses [input] into a [DigitalLinkResult]. Never throws: structural or
  /// format problems are collected into `result.issues` instead, and every
  /// step taken is recorded into `result.trace` for a validation-log UI.
  static DigitalLinkResult parse(String input) {
    final issues = <DigitalLinkIssue>[];
    final trace = <String>[];
    Uri? uri;
    try {
      uri = Uri.parse(input.trim());
    } on FormatException {
      uri = null;
    }
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      const msg = 'Not a well-formed absolute URI (missing scheme or host)';
      issues.add(const DigitalLinkIssue(DigitalLinkSeverity.error, msg));
      trace.add('✗ $msg');
      return DigitalLinkResult(
        uri: uri,
        pathStem: '',
        identifier: null,
        qualifiers: const [],
        attributes: const {},
        other: const {},
        issues: issues,
        trace: trace,
      );
    }
    trace.add(
      '✓ Parsed as an absolute URI: scheme=${uri.scheme}, host=${uri.host}',
    );

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    var startIndex = -1;
    for (var i = 0; i < segments.length; i++) {
      final def = Gs1AiTable.byCode[segments[i]];
      if (def != null && def.role == Gs1AiRole.identifier) {
        startIndex = i;
        break;
      }
    }

    Gs1AiValue? identifier;
    final qualifiers = <Gs1AiValue>[];
    var pathStem = '';

    if (startIndex == -1) {
      const msg = 'No recognized GS1 primary identifier found in the path';
      issues.add(const DigitalLinkIssue(DigitalLinkSeverity.error, msg));
      trace.add('✗ $msg');
    } else {
      if (startIndex > 0) {
        pathStem = segments.sublist(0, startIndex).join('/');
        trace.add(
          "Path stem before the identifier: '$pathStem' "
          '(e.g. a custom resolver prefix — not itself validated)',
        );
      }
      final aiSegments = segments.sublist(startIndex);
      if (aiSegments.length.isOdd) {
        const msg =
            'Path has an odd number of segments; every AI must have a value';
        issues.add(const DigitalLinkIssue(DigitalLinkSeverity.error, msg));
        trace.add('✗ $msg');
      }
      final pairCount = aiSegments.length ~/ 2;
      Gs1AiDef? primaryDef;
      final seenQualifiers = <String>{};
      var lastOrder = -1;
      for (var i = 0; i < pairCount; i++) {
        final ai = aiSegments[i * 2];
        final value = aiSegments[i * 2 + 1];
        final def = Gs1AiTable.byCode[ai];
        final v = Gs1AiValue(ai, value, def);

        if (i == 0) {
          identifier = v;
          primaryDef = (def != null && def.role == Gs1AiRole.identifier)
              ? def
              : null;
          if (primaryDef == null) {
            final msg = 'AI $ai is not a recognized GS1 primary identifier';
            issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, msg));
            trace.add('✗ $msg');
          } else {
            final problem = primaryDef.validate(value);
            if (problem != null) {
              issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, problem));
              trace.add(
                "✗ Identifier AI $ai (${primaryDef.title}) = '$value' — "
                '$problem',
              );
            } else {
              trace.add(
                "✓ Identifier AI $ai (${primaryDef.title}) = '$value' — "
                '${_okDetail(primaryDef, value)}',
              );
            }
          }
          continue;
        }

        qualifiers.add(v);
        if (def == null || def.role != Gs1AiRole.qualifier) {
          final msg = 'AI $ai is not a recognized GS1 qualifier';
          issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, msg));
          trace.add("✗ AI $ai = '$value' — $msg");
          continue;
        }
        var qualifierOk = true;
        if (primaryDef != null && !def.qualifierFor.contains(primaryDef.code)) {
          final msg =
              'AI $ai (${def.title}) is not a valid qualifier for '
              'identifier ${primaryDef.code}';
          issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, msg));
          trace.add('✗ $msg');
          qualifierOk = false;
        }
        if (!seenQualifiers.add(ai)) {
          final msg = 'Qualifier AI $ai appears more than once';
          issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, msg));
          trace.add('✗ $msg');
          qualifierOk = false;
        }
        if (def.qualifierOrder < lastOrder) {
          final msg = 'Qualifier AI $ai (${def.title}) is out of order';
          issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, msg));
          trace.add('✗ $msg');
          qualifierOk = false;
        }
        lastOrder = def.qualifierOrder;
        final problem = def.validate(value);
        if (problem != null) {
          issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, problem));
          trace.add("✗ Qualifier AI $ai (${def.title}) = '$value' — $problem");
        } else if (qualifierOk) {
          trace.add(
            "✓ Qualifier AI $ai (${def.title}) = '$value' — valid for "
            'identifier ${primaryDef?.code}, correctly ordered, '
            '${_okDetail(def, value)}',
          );
        }
      }
    }

    final attributes = <String, Gs1AiValue>{};
    final other = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (!Gtin.isAllDigits(key)) {
        other[key] = value;
        trace.add(
          "Query param '$key=$value' is not a numeric GS1 AI — treated as "
          'a custom parameter',
        );
        return;
      }
      final def = Gs1AiTable.byCode[key];
      if (def == null) {
        final msg = 'Unrecognized GS1 AI "$key" in query string';
        issues.add(DigitalLinkIssue(DigitalLinkSeverity.warning, msg));
        trace.add('⚠ $msg');
        attributes[key] = Gs1AiValue(key, value, null);
        return;
      }
      attributes[key] = Gs1AiValue(key, value, def);
      final problem = def.validate(value);
      if (problem != null) {
        issues.add(DigitalLinkIssue(DigitalLinkSeverity.error, problem));
        trace.add("✗ Attribute AI $key (${def.title}) = '$value' — $problem");
      } else {
        trace.add(
          "✓ Attribute AI $key (${def.title}) = '$value' — "
          '${_okDetail(def, value)}',
        );
      }
    });

    final errorCount = issues
        .where((i) => i.severity == DigitalLinkSeverity.error)
        .length;
    trace.add(
      errorCount == 0
          ? '✓ RESULT: VALID'
          : '✗ RESULT: INVALID '
                '($errorCount error${errorCount == 1 ? '' : 's'})',
    );

    return DigitalLinkResult(
      uri: uri,
      pathStem: pathStem,
      identifier: identifier,
      qualifiers: qualifiers,
      attributes: attributes,
      other: other,
      issues: issues,
      trace: trace,
    );
  }

  /// A short, human-readable description of the checks a value passed for
  /// [def] — composes a trace line explaining *why* an AI value is
  /// considered valid (length, charset, check digit).
  static String _okDetail(Gs1AiDef def, String value) {
    final parts = <String>[];
    if (def.fixedLength != null) {
      parts.add('length ${value.length} == ${def.fixedLength}');
    } else if (def.maxLength != null) {
      parts.add('length ${value.length} ≤ ${def.maxLength}');
    }
    parts.add(def.numeric ? 'numeric' : 'AI-82 charset');
    if (def.checkDigit) {
      final prefixLen = def.checkDigitPrefixLength ?? value.length;
      final prefix = value.substring(0, prefixLen);
      final expected = Gtin.checkDigit(prefix.substring(0, prefix.length - 1));
      parts.add('check digit $expected matches');
    }
    return parts.join(', ');
  }
}
