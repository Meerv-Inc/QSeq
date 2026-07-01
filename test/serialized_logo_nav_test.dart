// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qseq/models/symbology.dart';
import 'package:qseq/state/app_controller.dart';
import 'package:qseq/ui/preview_pane.dart';
import 'package:qseq/ui/serialization_log.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MacosApp(debugShowCheckedModeBanner: false, home: child),
    );

ProviderContainer _serial({
  required Symbology twoD,
  double logoSideMm = 0,
}) {
  final c = ProviderContainer();
  c.read(appControllerProvider.notifier).update(
        (s) => s.copyWith(
          mode: AppMode.twoDSerial,
          twoDSymbology: twoD,
          batchCount: 24,
          logoSideMm: logoSideMm,
        ),
      );
  return c;
}

void main() {
  for (final sym in [Symbology.qrCode, Symbology.dataMatrix]) {
    testWidgets('serialized ${sym.name} sheet with a logo renders without error',
        (tester) async {
      final c = _serial(twoD: sym, logoSideMm: 4);
      addTearDown(c.dispose);

      // The batch builds and the chosen symbology is what drives the cells.
      final batch = c.read(batchProvider)!;
      expect(batch.twoDSample!.symbology, sym);
      expect(batch.twoDSample!.logoSideMm, greaterThan(0));

      await tester.pumpWidget(_host(c, const PreviewPane()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('serialized pdf417 sheet renders without error', (tester) async {
    final c = _serial(twoD: Symbology.pdf417);
    addTearDown(c.dispose);

    final batch = c.read(batchProvider)!;
    expect(batch.twoDSample!.symbology, Symbology.pdf417);

    await tester.pumpWidget(_host(c, const PreviewPane()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a pdf417 sheet ignores a stale logoSideMm left over from a prior '
      'QR selection and still renders cleanly', (tester) async {
    final c = _serial(twoD: Symbology.pdf417, logoSideMm: 4);
    addTearDown(c.dispose);

    final batch = c.read(batchProvider)!;
    // logoSideMm still flows into the config (so a warning can surface), but
    // PDF417 never applies a knockout — the sizer reports no logo budget.
    expect(batch.twoDSample!.logoSideMm, greaterThan(0));
    expect(batch.twoDSize!.logoBudget, isNull);

    await tester.pumpWidget(_host(c, const PreviewPane()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('serialization log exposes four arrow nav buttons',
      (tester) async {
    final c = _serial(twoD: Symbology.qrCode);
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c, const SerializationLog()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Four arrow controls: page-up / up-one / down-one / page-down.
    expect(find.byType(MacosIconButton), findsNWidgets(4));
    final icons = tester
        .widgetList<MacosIcon>(find.byType(MacosIcon))
        .map((w) => w.icon)
        .toSet();
    expect(icons, containsAll(<IconData>{
      CupertinoIcons.arrow_up_to_line,
      CupertinoIcons.chevron_up,
      CupertinoIcons.chevron_down,
      CupertinoIcons.arrow_down_to_line,
    }));

    // No interactive drag scrollbar remains.
    expect(find.byType(RawScrollbar), findsNothing);
  });
}
