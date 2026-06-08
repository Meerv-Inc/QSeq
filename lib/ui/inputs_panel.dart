import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/batch.dart';
import '../models/combined_label.dart';
import '../models/data_source.dart';
import '../models/symbology.dart';
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
        _modeSection(s, update),
        _dataSection(context, s, update),
        _symbologySection(s, update),
        if (s.mode.isCombo) _comboLayoutSection(s, update),
        if (s.mode.isSerialized) _batchSection(s, update),
        _printSection(s, update),
        if (s.mode.use2D) _logoSection(context, s, update),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'QSeq · © 2026 Meerv Inc.',
            textAlign: TextAlign.center,
            style: MacosTheme.of(context)
                .typography
                .caption2
                .copyWith(color: MacosColors.systemGrayColor),
          ),
        ),
      ],
    );
  }

  Widget _modeSection(
      AppSettings s, void Function(AppSettings Function(AppSettings)) update) {
    return SectionCard(title: 'Workspace', children: [
      _dropdown<AppMode>(
        value: s.mode,
        items: {for (final m in AppMode.values) m: m.label},
        onChanged: (v) => update((x) => x.copyWith(mode: v)),
      ),
    ]);
  }

  Widget _dataSection(BuildContext context, AppSettings s,
      void Function(AppSettings Function(AppSettings)) update) {
    final d = s.data;
    final isCombo = s.mode.isCombo;
    final children = <Widget>[
      LabeledField(
        label: 'Data source',
        child: _dropdown<DataSourceKind>(
          value: d.kind,
          items: const {
            DataSourceKind.sgtin: 'SGTIN',
            DataSourceKind.nsn: 'NATO Stock Number',
            DataSourceKind.rawText: 'Free text',
          },
          onChanged: (v) =>
              update((x) => x.copyWith(data: d.copyWith(kind: v))),
        ),
      ),
    ];

    if (d.kind == DataSourceKind.sgtin) {
      children.add(LabeledField(
        label: 'GTIN (8/12/13/14)',
        child: _text(d.gtin,
            (v) => update((x) => x.copyWith(data: d.copyWith(gtin: v)))),
      ));
      if (!s.mode.isSerialized) {
        children.add(LabeledField(
          label: 'Serial',
          child: _text(d.serial,
              (v) => update((x) => x.copyWith(data: d.copyWith(serial: v)))),
        ));
      }
      if (!isCombo) {
        children.add(LabeledField(
          label: 'SGTIN format',
          child: _dropdown<SgtinFormat>(
            value: d.sgtinFormat,
            items: {for (final f in SgtinFormat.values) f: f.label},
            onChanged: (v) =>
                update((x) => x.copyWith(data: d.copyWith(sgtinFormat: v))),
          ),
        ));
        if (d.sgtinFormat == SgtinFormat.epcTagUri) {
          children.add(LabeledField(
            label: 'Company prefix length',
            child: NumberField(
              value: d.companyPrefixLength.toDouble(),
              onChanged: (v) => update((x) => x.copyWith(
                  data:
                      d.copyWith(companyPrefixLength: v.round().clamp(6, 12)))),
            ),
          ));
        }
      }
      if (isCombo || d.sgtinFormat == SgtinFormat.digitalLink) {
        children.add(LabeledField(
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
        ));
        children.add(LabeledField(
          label: 'Digital Link domain',
          child: _text(
              d.digitalLinkDomain,
              (v) => update(
                  (x) => x.copyWith(data: d.copyWith(digitalLinkDomain: v)))),
        ));
      }
    } else if (d.kind == DataSourceKind.nsn) {
      children.add(LabeledField(
        label: 'NATO Stock Number',
        child: _text(d.nsn,
            (v) => update((x) => x.copyWith(data: d.copyWith(nsn: v)))),
      ));
    } else {
      children.add(LabeledField(
        label: s.mode.isSerialized ? 'Text (serial appended)' : 'Text',
        child: _text(d.rawText,
            (v) => update((x) => x.copyWith(data: d.copyWith(rawText: v)))),
      ));
    }

    children.add(_resolvedPreview(context, s.data.resolve()));
    return SectionCard(title: 'Data', children: children);
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
            color: isError ? MacosColors.systemRedColor : theme.dividerColor),
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
      AppSettings s, void Function(AppSettings Function(AppSettings)) update) {
    final oneDItems = {
      for (final sym in Symbology.values.where((x) => !x.is2D))
        sym: sym.displayName
    };
    const twoDItems = {
      Symbology.qrCode: 'QR Code',
      Symbology.dataMatrix: 'Data Matrix',
    };
    final children = <Widget>[];
    if (s.mode.use2D) {
      children.add(LabeledField(
        label: '2D symbology',
        child: _dropdown<Symbology>(
          value: s.twoDSymbology,
          items: twoDItems,
          onChanged: (v) => update((x) => x.copyWith(twoDSymbology: v)),
        ),
      ));
      if (s.twoDSymbology.supportsEcLevel) {
        children.add(LabeledField(
          label: 'Error correction',
          child: _ecDropdown(s, update),
        ));
      }
    }
    if (s.mode.use1D) {
      children.add(LabeledField(
        label: '1D symbology',
        child: _dropdown<Symbology>(
          value: s.oneDSymbology,
          items: oneDItems,
          onChanged: (v) => update((x) => x.copyWith(oneDSymbology: v)),
        ),
      ));
    }
    return SectionCard(title: 'Symbology', children: children);
  }

  Widget _comboLayoutSection(
      AppSettings s, void Function(AppSettings Function(AppSettings)) update) {
    final children = <Widget>[
      LabeledField(
        label: 'Gap between 1D & 2D (mm)',
        child: NumberField(
            value: s.labelGapMm,
            onChanged: (v) => update((x) => x.copyWith(labelGapMm: v))),
      ),
    ];
    // Arrangement & outer padding apply to a static combined label only;
    // serialized combos always stack 2D over 1D within each sheet cell.
    if (s.mode == AppMode.combo) {
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
      children.add(LabeledField(
        label: 'Outer padding (mm)',
        child: NumberField(
            value: s.labelPaddingMm,
            onChanged: (v) => update((x) => x.copyWith(labelPaddingMm: v))),
      ));
    }
    return SectionCard(title: 'Label layout', children: children);
  }

  Widget _batchSection(
      AppSettings s, void Function(AppSettings Function(AppSettings)) update) {
    return SectionCard(title: 'Serialization', children: [
      LabeledField(
        label: 'Serial prefix (printed normal)',
        child: _text(s.batchPrefix,
            (v) => update((x) => x.copyWith(batchPrefix: v))),
      ),
      LabeledField(
        label: 'Start number (printed bold)',
        child: NumberField(
            value: s.batchStart.toDouble(),
            onChanged: (v) =>
                update((x) => x.copyWith(batchStart: v.round()))),
      ),
      LabeledField(
        label: 'Count',
        child: NumberField(
            value: s.batchCount.toDouble(),
            onChanged: (v) => update(
                (x) => x.copyWith(batchCount: v.round().clamp(1, 5000)))),
      ),
      LabeledField(
        label: 'Zero-pad digits',
        child: NumberField(
            value: s.batchPadding.toDouble(),
            onChanged: (v) => update(
                (x) => x.copyWith(batchPadding: v.round().clamp(0, 12)))),
      ),
      LabeledField(
        label: 'Page size',
        child: _dropdown<PageFormat>(
          value: s.pageFormat,
          items: {for (final p in PageFormat.values) p: p.label},
          onChanged: (v) => update((x) => x.copyWith(pageFormat: v)),
        ),
      ),
      LabeledField(
        label: 'Columns (0 = auto-fit)',
        child: NumberField(
            value: s.batchColumns.toDouble(),
            onChanged: (v) => update(
                (x) => x.copyWith(batchColumns: v.round().clamp(0, 50)))),
      ),
    ]);
  }

  Widget _printSection(
      AppSettings s, void Function(AppSettings Function(AppSettings)) update) {
    return SectionCard(title: 'Print', children: [
      LabeledField(
        label: 'Resolution',
        child: NumberField(
            value: s.dpi,
            suffix: 'DPI',
            onChanged: (v) => update((x) => x.copyWith(dpi: v))),
      ),
      LabeledField(
        label: 'X-dimension (module / narrow bar)',
        child: NumberField(
            value: s.xDimensionMm,
            suffix: 'mm',
            onChanged: (v) => update((x) => x.copyWith(xDimensionMm: v))),
      ),
      if (s.mode.use1D)
        LabeledField(
          label: 'Bar height',
          child: NumberField(
              value: s.barHeightMm,
              suffix: 'mm',
              onChanged: (v) => update((x) => x.copyWith(barHeightMm: v))),
        ),
    ]);
  }

  Widget _logoSection(BuildContext context, AppSettings s,
      void Function(AppSettings Function(AppSettings)) update) {
    return SectionCard(title: 'Logo dead-space', children: [
      LabeledField(
        label: 'Logo size (square side)',
        child: NumberField(
            value: s.logoSideMm,
            suffix: 'mm',
            onChanged: (v) => update((x) => x.copyWith(logoSideMm: v))),
      ),
      LabeledField(
        label: 'Logo may use this share of EC capacity',
        child: NumberField(
            value: (s.logoEcBudget * 100).roundToDouble(),
            suffix: '%',
            onChanged: (v) => update((x) =>
                x.copyWith(logoEcBudget: (v / 100).clamp(0.05, 0.95)))),
      ),
      Text(
        'Lower = smaller, safer logo (more error-correction kept in reserve). '
        'Higher = larger logo, less tolerant of print defects/damage.',
        style: MacosTheme.of(context)
            .typography
            .caption2
            .copyWith(color: MacosColors.systemGrayColor),
      ),
    ]);
  }

  // --- small control helpers ---

  Widget _ecDropdown(
          AppSettings s, void Function(AppSettings Function(AppSettings)) u) =>
      _dropdown<QrEcLevel>(
        value: s.ecLevel,
        items: {
          for (final e in QrEcLevel.values)
            e: '${e.label} · ${(e.recoverableFraction * 100).round()}%'
        },
        onChanged: (v) => u((x) => x.copyWith(ecLevel: v)),
      );

  static const _knownResolvers = {
    'https://id.gs1.org',
    'https://tapdpp.qdat.io',
  };
  String _resolverPreset(String domain) =>
      _knownResolvers.contains(domain) ? domain : 'custom';

  Widget _text(String value, ValueChanged<String> onChanged) =>
      PlainTextField(value: value, onChanged: onChanged);

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
