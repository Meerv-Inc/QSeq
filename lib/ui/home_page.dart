// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_controller.dart';
import '../state/project_io.dart';
import 'about_pane.dart';
import 'export_actions.dart';
import 'inputs_panel.dart';
import 'preview_pane.dart';
import 'serialization_log.dart';
import 'size_readout.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: 'QSeq', menus: [
          PlatformMenuItem(
            label: 'About QSeq',
            onSelected: () => showAboutSheet(context),
          ),
          const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu),
          const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hide),
          const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hideOtherApplications),
          const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit),
        ]),
      ],
      child: MacosWindow(
      sidebar: Sidebar(
        minWidth: 320,
        maxWidth: 420,
        startWidth: 360,
        builder: (context, _) => const InputsPanel(),
      ),
      endSidebar: Sidebar(
        minWidth: 240,
        maxWidth: 360,
        startWidth: 280,
        shownByDefault: true,
        builder: (context, _) => const SerializationLog(),
      ),
      child: MacosScaffold(
        toolBar: ToolBar(
          title: const Text('QSeq'),
          titleWidth: 180,
          actions: [
            ToolBarIconButton(
              label: 'Open',
              icon: const MacosIcon(CupertinoIcons.folder),
              showLabel: true,
              onPressed: () => _openProject(ref),
            ),
            ToolBarIconButton(
              label: 'Save',
              icon: const MacosIcon(CupertinoIcons.floppy_disk),
              showLabel: true,
              onPressed: () => _saveProject(ref),
            ),
            ToolBarIconButton(
              label: 'Pick logo',
              icon: const MacosIcon(CupertinoIcons.photo),
              showLabel: true,
              onPressed: () => _pickLogo(ref),
            ),
            ToolBarIconButton(
              label: 'Copy',
              icon: const MacosIcon(CupertinoIcons.doc_on_clipboard),
              showLabel: true,
              onPressed: () => _run(context, ref, ExportActions.copyPng),
            ),
            ToolBarIconButton(
              label: 'PNG',
              icon: const MacosIcon(CupertinoIcons.photo_fill),
              showLabel: true,
              onPressed: () => _run(context, ref, ExportActions.exportPng),
            ),
            ToolBarIconButton(
              label: 'SVG',
              icon: const MacosIcon(CupertinoIcons.doc_text),
              showLabel: true,
              onPressed: () => _runSvg(context, ref),
            ),
            ToolBarIconButton(
              label: 'PDF',
              icon: const MacosIcon(CupertinoIcons.doc_richtext),
              showLabel: true,
              onPressed: () => _runPdf(context, ref),
            ),
            ToolBarIconButton(
              label: 'About',
              icon: const MacosIcon(CupertinoIcons.info_circle),
              showLabel: true,
              onPressed: () => showAboutSheet(context),
            ),
          ],
        ),
        children: [
          ContentArea(
            builder: (context, _) => const Column(
              children: [
                Expanded(child: PreviewPane()),
                SizeReadout(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _saveProject(WidgetRef ref) async {
    await ProjectIo.save(ref.read(appControllerProvider));
  }

  Future<void> _openProject(WidgetRef ref) async {
    final loaded = await ProjectIo.open();
    if (loaded != null) {
      ref.read(appControllerProvider.notifier).set(loaded);
    }
  }

  Future<void> _pickLogo(WidgetRef ref) async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Image', extensions: ['png', 'jpg', 'jpeg'])
    ]);
    if (file != null) {
      ref.read(appControllerProvider.notifier).update(
            (s) => s.copyWith(logoImagePath: file.path),
          );
    }
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<bool> Function(AppSettings) action) async {
    final s = ref.read(appControllerProvider);
    final ok = await action(s);
    if (context.mounted) _toast(context, ok);
  }

  Future<void> _runSvg(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appControllerProvider);
    final size = ref.read(singleSizeProvider);
    final ok = await ExportActions.exportSvg(s, size);
    if (context.mounted) _toast(context, ok);
  }

  Future<void> _runPdf(BuildContext context, WidgetRef ref) async {
    final s = ref.read(appControllerProvider);
    final size = ref.read(singleSizeProvider);
    final ok = await ExportActions.exportPdf(s, size);
    if (context.mounted) _toast(context, ok);
  }

  void _toast(BuildContext context, bool ok) {
    // Lightweight feedback without a full snackbar system.
    if (!ok) return;
  }
}
