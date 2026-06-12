// Engine smoke test: exercises every workspace and option combination the UI
// can reach, on the Dart VM (same code that runs in the browser).
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
      final ss = const SerialSpec(count: 30);
      const sheet = SheetSpec(page: PageFormat.a4);
      final tag = '${mode.name}/${twoD.name}';
      if (mode.isLabel) {
        final spec = LabelSpec();
        if (mode == WebMode.label) {
          check('label $tag', buildLabel(i, spec));
          check('tmpl  $tag', buildLabelTemplate(i, spec));
          check('labelX $tag', buildLabel(i, spec, forExport: true));
        } else {
          final L = layoutLabelSheet(spec, ss, sheet);
          check('lsheet $tag p0', buildLabelSheetPage(i, spec, ss, L, 0));
          check('lsheet $tag pN',
              buildLabelSheetPage(i, spec, ss, L, L.pageCount - 1));
        }
      } else if (mode.isSerialized) {
        final L = layoutSheet(i, ss, sheet);
        check('sheet $tag p0', buildSheetPage(i, ss, L, 0));
        check('sheet $tag pN', buildSheetPage(i, ss, L, L.pageCount - 1));
        final log = serialLog(i, ss);
        if (log.length != 30) throw StateError('log ${log.length}');
      } else if (mode.isCombo) {
        check('combo $tag', buildCombined(i));
      } else {
        check('single $tag', buildSingle(i));
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
  // project round-trip
  {
    const i = GenInput(mode: WebMode.combo, data: data);
    final json = projectJson(
        i: i,
        ss: const SerialSpec(),
        sheet: const SheetSpec(),
        label: LabelSpec(),
        logoSideMm: 1);
    final p = parseProject(json);
    if (p == null || p.mode != WebMode.combo) {
      throw StateError('project round-trip failed');
    }
    print('ok  project round-trip');
  }
  print('ALL SMOKE TESTS PASSED');
}
