// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// The license sheet (toolbar "License" button) and the consent gate: on first
// launch — and again every 30 days — the user must read and agree to the
// PolyForm Noncommercial 1.0.0 terms granted by Meerv Inc. before using QSeq.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

const String kLicenseUrl =
    'https://polyformproject.org/licenses/noncommercial/1.0.0';

const List<(String, String)> _terms = [
  (
    'What you are granted',
    'Meerv Inc. grants you a non-exclusive, worldwide, royalty-free license '
        'to use, copy, modify and distribute QSeq — for noncommercial '
        'purposes only.'
  ),
  (
    'What counts as noncommercial',
    'Personal use, and use by charitable organizations, educational '
        'institutions, public research organizations, public safety or '
        'health organizations, environmental protection organizations and '
        'government institutions, regardless of the source of funding or '
        'obligations resulting from the funding.'
  ),
  (
    'Required notice',
    'Copies you distribute (modified or not) must keep the required notice: '
        '“Required Notice: Copyright Meerv Inc. (https://qseq.app)”.'
  ),
  (
    'Commercial use',
    'Any use for or by a for-profit purpose is NOT covered by this grant and '
        'requires a separate commercial license from Meerv Inc. — contact '
        'support@meerv.com.'
  ),
  (
    'No warranty / termination',
    'The software is provided as-is, without warranty. The license ends '
        'automatically if you violate its terms (with a 14-day cure window '
        'for a first violation of the noncommercial limit).'
  ),
];

Widget _termsBody(BuildContext context) {
  final t = MacosTheme.of(context).typography;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
          'QSeq is source-available under the PolyForm Noncommercial '
          'License 1.0.0, © 2026 Meerv Inc.',
          style: t.body.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      for (final (h, b) in _terms)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '$h.  ',
                style: t.body.copyWith(fontWeight: FontWeight.bold)),
            TextSpan(text: b, style: t.body),
          ])),
        ),
      const SizedBox(height: 4),
      Text('Full text: $kLicenseUrl', style: t.caption1),
    ],
  );
}

/// The informational License sheet (toolbar button).
Future<void> showLicenseSheet(BuildContext context) async {
  await showMacosSheet(
    context: context,
    builder: (context) => MacosSheet(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('License',
                style: MacosTheme.of(context)
                    .typography
                    .largeTitle
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: _termsBody(context))),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PushButton(
                controlSize: ControlSize.large,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---- consent gate -----------------------------------------------------------

File _consentFile() {
  final env = Platform.environment;
  final base = Platform.isWindows
      ? (env['APPDATA'] ?? env['USERPROFILE'] ?? '.')
      : '${env['HOME'] ?? '.'}/Library/Application Support';
  return File('$base${Platform.pathSeparator}QSeq'
      '${Platform.pathSeparator}license-consent.json');
}

bool _consentCurrent() {
  try {
    final f = _consentFile();
    if (!f.existsSync()) return false;
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final at = DateTime.tryParse(j['acceptedAt'] as String? ?? '');
    if (at == null) return false;
    // Re-confirm every 30 days.
    return DateTime.now().difference(at).inDays < 30;
  } catch (_) {
    return false;
  }
}

void _recordConsent() {
  try {
    final f = _consentFile();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
        jsonEncode({'acceptedAt': DateTime.now().toIso8601String()}));
  } catch (_) {}
}

/// Wraps the app; on first launch and every 30 days requires the user to read
/// and agree to the license before continuing (declining quits the app).
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  @override
  void initState() {
    super.initState();
    if (!_consentCurrent()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
  }

  Future<void> _ask() async {
    if (!mounted) return;
    final agreed = await showMacosAlertDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.doc_checkmark, size: 56),
        title: const Text('License agreement'),
        message: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _termsBody(context),
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('I have read the terms and agree'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline and quit'),
        ),
      ),
    );
    if (agreed == true) {
      _recordConsent();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
