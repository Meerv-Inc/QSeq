// Engine smoke test: exercises every workspace and option combination the UI
// can reach, on the Dart VM (same code that runs in the browser).
import 'dart:convert';

import 'package:qseq_core/qseq_core.dart';
import 'package:site/qseq/generate.dart';
import 'package:site/qseq/label.dart';
import 'package:site/qseq/project.dart';

void check(String name, Artwork a) {
  if (!a.ok) throw StateError('$name: ${a.error}');
  if (!a.svg.startsWith('<svg')) throw StateError('$name: not svg');
  print('ok  $name  ${a.wMm.toStringAsFixed(1)}×${a.hMm.toStringAsFixed(1)}mm '
      'svg=${a.svg.length}b');
}

void main() {
  const data = DataSourceInput();
  for (final mode in WebMode.values) {
    for (final twoD in [Symbology.qrCode, Symbology.dataMatrix]) {
      final i = GenInput(
          mode: mode, data: data, twoD: twoD, logoOn: true, logoDataUrl: null);
      // Serialized runs count distinct serials; copy sheets repeat the payload.
      final ss = mode.isCopies
          ? const SerialSpec(serialize: false, count: 30)
          : const SerialSpec(count: 30);
      const sheet = SheetSpec(page: PageFormat.a4);
      final tag = '${mode.name}/${twoD.name}';
      if (mode.isPaged) {
        final L = layoutSheet(i, ss, sheet);
        check('sheet $tag p0', buildSheetPage(i, ss, L, 0));
        check('sheet $tag pN', buildSheetPage(i, ss, L, L.pageCount - 1));
        final log = serialLog(i, ss);
        if (log.length != 30) throw StateError('log ${log.length}');
        if (mode.isCopies && log.toSet().length != 1) {
          throw StateError('copies log not identical');
        }
        // The label overlay tiles the designed label over the same run.
        final spec = LabelSpec(twoDOn: i.mode.use2D, oneDOn: i.mode.use1D);
        final LL = layoutLabelSheet(spec, ss, sheet);
        check('lsheet $tag p0', buildLabelSheetPage(i, spec, ss, LL, 0));
        check('lsheet $tag pN',
            buildLabelSheetPage(i, spec, ss, LL, LL.pageCount - 1));
      } else {
        if (mode.isCombo) {
          check('combo $tag', buildCombined(i));
        } else {
          check('single $tag', buildSingle(i));
        }
        // The label overlay on every single workspace.
        final spec = LabelSpec(twoDOn: mode.use2D, oneDOn: mode.use1D);
        check('label $tag', buildLabel(i, spec));
        check('tmpl  $tag', buildLabelTemplate(i, spec));
        check('labelX $tag', buildLabel(i, spec, forExport: true));
      }
    }
  }
  // 1D symbologies + NSN + text + EPC
  for (final s in Symbology.values.where((s) => !s.is2D)) {
    // Match each symbology's charset: Code 39 is uppercase-only, EAN/UPC are
    // fixed-length numeric (the check digit is computed from 12/11 digits).
    final d = switch (s) {
      Symbology.ean13 => const DataSourceInput(
          kind: DataSourceKind.rawText, rawText: '590123412345'),
      Symbology.upcA => const DataSourceInput(
          kind: DataSourceKind.rawText, rawText: '59012341234'),
      Symbology.code39 => const DataSourceInput(
          kind: DataSourceKind.rawText, rawText: 'QSEQ-12345'),
      _ => data,
    };
    check('1d ${s.name}',
        buildSingle(GenInput(mode: WebMode.oneD, data: d, oneDSym: s)));
  }
  check(
      'nsn',
      buildSingle(const GenInput(
          mode: WebMode.twoD,
          data: DataSourceInput(kind: DataSourceKind.nsn))));
  check(
      'epc',
      buildSingle(const GenInput(
          mode: WebMode.twoD,
          data: DataSourceInput(sgtinFormat: SgtinFormat.epcTagUri))));
  // continuous web + landscape + columns override
  {
    const i = GenInput(mode: WebMode.comboSerial, data: data);
    const ss = SerialSpec(count: 40);
    final L = layoutSheet(
        i, ss, const SheetSpec(page: PageFormat.flexo12cm));
    check('flexo', buildSheetPage(i, ss, L, 0, maxCells: 10));
    final L2 = layoutSheet(
        i,
        ss,
        const SheetSpec(
            page: PageFormat.a4,
            orientation: PageOrientation.landscape,
            columnsOverride: 2));
    check('landscape2col', buildSheetPage(i, ss, L2, 0, maxCells: 6));
  }
  // combo shared-vs-per-code HRI, single + sheet
  for (final shared in [true, false]) {
    final i = GenInput(
        mode: WebMode.combo, data: data, comboSharedHri: shared);
    check('combo hri=$shared', buildCombined(i));
    final is2 = GenInput(
        mode: WebMode.comboSerial, data: data, comboSharedHri: shared);
    const ss = SerialSpec(count: 12);
    final L = layoutSheet(is2, ss, const SheetSpec());
    check('comboSheet hri=$shared', buildSheetPage(is2, ss, L, 0));
  }
  // label sheets with 1D-only / 2D-only / both, QR and DataMatrix
  for (final two in [Symbology.qrCode, Symbology.dataMatrix]) {
    for (final (on2, on1) in [(true, false), (false, true), (true, true)]) {
      final i = GenInput(mode: WebMode.comboSerial, data: data, twoD: two);
      final spec = LabelSpec(twoDOn: on2, oneDOn: on1);
      const ss = SerialSpec(count: 8);
      final L = layoutLabelSheet(spec, ss, const SheetSpec());
      check('lsheet ${two.name} 2D=$on2 1D=$on1',
          buildLabelSheetPage(i, spec, ss, L, 0));
    }
  }
  // print rulers wrap a single artwork and a sheet page
  {
    const i = GenInput(mode: WebMode.twoD, data: data);
    final r = withPrintRulers(buildSingle(i));
    check('rulers single', r);
    if (!r.svg.contains('vern 0.1mm')) throw StateError('no vernier');
    const is2 = GenInput(mode: WebMode.twoDSerial, data: data);
    const ss = SerialSpec(count: 8);
    final L = layoutSheet(is2, ss, const SheetSpec());
    check('rulers sheet', withPrintRulers(buildSheetPage(is2, ss, L, 0)));
  }
  // logo dead-space: EC shares and the manual override
  {
    for (final share in [0.15, 0.3, 0.5]) {
      final i = GenInput(
          mode: WebMode.twoD, data: data, logoOn: true, logoEcShare: share);
      check('logo ec=${(share * 100).round()}%', buildSingle(i));
    }
    const manual = GenInput(
        mode: WebMode.twoD, data: data, logoOn: true, logoManualMm: 8);
    if (activeLogoMm(manual, 'x') != 8) throw StateError('manual logo mm');
    check('logo manual 8mm', buildSingle(manual));
  }
  // explicit HRI font size renders (and round-trips through label JSON)
  {
    const i = GenInput(mode: WebMode.combo, data: data);
    final spec = LabelSpec(hriFontMm: 5);
    check('label hriFont=5mm', buildLabel(i, spec));
    final spec2 = LabelSpec()..applyJson(spec.toJson());
    if (spec2.hriFontMm != 5) throw StateError('hriFontMm round-trip');
  }
  // project round-trip (overlay + copies persisted)
  {
    const i = GenInput(mode: WebMode.twoDSheet, data: data);
    final json = projectJson(
        i: i,
        ss: const SerialSpec(),
        sheet: const SheetSpec(),
        label: LabelSpec(),
        logoSideMm: 1,
        labelOn: true,
        copies: 33);
    final p = parseProject(json);
    if (p == null ||
        p.mode != WebMode.twoDSheet ||
        !p.labelOn ||
        p.copies != 33) {
      throw StateError('project round-trip failed');
    }
    print('ok  project round-trip');
  }
  // legacy projects: label workspaces load as combo + overlay
  {
    final legacy = jsonEncode({
      'format': 'QSeq Project',
      'version': 1,
      'workspace': {'mode': 'labelSerial'},
    });
    final p = parseProject(legacy);
    if (p == null || p.mode != WebMode.comboSerial || !p.labelOn) {
      throw StateError('legacy label mapping failed');
    }
    print('ok  legacy label workspace mapping');
  }
  print('ALL SMOKE TESTS PASSED');
}
