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
import 'digital_link_validator_pane.dart';

/// The far-right panel enumerating every serial in the current workspace.
class SerializationLog extends ConsumerStatefulWidget {
  const SerializationLog({super.key});

  @override
  ConsumerState<SerializationLog> createState() => _SerializationLogState();
}

class _SerializationLogState extends ConsumerState<SerializationLog> {
  final _scroll = ScrollController();

  /// Fixed height of one log row, so a single-step scroll advances exactly one
  /// code and the list lays out cheaply.
  static const double _rowExtent = 20;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll the log by [delta] logical pixels, clamped to the scrollable range.
  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = (pos.pixels + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  /// One viewport-worth of scroll (a little overlap keeps a row of context).
  double get _pageDelta {
    if (!_scroll.hasClients) return _rowExtent * 10;
    final vp = _scroll.position.viewportDimension;
    return (vp - _rowExtent).clamp(_rowExtent, double.infinity).toDouble();
  }

  /// Arrow controls pinned under the list — line up/down and page up/down —
  /// replacing the unreliable drag scrollbar.
  Widget _navBar(MacosThemeData theme, bool disabled) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => MacosTooltip(
          message: tip,
          child: MacosIconButton(
            icon: MacosIcon(icon, size: 16),
            boxConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 26),
            onPressed: disabled ? null : onTap,
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          btn(CupertinoIcons.arrow_up_to_line, 'Page up',
              () => _scrollBy(-_pageDelta)),
          btn(CupertinoIcons.chevron_up, 'Up one', () => _scrollBy(-_rowExtent)),
          btn(CupertinoIcons.chevron_down, 'Down one',
              () => _scrollBy(_rowExtent)),
          btn(CupertinoIcons.arrow_down_to_line, 'Page down',
              () => _scrollBy(_pageDelta)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serials = ref.watch(serialLogProvider);
    final theme = MacosTheme.of(context);
    // Show every code (the batch is already capped at 2000); the ListView is
    // lazy, so rendering the full run stays cheap.
    final shown = serials;
    // When the serialized sheet spans multiple printed pages, each row carries a
    // "Page: # of Y" link that jumps the on-screen preview to the page holding
    // that code. Uses the live pagination, so it tracks the page tabs and PDF.
    final s = ref.watch(appControllerProvider);
    final batch = s.mode.isSerialized ? ref.watch(batchProvider) : null;
    final perPage = batch?.perPage ?? 0;
    final pageCount = batch?.pageCount ?? 0;
    final multiPage = batch != null &&
        !batch.page.isContinuous &&
        pageCount > 1 &&
        perPage > 0;

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
          // Drag-thumb scrollbars proved unreliable across platforms (the
          // macos_ui Sidebar overlays its own non-interactive bar), so the list
          // is driven by the arrow buttons below instead. Swallow the list's
          // scroll notifications so that phantom sidebar bar never renders;
          // wheel/trackpad scrolling still works via the shared controller.
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) => true,
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _rowExtent,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final num =
                    (i + 1).toString().padLeft(shown.length.toString().length);
                final page = multiPage ? i ~/ perPage : 0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '$num.  ${shown[i]}',
                        style: theme.typography.caption1
                            .copyWith(fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (multiPage) ...[
                      const SizedBox(width: 8),
                      _JumpLink(
                        label: 'Page: ${page + 1} of $pageCount',
                        onTap: () =>
                            ref.read(batchPageProvider.notifier).set(page),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        _navBar(theme, serials.isEmpty),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            onPressed: serials.isEmpty
                ? null
                : () => showSerialLogDialog(context, serials),
            child: const Text('Open full log…'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            onPressed: serials.isEmpty
                ? null
                : () => showDigitalLinkBulkValidatorSheet(context, serials),
            child: const Text('Validate all'),
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
            Text('Serialization Log — ${serials.length} codes (full encoded payload)',
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

/// A small tappable "Page: # of Y" link that jumps the preview to a page.
class _JumpLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JumpLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: MacosTheme.of(context).typography.caption1.copyWith(
                fontFamily: 'monospace',
                color: const Color(0xFF0A84FF),
              ),
        ),
      ),
    );
  }
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
