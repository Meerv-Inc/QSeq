// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Reproduces a reported bug: on the on-screen "Sheet of copies" preview,
// switching pages (via the page browser) kept whatever vertical scroll
// offset the previous page was left at — so a newly-opened page could start
// already scrolled past its own top margin, looking like the page had no
// margin at the top at all.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qseq/state/app_controller.dart';
import 'package:qseq/ui/preview_pane.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MacosApp(debugShowCheckedModeBanner: false, home: child),
    );

void main() {
  testWidgets(
      'switching pages resets the vertical scroll so the new page opens at '
      'its own top margin', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appControllerProvider.notifier).update(
          (s) => s.copyWith(mode: AppMode.twoDSheet, batchCopies: 200),
        );
    final batch = c.read(batchProvider)!;
    expect(batch.pageCount, greaterThan(1),
        reason: 'test needs a multi-page sheet to exercise page switching');

    await tester.pumpWidget(_host(c, const PreviewPane()));
    await tester.pump();

    final vertical = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.widget.axisDirection == AxisDirection.down);
    expect(vertical.position.pixels, 0);

    // Scroll down within page 1, away from the top margin.
    vertical.position.jumpTo(120);
    await tester.pump();
    expect(vertical.position.pixels, greaterThan(0));

    // Switch to page 2 — the scroll should snap back to the top.
    c.read(batchPageProvider.notifier).set(1);
    await tester.pump();
    await tester.pump();

    final verticalAfter = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.widget.axisDirection == AxisDirection.down);
    expect(verticalAfter.position.pixels, 0,
        reason: 'page 2 opened scrolled past its own top margin');
  });
}
