// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// .qseq project files — the same JSON schema the desktop app and the previous
// web app exchange, plus a web-only `label` block for the label designer.
import 'dart:convert';

import 'package:qseq_core/qseq_core.dart';

import 'generate.dart';
import 'label.dart';

const _modeTo = {
  WebMode.twoD: 'twoD',
  WebMode.twoDSerial: 'twoDSerial',
  WebMode.oneD: 'oneD',
  WebMode.oneDSerial: 'oneDSerial',
  WebMode.combo: 'combo',
  WebMode.comboSerial: 'comboSerial',
  WebMode.label: 'label',
  WebMode.labelSerial: 'labelSerial',
};

WebMode modeFrom(String? v) =>
    _modeTo.entries
        .where((e) => e.value == v)
        .map((e) => e.key)
        .firstOrNull ??
    WebMode.twoD;

const _ecTo = {
  QrEcLevel.low: 'low',
  QrEcLevel.medium: 'medium',
  QrEcLevel.quartile: 'quartile',
  QrEcLevel.high: 'high',
};

String projectJson({
  required GenInput i,
  required SerialSpec ss,
  required SheetSpec sheet,
  required LabelSpec label,
  required double logoSideMm,
}) {
  final d = i.data;
  final proj = {
    'format': 'QSeq Project',
    'version': 1,
    'workspace': {
      'mode': _modeTo[i.mode],
      'oneDSymbology': i.oneDSym.name,
      'twoDSymbology': i.twoD.name,
      'errorCorrection': _ecTo[i.ec],
      'arrangement': i.arrangement.name,
      'labelGapMm': i.gapMm,
      'labelPaddingMm': i.padMm,
    },
    'data': {
      'kind': d.kind.name,
      'gtin': d.gtin,
      'serial': d.serial,
      'sgtinFormat': d.sgtinFormat.name,
      'companyPrefixLength': d.companyPrefixLength,
      'digitalLinkDomain': d.digitalLinkDomain,
      'nsn': d.nsn,
      'rawText': d.rawText,
    },
    'print': {'dpi': i.dpi, 'xDimensionMm': i.xdim, 'barHeightMm': i.barh},
    'logo': {'sideMm': logoSideMm, 'ecBudget': logoAutoEcShare},
    'serialization': {
      'prefix': ss.prefix,
      'start': ss.start,
      'count': ss.count,
      'padDigits': ss.pad,
      'pageFormat': sheet.page.name,
      'orientation': sheet.orientation.name,
      'columns': sheet.columnsOverride,
    },
    'label': label.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(proj);
}

T? _enumByName<T extends Enum>(List<T> values, String? name) =>
    values.where((v) => v.name == name).firstOrNull;

/// Parses a .qseq project. Returns the parsed pieces; unknown/missing fields
/// keep the supplied defaults (old project files still load).
({
  WebMode mode,
  DataSourceInput data,
  Symbology twoD,
  Symbology oneD,
  QrEcLevel ec,
  double dpi,
  double xdim,
  double barh,
  bool logoOn,
  LabelArrangement arrangement,
  double gapMm,
  double padMm,
  SerialSpec serial,
  SheetSpec sheet,
  Map<String, dynamic>? labelJson,
})? parseProject(String text) {
  Map<String, dynamic> j;
  try {
    j = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final w = (j['workspace'] as Map?)?.cast<String, dynamic>() ?? {};
  final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? {};
  final pr = (j['print'] as Map?)?.cast<String, dynamic>() ?? {};
  final lg = (j['logo'] as Map?)?.cast<String, dynamic>() ?? {};
  final sr = (j['serialization'] as Map?)?.cast<String, dynamic>() ?? {};
  final ecName = w['errorCorrection'] as String?;
  final ec = _ecTo.entries
          .where((e) => e.value == ecName)
          .map((e) => e.key)
          .firstOrNull ??
      QrEcLevel.medium;
  return (
    mode: modeFrom(w['mode'] as String?),
    data: DataSourceInput(
      kind: _enumByName(DataSourceKind.values, d['kind'] as String?) ??
          DataSourceKind.sgtin,
      gtin: d['gtin'] as String? ?? '80614141123458',
      serial: d['serial'] as String? ?? '6789',
      sgtinFormat:
          _enumByName(SgtinFormat.values, d['sgtinFormat'] as String?) ??
              SgtinFormat.digitalLink,
      companyPrefixLength:
          (d['companyPrefixLength'] as num?)?.toInt().clamp(6, 12) ?? 7,
      digitalLinkDomain:
          d['digitalLinkDomain'] as String? ?? 'https://id.gs1.org',
      nsn: d['nsn'] as String? ?? '9515-00-003-6945',
      rawText: d['rawText'] as String? ?? 'https://example.com',
    ),
    twoD: _enumByName(
            [Symbology.qrCode, Symbology.dataMatrix], w['twoDSymbology'] as String?) ??
        Symbology.qrCode,
    oneD: _enumByName(
            Symbology.values.where((s) => !s.is2D).toList(),
            w['oneDSymbology'] as String?) ??
        Symbology.gs1_128,
    ec: ec,
    dpi: ((pr['dpi'] as num?)?.toDouble() ?? 300).clamp(36, 1200),
    xdim: ((pr['xDimensionMm'] as num?)?.toDouble() ?? 0.5).clamp(0.05, 5),
    barh: ((pr['barHeightMm'] as num?)?.toDouble() ?? 15).clamp(1, 300),
    logoOn: ((lg['sideMm'] as num?)?.toDouble() ?? 0) > 0,
    arrangement: _enumByName(
            LabelArrangement.values, w['arrangement'] as String?) ??
        LabelArrangement.sideBySide,
    gapMm: ((w['labelGapMm'] as num?)?.toDouble() ?? 4).clamp(0, 100),
    padMm: ((w['labelPaddingMm'] as num?)?.toDouble() ?? 2).clamp(0, 100),
    serial: SerialSpec(
      prefix: sr['prefix'] as String? ?? '',
      start: (sr['start'] as num?)?.toInt().clamp(0, 1000000000) ?? 1,
      count: (sr['count'] as num?)?.toInt().clamp(1, 2000) ?? 24,
      pad: (sr['padDigits'] as num?)?.toInt().clamp(0, 20) ?? 5,
    ),
    sheet: SheetSpec(
      page: _enumByName(PageFormat.values, sr['pageFormat'] as String?) ??
          PageFormat.letter,
      orientation: _enumByName(
              PageOrientation.values, sr['orientation'] as String?) ??
          PageOrientation.portrait,
      columnsOverride: (sr['columns'] as num?)?.toInt().clamp(0, 50) ?? 0,
    ),
    labelJson: (j['label'] as Map?)?.cast<String, dynamic>(),
  );
}
