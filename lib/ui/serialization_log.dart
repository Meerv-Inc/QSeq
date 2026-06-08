// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_controller.dart';

/// The far-right panel enumerating every serial in the current workspace.
class SerializationLog extends ConsumerWidget {
  const SerializationLog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serials = ref.watch(serialLogProvider);
    final theme = MacosTheme.of(context);
    final shown = serials.take(300).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('Serialization Log',
              style: theme.typography.headline
                  .copyWith(fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            serials.isEmpty
                ? 'No codes in this workspace.'
                : '${serials.length} code${serials.length == 1 ? '' : 's'} · full encoded link'
                    '${serials.length > shown.length ? ' · first ${shown.length}' : ''}',
            style: theme.typography.caption1
                .copyWith(color: MacosColors.systemGrayColor),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Text(
                '${(i + 1).toString().padLeft(shown.length.toString().length)}.  ${shown[i]}',
                style: theme.typography.caption1
                    .copyWith(fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            onPressed: serials.isEmpty
                ? null
                : () => showSerialLogDialog(context, serials),
            child: const Text('Open full log…'),
          ),
        ),
      ],
    );
  }
}

/// Shows the complete enumerated serial list in a sheet, with copy / save.
Future<void> showSerialLogDialog(
    BuildContext context, List<String> serials) async {
  final text = [
    for (var i = 0; i < serials.length; i++) '${i + 1}\t${serials[i]}',
  ].join('\n');

  await showMacosSheet(
    context: context,
    builder: (context) => MacosSheet(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Serialization Log — ${serials.length} codes (full GS1 Digital Link)',
                style: MacosTheme.of(context)
                    .typography
                    .title2
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: MacosTheme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: serials.length,
                  itemBuilder: (context, i) => Text(
                    '${(i + 1).toString().padLeft(serials.length.toString().length)}.  ${serials[i]}',
                    style: MacosTheme.of(context)
                        .typography
                        .body
                        .copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: text)),
                  child: const Text('Copy all'),
                ),
                const SizedBox(width: 10),
                PushButton(
                  controlSize: ControlSize.large,
                  secondary: true,
                  onPressed: () => _saveTxt(text),
                  child: const Text('Save .txt'),
                ),
                const SizedBox(width: 10),
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _saveTxt(String text) async {
  final location = await getSaveLocation(
    suggestedName: 'serials.txt',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Text', extensions: ['txt'])
    ],
  );
  if (location == null) return;
  await File(location.path).writeAsString(text);
}
