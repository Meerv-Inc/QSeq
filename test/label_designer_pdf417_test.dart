// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Reproduces a reported bug: in the label designer, a 1D+2D combo label with
// PDF417 as the 2D symbology didn't place PDF417 above the 1D barcode the way
// the static combined label and serialized sheets already forced — the
// designer's auto-arrange had no concept of PDF417's forced stacking, and a
// design made while 2D was QR/Data Matrix stayed side by side after switching
// to PDF417.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qseq/models/label_spec.dart';
import 'package:qseq/models/symbology.dart';
import 'package:qseq/render/label_export.dart';
import 'package:qseq/state/app_controller.dart';
import 'package:qseq/ui/label_designer.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MacosApp(debugShowCheckedModeBanner: false, home: child),
    );

void main() {
  testWidgets(
      'a fresh combo label designer with PDF417 as the 2D symbology stacks '
      '2D above 1D', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.combo, twoDSymbology: Symbology.pdf417),
        );

    await tester.pumpWidget(_host(c, const LabelDesigner()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final spec = c.read(labelSpecProvider);
    expect(labelLayoutIsSideBySide(spec), isFalse);
    final twoD = spec.rects['twoD'], oneD = spec.rects['oneD'];
    expect(twoD, isNotNull);
    expect(oneD, isNotNull);
    expect(twoD!.y + twoD.h, lessThanOrEqualTo(oneD!.y + 0.01));
  });

  testWidgets(
      'switching an already-designed side-by-side combo label to PDF417 '
      're-stacks it', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.combo, twoDSymbology: Symbology.qrCode),
        );

    await tester.pumpWidget(_host(c, const LabelDesigner()));
    await tester.pumpAndSettle();
    // QR + 1D auto-arranges side by side (the pre-existing default).
    expect(labelLayoutIsSideBySide(c.read(labelSpecProvider)), isTrue);

    c.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(twoDSymbology: Symbology.pdf417),
        );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final spec = c.read(labelSpecProvider);
    expect(labelLayoutIsSideBySide(spec), isFalse,
        reason: 'stale side-by-side layout survived the switch to PDF417');
    final twoD = spec.rects['twoD']!, oneD = spec.rects['oneD']!;
    expect(twoD.y + twoD.h, lessThanOrEqualTo(oneD.y + 0.01));
  });

  test('LabelExport.arrange re-stacks a stale side-by-side design for '
      'PDF417 export', () {
    final s = const AppSettings()
        .copyWith(mode: AppMode.combo, twoDSymbology: Symbology.qrCode);
    final spec = LabelSpec();
    final arrangedQr = LabelExport.arrange(s, spec);
    expect(labelLayoutIsSideBySide(arrangedQr), isTrue);

    final pdfS = s.copyWith(twoDSymbology: Symbology.pdf417);
    final arrangedPdf = LabelExport.arrange(pdfS, arrangedQr);
    expect(labelLayoutIsSideBySide(arrangedPdf), isFalse);
  });
}
