import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import 'ui/home_page.dart';

void main() {
  runApp(const ProviderScope(child: QrStudioApp()));
}

class QrStudioApp extends StatelessWidget {
  const QrStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'QSeq',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
