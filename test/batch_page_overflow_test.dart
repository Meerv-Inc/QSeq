// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Reproduces a reported bug: on the on-screen "Sheet of copies" preview,
// labels overflowed past the bottom edge of the drawn page instead of
// paginating to the next one. Root cause: Batch.rows/perPage/pageHeightMm
// are computed from an mm-true HRI caption model (5 pt font, documented
// per-band gaps) that must "track batch_pdf.dart" — but the on-screen cell
// widget rendered its own independent, UN-scaled fixed-pixel gaps and a
// fixed UI theme caption font, so the actual on-screen cell height silently
// drifted from what governed pagination, and the excess got clipped mid-row
// instead of moving to the next page.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qseq/models/symbology.dart';
import 'package:qseq/state/app_controller.dart';
import 'package:qseq/ui/preview_pane.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MacosApp(debugShowCheckedModeBanner: false, home: child),
    );

void main() {
  for (final sym in [Symbology.qrCode, Symbology.pdf417]) {
    testWidgets(
        'sheet of copies (${sym.name}) never overflows the drawn page — the '
        'grid content stays within the page container on screen',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(appControllerProvider.notifier).update(
            (s) => s.copyWith(
              mode: AppMode.twoDSheet,
              twoDSymbology: sym,
              batchCopies: 60,
            ),
          );

      await tester.pumpWidget(_host(c, const PreviewPane()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final pageRect = tester.getRect(find.byKey(const Key('batchPageContainer')));
      final gridRect = tester.getRect(find.byKey(const Key('batchPageGrid')));

      expect(
        gridRect.bottom,
        lessThanOrEqualTo(pageRect.bottom + 0.5),
        reason: 'the ${sym.name} grid content overflowed past the bottom of '
            'the drawn page instead of moving to the next page',
      );
    });
  }
}
