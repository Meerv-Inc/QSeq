// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import 'state/app_controller.dart';
import 'ui/home_page.dart';
import 'ui/license_pane.dart';

void main() {
  runApp(const ProviderScope(child: QrStudioApp()));
}

class QrStudioApp extends ConsumerWidget {
  const QrStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MacosApp(
      title: 'QSeq',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      home: const LicenseGate(child: HomePage()),
    );
  }
}
