// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// Reproduces a reported bug: in a serialized sheet, editing the data source
// text or the GS1 Digital Link domain didn't visibly update the rendered
// labels. test/batch_test.dart already proves the underlying batchProvider
// recomputes correctly on every edit — this test instead pumps the REAL
// widget tree (PreviewPane), which is what could reveal a genuine Flutter
// rebuild bug a provider-only test can't catch.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:qseq/models/data_source.dart';
import 'package:qseq/state/app_controller.dart';
import 'package:qseq/ui/preview_pane.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MacosApp(debugShowCheckedModeBanner: false, home: child),
);

void main() {
  testWidgets('serialized sheet re-renders every label when the free-text data '
      'source changes', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(appControllerProvider.notifier)
        .update(
          (s) => s.copyWith(
            mode: AppMode.twoDSerial,
            batchCount: 3,
            data: s.data.copyWith(
              kind: DataSourceKind.rawText,
              rawText: 'hello-',
            ),
          ),
        );

    await tester.pumpWidget(_host(c, const PreviewPane()));
    await tester.pump();
    expect(find.textContaining('hello-'), findsWidgets);
    expect(find.textContaining('world-'), findsNothing);

    c
        .read(appControllerProvider.notifier)
        .update((s) => s.copyWith(data: s.data.copyWith(rawText: 'world-')));
    await tester.pump();

    expect(find.textContaining('world-'), findsWidgets);
    expect(
      find.textContaining('hello-'),
      findsNothing,
      reason: 'a stale "hello-" label survived the rawText edit',
    );
  });

  testWidgets('serialized sheet re-renders every label when the Digital Link '
      'domain changes', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(appControllerProvider.notifier)
        .update(
          (s) => s.copyWith(
            mode: AppMode.twoDSerial,
            batchCount: 3,
            data: s.data.copyWith(
              kind: DataSourceKind.sgtin,
              digitalLinkDomain: 'https://id.gs1.org',
            ),
          ),
        );

    await tester.pumpWidget(_host(c, const PreviewPane()));
    await tester.pump();
    expect(find.textContaining('id.gs1.org'), findsWidgets);
    expect(find.textContaining('example.com'), findsNothing);

    c
        .read(appControllerProvider.notifier)
        .update(
          (s) => s.copyWith(
            data: s.data.copyWith(digitalLinkDomain: 'https://example.com'),
          ),
        );
    await tester.pump();

    expect(find.textContaining('example.com'), findsWidgets);
    expect(
      find.textContaining('id.gs1.org'),
      findsNothing,
      reason: 'a stale id.gs1.org label survived the domain edit',
    );
  });

  testWidgets(
    'Label designer + serialized sheet (the WYSIWYG raster view) renders '
    'and re-renders on a rawText edit without crashing',
    (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c
          .read(appControllerProvider.notifier)
          .update(
            (s) => s.copyWith(
              mode: AppMode.twoDSerial,
              labelOn: true,
              batchCount: 2,
              data: s.data.copyWith(
                kind: DataSourceKind.rawText,
                rawText: 'hello-',
              ),
            ),
          );

      await tester.pumpWidget(_host(c, const PreviewPane()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsWidgets);

      c
          .read(appControllerProvider.notifier)
          .update((s) => s.copyWith(data: s.data.copyWith(rawText: 'world-')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsWidgets);
    },
  );
}
