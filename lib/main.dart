// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import 'mobile/mobile_app.dart';
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
    // iOS / Android get a touch-first Material UI over the shared pure-Dart
    // core; macOS / Windows keep the macos_ui desktop shell.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      return const MobileApp();
    }
    final mode = ref.watch(themeModeProvider);
    return MacosApp(
      title: 'QSeq',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: mode,
      debugShowCheckedModeBanner: false,
      // macos_ui paints the window chrome (title bar, toolbar, sidebars) from
      // the PLATFORM brightness, while widgets follow themeMode — when the
      // in-app toggle disagrees with the OS theme they split (white-on-white
      // text/icons). Force the platform brightness to match the toggle so
      // chrome and content always agree.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final brightness = mode == ThemeMode.dark
            ? Brightness.dark
            : mode == ThemeMode.light
                ? Brightness.light
                : mq.platformBrightness;
        return MediaQuery(
          data: mq.copyWith(platformBrightness: brightness),
          child: child ?? const SizedBox(),
        );
      },
      home: const LicenseGate(child: HomePage()),
    );
  }
}
