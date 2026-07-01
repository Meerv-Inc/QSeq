// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../encoders/gs1_keys.dart';
import '../encoders/gtin.dart';
import '../models/batch.dart';
import '../models/label_spec.dart';
import '../models/combined_label.dart';
import '../models/data_source.dart';
import '../models/symbology.dart';
import '../sizing/pdf417_capacity.dart';
import '../state/app_controller.dart';
import 'ui_helpers.dart';

class InputsPanel extends ConsumerWidget {
  const InputsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final c = ref.read(appControllerProvider.notifier);
    void update(AppSettings Function(AppSettings) fn) => c.update(fn);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _modeSection(ref, s, update),
        _dataSection(context, s, update),
        _symbologySection(s, update),
        if (s.mode.isCombo && !s.labelOn)
          _comboLayoutSection(context, s, update),
        if (s.labelOn) _labelDesignerSection(context, ref, s, update),
        if (s.mode.isSerialized) _batchSection(context, s, update),
        _printSection(s, update),
        _rulersSection(s, update),
        if (s.mode.use2D && s.twoDSymbology.supportsLogo)
          _logoSection(context, ref, s, update),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'QSeq · © 2026 Meerv Inc.',
            textAlign: TextAlign.center,
            style: MacosTheme.of(
              context,
            ).typography.caption2.copyWith(color: MacosColors.systemGrayColor),
          ),
        ),
      ],
    );
  }

  Widget _modeSection(
    WidgetRef ref,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    return SectionCard(
      title: 'Workspace',
      children: [
        // The two toggles sit above the Workspace selector.
        _checkRow('Label designer', s.labelOn, (v) {
          update((x) => x.copyWith(labelOn: v));
          if (v) {
            // The label shows exactly this workspace's symbols; re-arrange.
            ref.read(labelSpecProvider.notifier).mutate((spec) {
              spec.rects.clear();
            });
          }
          ref.read(labelSelectionProvider.notifier).set(null);
        }),
        // A GS1 key type that doesn't carry a serial (GLN, SSCC, GSRN, GSIN,
        // GIAI, GINC, CPID, GMN) has no "Serialization" concept to toggle.
        if (s.data.kind == DataSourceKind.sgtin &&
            (s.data.gs1KeyType == null || s.data.gs1KeyType!.supportsSerial))
          _checkRow('Serialization', s.data.serialize, (v) {
            update((x) {
              var nd = x.data.copyWith(serialize: v);
              if (!v && nd.sgtinFormat.epcScheme != null) {
                nd = nd.copyWith(sgtinFormat: SgtinFormat.digitalLink);
              }
              var mode = x.mode;
              if (!v && mode.isSerialRun) {
                mode = switch (mode) {
                  AppMode.twoDSerial => AppMode.twoD,
                  AppMode.oneDSerial => AppMode.oneD,
                  AppMode.comboSerial => AppMode.combo,
                  _ => mode,
                };
              }
              return x.copyWith(data: nd, mode: mode);
            });
          }),
        const SizedBox(height: 8),
        _dropdown<AppMode>(
          value: s.mode,
          items: {
            // Serialized runs are tributary to the Serialization checkbox, and
            // to the GS1 key type supporting a serial at all.
            for (final m in AppMode.values)
              if (s.data.kind != DataSourceKind.sgtin ||
                  ((s.data.gs1KeyType == null ||
                          s.data.gs1KeyType!.supportsSerial) &&
                      s.data.serialize) ||
                  !m.isSerialRun)
                m: m.label,
          },
          onChanged: (v) => update((x) => x.copyWith(mode: v)),
        ),
      ],
    );
  }

  Widget _dataSection(
    BuildContext context,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final d = s.data;
    final isCombo = s.mode.isCombo;
    final children = <Widget>[
      LabeledField(
        label: 'Data source',
        child: _dropdown<DataSourceKind>(
          value: d.kind,
          items: const {
            DataSourceKind.sgtin: 'GS1',
            DataSourceKind.rawText: 'Free text',
          },
          onChanged: (v) =>
              update((x) => x.copyWith(data: d.copyWith(kind: v))),
        ),
      ),
    ];

    if (d.kind == DataSourceKind.sgtin) {
      children.add(
        LabeledField(
          label: 'GS1 identifier type',
          child: MacosPopupButton<Gs1KeyType?>(
            value: d.gs1KeyType,
            onChanged: (v) =>
                update((x) => x.copyWith(data: d.copyWith(gs1KeyType: v))),
            items: [
              const MacosPopupMenuItem<Gs1KeyType?>(
                value: null,
                child: Text('GTIN / SGTIN'),
              ),
              for (final t in Gs1KeyType.values)
                MacosPopupMenuItem<Gs1KeyType?>(
                  value: t,
                  child: Text(t.shortTitle),
                ),
            ],
          ),
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Builder(
            builder: (context) => Text(
              gs1KeyStructureDescription(d.gs1KeyType),
              style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
            ),
          ),
        ),
      );
      if (d.gs1KeyType == null) {
        children.add(
          LabeledField(
            label: 'GTIN length',
            child: _dropdown<int>(
              value: d.gtinLength,
              items: {
                for (final len in Gtin.lengths)
                  len: 'GTIN-$len · e.g. ${Gtin.example(len)}',
              },
              onChanged: (v) =>
                  update((x) => x.copyWith(data: d.copyWith(gtinLength: v))),
            ),
          ),
        );
        children.add(
          LabeledField(
            label: 'GTIN',
            child: _text(
              d.gtin,
              (v) => update((x) => x.copyWith(data: d.copyWith(gtin: v))),
            ),
          ),
        );
        children.add(_gtinActions(context, d, update));
        // Serialization toggle lives in the Workspace card (above the selector).
        if (d.serialize && !s.mode.isSerialized) {
          children.add(
            LabeledField(
              label: 'Serial',
              child: _text(
                d.serial,
                (v) => update((x) => x.copyWith(data: d.copyWith(serial: v))),
              ),
            ),
          );
        }
        if (!isCombo && !s.labelOn) {
          children.add(
            LabeledField(
              label: 'Format',
              child: _dropdown<SgtinFormat>(
                value: d.sgtinFormat,
                items: {
                  for (final f in SgtinFormat.values)
                    if (d.serialize || f.epcScheme == null) f: f.label,
                },
                onChanged: (v) =>
                    update((x) => x.copyWith(data: d.copyWith(sgtinFormat: v))),
              ),
            ),
          );
          if (d.serialize &&
              (d.sgtinFormat == SgtinFormat.sgtin96 ||
                  d.sgtinFormat == SgtinFormat.sgtin198)) {
            children.add(
              LabeledField(
                label: 'Company prefix length',
                child: NumberField(
                  value: d.companyPrefixLength.toDouble(),
                  onChanged: (v) => update(
                    (x) => x.copyWith(
                      data: d.copyWith(
                        companyPrefixLength: v.round().clamp(6, 12),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        if (isCombo || s.labelOn || d.sgtinFormat == SgtinFormat.digitalLink) {
          children.addAll(_resolverFields(d, update));
        }
      } else {
        final type = d.gs1KeyType!;
        if (type == Gs1KeyType.ginc || type == Gs1KeyType.gmn) {
          children.add(
            LabeledField(
              label: type == Gs1KeyType.ginc
                  ? 'Consignment ID'
                  : 'Model number',
              child: _text(
                d.gs1OpaqueValue,
                (v) => update(
                  (x) => x.copyWith(data: d.copyWith(gs1OpaqueValue: v)),
                ),
              ),
            ),
          );
        } else {
          children.add(
            LabeledField(
              label: 'Company prefix',
              child: _text(
                d.gs1CompanyPrefix,
                (v) => update(
                  (x) => x.copyWith(data: d.copyWith(gs1CompanyPrefix: v)),
                ),
              ),
            ),
          );
          children.add(
            LabeledField(
              label: _gs1ReferenceLabel(type),
              child: _text(
                d.gs1Reference,
                (v) => update(
                  (x) => x.copyWith(data: d.copyWith(gs1Reference: v)),
                ),
              ),
            ),
          );
          if (type == Gs1KeyType.sscc) {
            children.add(
              LabeledField(
                label: 'Extension digit (0–9)',
                child: NumberField(
                  value: d.gs1ExtensionDigit.toDouble(),
                  onChanged: (v) => update(
                    (x) => x.copyWith(
                      data: d.copyWith(
                        gs1ExtensionDigit: v.round().clamp(0, 9),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        // Serialization toggle lives in the Workspace card (above the selector).
        if (type.supportsSerial && d.serialize && !s.mode.isSerialized) {
          children.add(
            LabeledField(
              label: 'Serial',
              child: _text(
                d.gs1KeySerial,
                (v) => update(
                  (x) => x.copyWith(data: d.copyWith(gs1KeySerial: v)),
                ),
              ),
            ),
          );
        }
        if (!isCombo && !s.labelOn) {
          children.add(
            LabeledField(
              label: 'Format',
              child: _dropdown<SgtinFormat>(
                value: d.sgtinFormat.epcScheme != null
                    ? SgtinFormat.digitalLink
                    : d.sgtinFormat,
                items: const {
                  SgtinFormat.elementString: 'GS1-128',
                  SgtinFormat.digitalLink: 'GS1 Digital Link',
                },
                onChanged: (v) =>
                    update((x) => x.copyWith(data: d.copyWith(sgtinFormat: v))),
              ),
            ),
          );
        }
        if (isCombo || s.labelOn || d.sgtinFormat == SgtinFormat.digitalLink) {
          children.addAll(_resolverFields(d, update));
        }
      }
    } else {
      children.add(
        LabeledField(
          label: s.mode.isSerialized ? 'Text (serial appended)' : 'Text',
          child: _text(
            d.rawText,
            (v) => update((x) => x.copyWith(data: d.copyWith(rawText: v))),
          ),
        ),
      );
    }

    children.add(_resolvedPreview(context, s.data.resolve()));
    return SectionCard(title: 'Data', children: children);
  }

  /// The label for [DataSourceInput.gs1Reference] — the field next to the
  /// company prefix — which means something different per [Gs1KeyType].
  /// Unused for GINC/GMN, which have no company-prefix split.
  String _gs1ReferenceLabel(Gs1KeyType type) => switch (type) {
    Gs1KeyType.grai => 'Asset type',
    Gs1KeyType.gdti => 'Doc type',
    Gs1KeyType.gcn => 'Coupon ref',
    Gs1KeyType.gln => 'Location ref',
    Gs1KeyType.sscc => 'Serial ref',
    Gs1KeyType.gsrnProvider || Gs1KeyType.gsrnRecipient => 'Service ref',
    Gs1KeyType.gsin => 'Shipper ref',
    Gs1KeyType.giai => 'Asset ref',
    Gs1KeyType.cpid => 'Component ref',
    Gs1KeyType.ginc || Gs1KeyType.gmn => '',
  };

  /// The "Resolver" preset dropdown + "Digital Link domain" text field,
  /// shared by the GTIN/SGTIN and the other GS1 key type branches.
  List<Widget> _resolverFields(
    DataSourceInput d,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    return [
      LabeledField(
        label: 'Resolver',
        child: _dropdown<String>(
          value: _resolverPreset(d.digitalLinkDomain),
          items: const {
            'https://id.gs1.org': 'GS1 · id.gs1.org',
            'https://tapdpp.qdat.io': 'QDat.io · tapdpp.qdat.io',
            'custom': 'Custom…',
          },
          onChanged: (v) {
            if (v != 'custom') {
              update((x) => x.copyWith(data: d.copyWith(digitalLinkDomain: v)));
            }
          },
        ),
      ),
      LabeledField(
        label: 'Digital Link domain',
        child: _text(
          d.digitalLinkDomain,
          (v) =>
              update((x) => x.copyWith(data: d.copyWith(digitalLinkDomain: v))),
        ),
      ),
    ];
  }

  Widget _resolvedPreview(BuildContext context, ResolvedData r) {
    final theme = MacosTheme.of(context);
    final isError = r.data == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isError ? MacosColors.systemRedColor : theme.dividerColor,
        ),
      ),
      child: Text(
        r.data ?? (r.error ?? ''),
        style: theme.typography.caption1.copyWith(
          fontFamily: 'monospace',
          color: isError ? MacosColors.systemRedColor : null,
        ),
      ),
    );
  }

  Widget _symbologySection(
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final oneDItems = {
      for (final sym in Symbology.values.where((x) => !x.is2D))
        sym: sym.displayName,
    };
    const twoDItems = {
      Symbology.qrCode: 'QR Code',
      Symbology.dataMatrix: 'Data Matrix',
      Symbology.pdf417: 'PDF417',
    };
    final children = <Widget>[];
    if (s.mode.use2D) {
      children.add(
        LabeledField(
          label: '2D symbology',
          child: _dropdown<Symbology>(
            value: s.twoDSymbology,
            items: twoDItems,
            onChanged: (v) => update((x) => x.copyWith(twoDSymbology: v)),
          ),
        ),
      );
      if (s.twoDSymbology.supportsEcLevel) {
        children.add(
          LabeledField(
            label: 'Error correction',
            child: _ecDropdown(s, update),
          ),
        );
      }
      if (s.twoDSymbology.supportsPdf417EcLevel) {
        children.add(
          LabeledField(
            label: 'Error correction',
            child: _pdf417EcDropdown(s, update),
          ),
        );
      }
    }
    if (s.mode.use1D) {
      children.add(
        LabeledField(
          label: '1D symbology',
          child: _dropdown<Symbology>(
            value: s.oneDSymbology,
            items: oneDItems,
            onChanged: (v) => update((x) => x.copyWith(oneDSymbology: v)),
          ),
        ),
      );
    }
    return SectionCard(title: 'Symbology', children: children);
  }

  Widget _comboLayoutSection(
    BuildContext context,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final children = <Widget>[
      LabeledField(
        label: 'Gap between 1D & 2D (mm)',
        child: NumberField(
          value: s.labelGapMm,
          onChanged: (v) => update((x) => x.copyWith(labelGapMm: v)),
        ),
      ),
    ];
    // Arrangement & outer padding apply to a static combined label only;
    // serialized combos always stack 2D over 1D within each sheet cell.
    if (s.mode == AppMode.combo) {
      // PDF417 is already wide on its own, so a combined label always stacks
      // it over the 1D code — side by side would make the label excessively
      // wide. The Arrangement choice has no effect while PDF417 is selected.
      if (s.twoDSymbology == Symbology.pdf417) {
        children.insert(
          0,
          Text(
            'Arrangement: Stacked (forced — PDF417 is too wide to place '
            'side by side with a 1D code).',
            style: MacosTheme.of(context).typography.caption2.copyWith(
              color: MacosColors.systemGrayColor,
            ),
          ),
        );
      } else {
        children.insert(
          0,
          LabeledField(
            label: 'Arrangement',
            child: _dropdown<LabelArrangement>(
              value: s.arrangement,
              items: {for (final a in LabelArrangement.values) a: a.label},
              onChanged: (v) => update((x) => x.copyWith(arrangement: v)),
            ),
          ),
        );
      }
      children.add(
        LabeledField(
          label: 'Outer padding (mm)',
          child: NumberField(
            value: s.labelPaddingMm,
            onChanged: (v) => update((x) => x.copyWith(labelPaddingMm: v)),
          ),
        ),
      );
    }
    return SectionCard(title: 'Label layout', children: children);
  }

  Widget _labelDesignerSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final spec = ref.watch(labelSpecProvider);
    final c = ref.read(labelSpecProvider.notifier);
    void mutate(void Function(LabelSpec) fn) => c.mutate(fn);
    return SectionCard(
      title: 'Label',
      children: [
        Text(
          'Click an element in the preview to select it; drag to move, drag the '
          'corner handle to resize. The 2D carries the Digital Link URL, the 1D '
          'the GS1 element string; one shared human-readable line spans the '
          'label.',
          style: MacosTheme.of(
            context,
          ).typography.caption2.copyWith(color: MacosColors.systemGrayColor),
        ),
        const SizedBox(height: 8),
        LabeledField(
          label: 'Label width (mm)',
          child: NumberField(
            value: spec.wMm,
            onChanged: (v) => mutate((sp) {
              sp.wMm = v.clamp(10.0, 2000.0);
              sp.rects.clear();
            }),
          ),
        ),
        LabeledField(
          label: 'Label height (mm)',
          child: NumberField(
            value: spec.hMm,
            onChanged: (v) => mutate((sp) {
              sp.hMm = v.clamp(10.0, 2000.0);
              sp.rects.clear();
            }),
          ),
        ),
        LabeledField(
          label: 'Title text',
          child: _text(spec.title, (v) => mutate((sp) => sp.title = v)),
        ),
        _checkRow(
          'Title',
          spec.titleOn,
          (v) => mutate((sp) {
            sp.titleOn = v;
            sp.rects.clear();
          }),
        ),
        const SizedBox(height: 4),
        _checkRow(
          'Shared text (HRI)',
          spec.hriOn,
          (v) => mutate((sp) {
            sp.hriOn = v;
            sp.rects.clear();
          }),
        ),
        if (spec.hriOn)
          LabeledField(
            label: 'HRI font size (mm, 0 = auto)',
            child: NumberField(
              value: spec.hriFontMm,
              onChanged: (v) =>
                  mutate((sp) => sp.hriFontMm = v.clamp(0.0, 30.0)),
            ),
          ),
        const SizedBox(height: 4),
        _checkRow(
          'Show label frame',
          spec.frameShown,
          (v) => mutate((sp) => sp.frameShown = v),
        ),
        const SizedBox(height: 4),
        _checkRow(
          'Print frame (cut guide)',
          spec.framePrinted,
          (v) => mutate((sp) => sp.framePrinted = v),
        ),
        const SizedBox(height: 4),
        _checkRow(
          'Snap to grid',
          spec.snap,
          (v) => mutate((sp) => sp.snap = v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            PushButton(
              controlSize: ControlSize.regular,
              secondary: true,
              onPressed: () => mutate((sp) => sp.rects.clear()),
              child: const Text('Auto-arrange'),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              secondary: true,
              onPressed: () => _pickLabelBg(ref),
              child: const Text('Background…'),
            ),
            const SizedBox(width: 8),
            if (spec.bgImagePath != null)
              PushButton(
                controlSize: ControlSize.regular,
                secondary: true,
                onPressed: () => mutate((sp) => sp.bgImagePath = null),
                child: const Text('Remove bg'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickLabelBg(WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Image', extensions: ['png', 'jpg', 'jpeg']),
      ],
    );
    if (file != null) {
      ref
          .read(labelSpecProvider.notifier)
          .mutate((sp) => sp.bgImagePath = file.path);
    }
  }

  Widget _batchSection(
    BuildContext context,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    return SectionCard(
      title: s.mode.isCopies ? 'Sheet of copies' : 'Serialization',
      children: [
        LabeledField(
          label: 'Serial — start of serialization (counter printed bold)',
          child: _text(
            s.data.serial,
            (v) => update((x) => x.copyWith(data: s.data.copyWith(serial: v))),
          ),
        ),
        Text(
          'The trailing digits increment per item — 6789, 6790, … — and any '
          'leading text stays as a fixed prefix. Every generated identifier is '
          'listed in the Serialization Log.',
          style: MacosTheme.of(
            context,
          ).typography.caption2.copyWith(color: MacosColors.systemGrayColor),
        ),
        const SizedBox(height: 8),
        if (s.mode.isCopies)
          LabeledField(
            label: 'Copies (each one incremented)',
            child: NumberField(
              value: s.batchCopies.toDouble(),
              onChanged: (v) => update(
                (x) => x.copyWith(batchCopies: v.round().clamp(1, 2000)),
              ),
            ),
          )
        else
          LabeledField(
            label: 'Count',
            child: NumberField(
              value: s.batchCount.toDouble(),
              onChanged: (v) => update(
                (x) => x.copyWith(batchCount: v.round().clamp(1, 2000)),
              ),
            ),
          ),
        LabeledField(
          label: 'Page size',
          child: _dropdown<PageFormat>(
            value: s.pageFormat,
            items: {for (final p in PageFormat.values) p: p.label},
            onChanged: (v) => update((x) => x.copyWith(pageFormat: v)),
          ),
        ),
        // Orientation only applies to finite cut sheets; a continuous web has no
        // second dimension to rotate.
        if (!s.pageFormat.isContinuous)
          LabeledField(
            label: 'Orientation',
            child: _dropdown<PageOrientation>(
              value: s.pageOrientation,
              items: const {
                PageOrientation.portrait: 'Portrait',
                PageOrientation.landscape: 'Landscape',
              },
              onChanged: (v) => update((x) => x.copyWith(pageOrientation: v)),
            ),
          ),
        LabeledField(
          label: 'Columns (0 = auto-fit)',
          child: NumberField(
            value: s.batchColumns.toDouble(),
            onChanged: (v) =>
                update((x) => x.copyWith(batchColumns: v.round().clamp(0, 50))),
          ),
        ),
      ],
    );
  }

  Widget _printSection(
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    return SectionCard(
      title: 'Print',
      children: [
        LabeledField(
          label: 'Resolution',
          child: NumberField(
            value: s.dpi,
            suffix: 'DPI',
            onChanged: (v) => update((x) => x.copyWith(dpi: v)),
          ),
        ),
        LabeledField(
          label: 'X-dimension (module / narrow bar)',
          child: NumberField(
            value: s.xDimensionMm,
            suffix: 'mm',
            onChanged: (v) => update((x) => x.copyWith(xDimensionMm: v)),
          ),
        ),
        if (s.mode.use1D)
          LabeledField(
            label: 'Bar height',
            child: NumberField(
              value: s.barHeightMm,
              suffix: 'mm',
              onChanged: (v) => update((x) => x.copyWith(barHeightMm: v)),
            ),
          ),
      ],
    );
  }

  Widget _rulersSection(
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    return SectionCard(
      title: 'Rulers',
      children: [
        _checkRow(
          'Show rulers around the preview',
          s.rulersOnScreen,
          (v) => update((x) => x.copyWith(rulersOnScreen: v)),
        ),
        const SizedBox(height: 6),
        _checkRow(
          'Include rulers in PNG / PDF exports',
          s.rulersInExports,
          (v) => update((x) => x.copyWith(rulersInExports: v)),
        ),
      ],
    );
  }

  Widget _logoSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final on = s.logoSideMm > 0;
    final theme = MacosTheme.of(context);

    // Re-derive the auto size after a settings change (the provider reflects
    // the freshly updated state when read inside the callback).
    void applyAuto(void Function(AppSettings Function(AppSettings)) u) {
      final side = ref.read(autoLogoSideProvider);
      u((x) => x.copyWith(logoSideMm: side));
    }

    final children = <Widget>[
      _checkRow('Logo', on, (checked) {
        update(
          (x) => x.copyWith(
            logoManual: false,
            logoEcBudget: checked ? x.logoEcShare : x.logoEcBudget,
          ),
        );
        if (checked) {
          applyAuto(update);
        } else {
          update((x) => x.copyWith(logoSideMm: 0));
        }
      }),
    ];

    if (on) {
      children.addAll([
        const SizedBox(height: 8),
        LabeledField(
          label: 'Dead-space size',
          child: _dropdown<String>(
            value: s.logoManual ? 'manual' : '${(s.logoEcShare * 100).round()}',
            items: const {
              '15': '15% of error correction',
              '20': '20% of error correction',
              '30': '30% of error correction',
              '40': '40% of error correction',
              '50': '50% of error correction',
              'manual': 'Manual…',
            },
            onChanged: (v) {
              if (v == 'manual') {
                update((x) => x.copyWith(logoManual: true));
              } else {
                final share = int.parse(v) / 100;
                update(
                  (x) => x.copyWith(
                    logoManual: false,
                    logoEcShare: share,
                    logoEcBudget: share,
                  ),
                );
                applyAuto(update);
              }
            },
          ),
        ),
        if (s.logoManual)
          LabeledField(
            label: 'Dead-space side (mm)',
            child: NumberField(
              value: s.logoSideMm,
              suffix: 'mm',
              onChanged: (v) =>
                  update((x) => x.copyWith(logoSideMm: v.clamp(1, 100))),
            ),
          ),
      ]);

      // EC consumption + the scanability consequence, like the web app.
      final share = ref.watch(logoShareUsedProvider);
      if (share != null) {
        final String note;
        final Color color;
        if (share >= 1) {
          color = MacosColors.systemRedColor;
          note =
              'The dead-space destroys more data than the error correction '
              'can recover — the code will NOT scan. Shrink the dead-space or '
              'raise the error-correction level.';
        } else if (share > 0.5) {
          color = MacosColors.systemOrangeColor;
          note =
              'Over half the error correction is spent on the dead-space. '
              'A perfect print will scan, but little margin is left for '
              'real-world damage — print defects, scuffs, fading or curvature '
              'can make the code unreadable.';
        } else {
          color = MacosColors.systemGreenColor;
          note =
              'At least half the error correction stays available to '
              'absorb real-world damage (print defects, scuffs, fading) — '
              'readability stays robust.';
        }
        children.addAll([
          const SizedBox(height: 8),
          Text(
            'Dead-space ≈ ${s.logoSideMm.toStringAsFixed(1)} mm · uses '
            '≈ ${(share * 100).round()}% of the symbol’s error-correction '
            'capacity.',
            style: theme.typography.caption2.copyWith(
              color: MacosColors.systemGrayColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(note, style: theme.typography.caption2.copyWith(color: color)),
        ]);
      }
    } else {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          'Reserves a clean centre square in the 2D symbol for a logo — '
          'finder, timing and alignment patterns always show through. '
          'Pick an image from the toolbar to fill it.',
          style: theme.typography.caption2.copyWith(
            color: MacosColors.systemGrayColor,
          ),
        ),
      ]);
    }
    return SectionCard(title: 'Logo', children: children);
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlainCheckbox(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }

  // --- small control helpers ---

  Widget _ecDropdown(
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) u,
  ) => _dropdown<QrEcLevel>(
    value: s.ecLevel,
    items: {
      for (final e in QrEcLevel.values)
        e: '${e.label} · ${(e.recoverableFraction * 100).round()}%',
    },
    onChanged: (v) => u((x) => x.copyWith(ecLevel: v)),
  );

  Widget _pdf417EcDropdown(
    AppSettings s,
    void Function(AppSettings Function(AppSettings)) u,
  ) => _dropdown<Pdf417EcLevel>(
    value: s.pdf417EcLevel,
    items: {for (final e in Pdf417EcLevel.values) e: e.label},
    onChanged: (v) => u((x) => x.copyWith(pdf417EcLevel: v)),
  );

  static const _knownResolvers = {
    'https://id.gs1.org',
    'https://tapdpp.qdat.io',
  };
  String _resolverPreset(String domain) =>
      _knownResolvers.contains(domain) ? domain : 'custom';

  Widget _text(String value, ValueChanged<String> onChanged) =>
      PlainTextField(value: value, onChanged: onChanged);

  /// "Generate a valid GTIN" button plus a live check-digit status: a one-click
  /// fix when the trailing digit is wrong, or a confirmation when it is valid.
  Widget _gtinActions(
    BuildContext context,
    DataSourceInput d,
    void Function(AppSettings Function(AppSettings)) update,
  ) {
    final raw = d.gtin.trim();
    final canCheck = Gtin.isAllDigits(raw) && Gtin.lengths.contains(raw.length);
    int? expected;
    var ok = false;
    if (canCheck) {
      expected = Gtin.checkDigit(raw.substring(0, raw.length - 1));
      ok = expected == raw.codeUnitAt(raw.length - 1) - 0x30;
    }
    final caption = MacosTheme.of(context).typography.caption1;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: () => update(
              (x) => x.copyWith(
                data: d.copyWith(gtin: Gtin.generate(d.gtinLength)),
              ),
            ),
            child: Text('Generate GTIN-${d.gtinLength}'),
          ),
          const SizedBox(width: 8),
          if (canCheck && !ok) ...[
            PushButton(
              controlSize: ControlSize.regular,
              secondary: true,
              onPressed: () => update(
                (x) => x.copyWith(
                  data: d.copyWith(
                    gtin: '${raw.substring(0, raw.length - 1)}$expected',
                  ),
                ),
              ),
              child: const Text('Fix check digit'),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'check digit should be $expected',
                style: caption.copyWith(color: MacosColors.systemRedColor),
              ),
            ),
          ] else if (ok)
            Text(
              '✓ check digit valid',
              style: caption.copyWith(color: MacosColors.systemGreenColor),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return MacosPopupButton<T>(
      value: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: [
        for (final e in items.entries)
          MacosPopupMenuItem<T>(value: e.key, child: Text(e.value)),
      ],
    );
  }
}
