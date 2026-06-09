// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qr_studio/models/batch.dart';
import 'package:qr_studio/state/app_controller.dart';
import 'package:qr_studio/ui/preview_pane.dart';
import 'package:qr_studio/ui/serialization_log.dart';

// A serialized A4 sheet whose item count spans several printed pages, so the
// page tabs and the log jump-links both have something to render.
ProviderContainer _multiPageContainer() {
  final container = ProviderContainer();
  container.read(appControllerProvider.notifier).update(
        (s) => s.copyWith(
          mode: AppMode.twoDSerial,
          pageFormat: PageFormat.a4,
          batchCount: 150,
        ),
      );
  return container;
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MacosApp(
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );

void main() {
  testWidgets('serialized preview renders the tabbed page browser',
      (tester) async {
    final container = _multiPageContainer();
    addTearDown(container.dispose);

    final batch = container.read(batchProvider)!;
    expect(batch.pageCount, greaterThan(1),
        reason: 'A4 with 150 QR codes should span multiple pages');

    await tester.pumpWidget(_host(container, const PreviewPane()));
    await tester.pump();

    // No build/layout exception — a blank/throwing frame would fail here.
    expect(tester.takeException(), isNull);

    // The bottom info label and a tab for the second page are both present.
    expect(find.textContaining('A4 · ${batch.pageCount} pages'), findsOneWidget);
    expect(find.widgetWithText(GestureDetector, '2'), findsWidgets);
  });

  testWidgets('serialization log shows a jump-to-page link per row',
      (tester) async {
    final container = _multiPageContainer();
    addTearDown(container.dispose);

    final batch = container.read(batchProvider)!;

    await tester.pumpWidget(_host(container, const SerializationLog()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The first row sits on page 1; later rows link to higher pages.
    expect(
      find.textContaining('Page: 1 of ${batch.pageCount}'),
      findsWidgets,
    );
  });

  testWidgets('a continuous flexo web reads as one endless page (no tabs)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(
            mode: AppMode.twoDSerial,
            pageFormat: PageFormat.flexo12in,
            batchCount: 40,
          ),
        );

    await tester.pumpWidget(_host(container, const PreviewPane()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('on one endless page'), findsOneWidget);
    // No numbered page tabs for a continuous web.
    expect(find.widgetWithText(GestureDetector, '2'), findsNothing);
  });
}
