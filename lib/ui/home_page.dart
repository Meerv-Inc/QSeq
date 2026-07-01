// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:flutter/material.dart' show ThemeMode;

import '../state/app_controller.dart';
import '../state/project_io.dart';
import 'about_pane.dart';
import 'digital_link_validator_pane.dart';
import 'export_actions.dart';
import 'inputs_panel.dart';
import 'license_pane.dart';
import 'preview_pane.dart';
import 'serialization_log.dart';
import 'size_readout.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // macos_ui leaves undecorated sidebars TRANSPARENT, expecting macOS window
    // vibrancy behind them. On Windows there is none — they composite over the
    // native window surface, which follows the OS theme. When the in-app theme
    // disagrees with the OS, that produced white-on-white (or black) panels.
    // Paint everything opaquely. The brightness comes straight from the theme
    // toggle (MacosTheme.of at this level still reflects the OS theme).
    final mode = ref.watch(themeModeProvider);
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final windowBg =
        dark ? const Color(0xFF1E1F21) : const Color(0xFFF6F6F8);
    final sideBg = dark ? const Color(0xFF26282A) : const Color(0xFFEFF0F2);
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: 'QSeq', menus: [
          PlatformMenuItem(
            label: 'About QSeq',
            onSelected: () => showAboutSheet(context),
          ),
          // The Services / Hide / Quit items are macOS-only platform-provided
          // menus; instantiating them on Windows throws. Include each only where
          // the running platform actually provides it.
          for (final type in const [
            PlatformProvidedMenuItemType.servicesSubmenu,
            PlatformProvidedMenuItemType.hide,
            PlatformProvidedMenuItemType.hideOtherApplications,
            PlatformProvidedMenuItemType.quit,
          ])
            if (PlatformProvidedMenuItem.hasMenu(type))
              PlatformProvidedMenuItem(type: type),
        ]),
      ],
      child: MacosWindow(
      backgroundColor: windowBg,
      // macos_ui clears the sidebar surface with BlendMode.clear (expecting
      // macOS window vibrancy behind it) — on Windows that erases ANY
      // background set via decoration, leaving the raw compositor surface
      // (black or white depending on the OS theme), which made panels
      // unreadable whenever the in-app theme differed. Painting INSIDE the
      // builder happens after the clear, so it sticks. topOffset: 0 removes
      // the macOS traffic-light inset that left an unpainted strip.
      sidebar: Sidebar(
        minWidth: 320,
        maxWidth: 420,
        startWidth: 360,
        topOffset: 0,
        builder: (context, _) =>
            ColoredBox(color: sideBg, child: const InputsPanel()),
      ),
      endSidebar: Sidebar(
        minWidth: 240,
        maxWidth: 420,
        startWidth: 320,
        shownByDefault: true,
        topOffset: 0,
        builder: (context, _) =>
            ColoredBox(color: sideBg, child: const SerializationLog()),
      ),
      child: MacosScaffold(
        toolBar: ToolBar(
          title: _titleRow(context, ref),
          titleWidth: 330,
          decoration: BoxDecoration(
              color: dark ? const Color(0xFF2A2C2E) : const Color(0xFFF2F3F5)),
          actions: [
            _toolButton(
                label: ref.watch(themeModeProvider) == ThemeMode.dark
                    ? 'Light'
                    : 'Dark',
                icon: ref.watch(themeModeProvider) == ThemeMode.dark
                    ? CupertinoIcons.sun_max
                    : CupertinoIcons.moon,
                onPressed: () => _toggleTheme(context, ref)),
            _toolButton(
                label: 'Open',
                icon: CupertinoIcons.folder,
                onPressed: () => _openProject(ref)),
            _toolButton(
                label: 'Save',
                icon: CupertinoIcons.floppy_disk,
                onPressed: () => _saveProject(ref)),
            _toolButton(
                label: 'Pick logo',
                icon: CupertinoIcons.photo,
                onPressed: () => _pickLogo(ref)),
            _toolButton(
                label: 'Copy',
                icon: CupertinoIcons.doc_on_clipboard,
                onPressed: () => _run(
                    context,
                    ref,
                    (s) => ExportActions.copyPng(s,
                        label: ref.read(labelSpecProvider)))),
            _toolButton(
                label: 'PNG',
                icon: CupertinoIcons.photo_fill,
                onPressed: () => _run(
                    context,
                    ref,
                    (s) => ExportActions.exportPng(s,
                        label: ref.read(labelSpecProvider)))),
            _toolButton(
                label: 'SVG',
                icon: CupertinoIcons.doc_text,
                onPressed: () => _runSvg(context, ref)),
            _toolButton(
                label: 'PDF',
                icon: CupertinoIcons.doc_richtext,
                onPressed: () => _runPdf(context, ref)),
            _toolButton(
                label: 'Validate',
                icon: CupertinoIcons.checkmark_shield,
                onPressed: () => showDigitalLinkValidatorSheet(context)),
            _toolButton(
                label: 'About',
                icon: CupertinoIcons.info_circle,
                onPressed: () => showAboutSheet(context)),
            _toolButton(
                label: 'License',
                icon: CupertinoIcons.doc_checkmark,
                onPressed: () => showLicenseSheet(context)),
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

  /// A toolbar button whose entire footprint — the icon *and* the label
  /// beneath it — is one tap target. The stock [ToolBarIconButton] only makes
  /// the glyph clickable (the label is a bare [Text]), so clicking "PDF" under
  /// the icon did nothing. [CustomToolbarItem] lets us hand the whole column to
  /// a single [MacosIconButton], and still degrades to an overflow-menu entry
  /// when the toolbar runs out of room.
  ToolbarItem _toolButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CustomToolbarItem(
      inToolbarBuilder: (context) {
        final brightness = MacosTheme.of(context).brightness;
        return MacosIconButton(
          disabledColor: const Color(0x00000000),
          onPressed: onPressed,
          mouseCursor: SystemMouseCursors.click,
          boxConstraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 20,
            maxWidth: 84,
            maxHeight: 46,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacosIconTheme(
                data: MacosTheme.of(context).iconTheme.copyWith(
                      color: brightness.resolve(
                        const Color.fromRGBO(0, 0, 0, 0.5),
                        const Color.fromRGBO(255, 255, 255, 0.5),
                      ),
                      size: 16.0,
                    ),
                child: MacosIcon(icon),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.0,
                    color: MacosColors.systemGrayColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      inOverflowedBuilder: (context) =>
          ToolbarOverflowMenuItem(label: label, onPressed: onPressed),
    );
  }

  /// "QSeq · `<project>.qseq` — edited/saved" in the toolbar title.
  Widget _titleRow(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(projectMetaProvider);
    final status = meta.path == null
        ? (meta.dirty ? 'not saved' : 'new')
        : (meta.dirty ? 'edited' : 'saved');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('QSeq'),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '${meta.name} — $status',
            overflow: TextOverflow.ellipsis,
            style: MacosTheme.of(context).typography.caption1.copyWith(
                color: meta.dirty
                    ? MacosColors.systemOrangeColor
                    : MacosColors.systemGrayColor),
          ),
        ),
      ],
    );
  }

  void _toggleTheme(BuildContext context, WidgetRef ref) {
    final mode = ref.read(themeModeProvider);
    // From "system", flip away from whatever is currently showing.
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MacosTheme.of(context).brightness == Brightness.dark);
    ref
        .read(themeModeProvider.notifier)
        .set(dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _saveProject(WidgetRef ref) async {
    final meta = ref.read(projectMetaProvider);
    final path = await ProjectIo.save(
      ref.read(appControllerProvider),
      label: ref.read(labelSpecProvider),
      toPath: meta.path,
    );
    if (path != null) {
      ref.read(projectMetaProvider.notifier).saved(path);
    }
  }

  Future<void> _openProject(WidgetRef ref) async {
    final loaded = await ProjectIo.open();
    if (loaded != null) {
      ref.read(appControllerProvider.notifier).set(loaded.settings);
      if (loaded.label != null) {
        ref.read(labelSpecProvider.notifier).set(loaded.label!);
      }
      ref.read(projectMetaProvider.notifier).opened(loaded.path);
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
    final ok = await ExportActions.exportPdf(s, size,
        label: ref.read(labelSpecProvider));
    if (context.mounted) _toast(context, ok);
  }

  void _toast(BuildContext context, bool ok) {
    // Lightweight feedback without a full snackbar system.
    if (!ok) return;
  }
}
