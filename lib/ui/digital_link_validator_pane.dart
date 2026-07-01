// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../encoders/digital_link.dart';
import '../encoders/gtin.dart';
import '../encoders/sgtin.dart';

/// A dark, monospace "log window" listing every step [DigitalLink.parse]
/// performed and its outcome — shared by the single-link and bulk validator
/// sheets so both can show *why* a link parsed and passed (or failed).
Widget logWindow(List<String> trace, {double? height}) {
  return Container(
    height: height,
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1D1F),
      borderRadius: BorderRadius.circular(6),
    ),
    child: height == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final line in trace) _logLine(line)],
          )
        : CupertinoScrollbar(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final line in trace) _logLine(line)],
              ),
            ),
          ),
  );
}

Widget _logLine(String line) {
  final color = line.startsWith('✗')
      ? MacosColors.systemRedColor
      : line.startsWith('⚠')
      ? MacosColors.systemOrangeColor
      : line.startsWith('✓')
      ? const Color(0xFF7CF6C8)
      : MacosColors.systemGrayColor;
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text(
      line,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        height: 1.4,
        color: color,
      ),
    ),
  );
}

/// The GS1 Digital Link Validator sheet (toolbar "Validate" button): paste a
/// Digital Link URI and see it decoded into its GS1 Application Identifier
/// components, with any structural or format problems listed.
Future<void> showDigitalLinkValidatorSheet(BuildContext context) async {
  await showMacosSheet(
    context: context,
    builder: (context) => const MacosSheet(child: _ValidatorSheetBody()),
  );
}

class _ValidatorSheetBody extends StatefulWidget {
  const _ValidatorSheetBody();

  @override
  State<_ValidatorSheetBody> createState() => _ValidatorSheetBodyState();
}

class _ValidatorSheetBodyState extends State<_ValidatorSheetBody> {
  static final String _example = Sgtin(
    gtin: Gtin.example(14),
    serial: '12345',
  ).toDigitalLink();

  late final TextEditingController _controller = TextEditingController(
    text: _example,
  );
  DigitalLinkResult? _result;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() => _result = DigitalLink.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = MacosTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MacosIcon(CupertinoIcons.checkmark_shield, size: 26),
              const SizedBox(width: 10),
              Text(
                'Digital Link Validator',
                style: t.largeTitle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a GS1 Digital Link URI to decode its Application '
            'Identifiers and check it for structural or format problems.',
            style: t.caption1.copyWith(color: MacosColors.systemGrayColor),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MacosTextField(
                  controller: _controller,
                  placeholder: _example,
                  onSubmitted: (_) => _validate(),
                ),
              ),
              const SizedBox(width: 10),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _validate,
                child: const Text('Validate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: _result == null
                  ? const SizedBox()
                  : _resultBody(context, _result!),
            ),
          ),
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
    );
  }

  Widget _resultBody(BuildContext context, DigitalLinkResult r) {
    final t = MacosTheme.of(context).typography;
    final errors = r.issues
        .where((i) => i.severity == DigitalLinkSeverity.error)
        .length;
    final warnings = r.issues
        .where((i) => i.severity == DigitalLinkSeverity.warning)
        .length;
    final summaryColor = errors > 0
        ? MacosColors.systemRedColor
        : warnings > 0
        ? MacosColors.systemOrangeColor
        : MacosColors.systemGreenColor;
    final summaryText = errors > 0
        ? '$errors error${errors == 1 ? '' : 's'}'
              '${warnings > 0 ? ', $warnings warning${warnings == 1 ? '' : 's'}' : ''}'
        : warnings > 0
        ? 'Valid — $warnings warning${warnings == 1 ? '' : 's'}'
        : 'Valid';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        errors > 0
            ? Row(
                children: [
                  MacosIcon(
                    CupertinoIcons.xmark_circle_fill,
                    color: summaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    summaryText,
                    style: t.headline.copyWith(
                      fontWeight: FontWeight.w600,
                      color: summaryColor,
                    ),
                  ),
                ],
              )
            : _validPill(context, t, summaryText),
        const SizedBox(height: 12),
        if (r.pathStem.isNotEmpty) _plainRow(t, 'Path stem', r.pathStem),
        if (r.identifier != null) _aiRow(t, r.identifier!, label: 'Identifier'),
        for (final q in r.qualifiers) _aiRow(t, q, label: 'Qualifier'),
        for (final a in r.attributes.values) _aiRow(t, a, label: 'Attribute'),
        for (final e in r.other.entries)
          _plainRow(t, 'Other param', '${e.key} = ${e.value}'),
        if (r.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Issues',
            style: t.headline.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final issue in r.issues) _issueRow(t, issue),
        ],
        const SizedBox(height: 12),
        Text(
          'Validation Log',
          style: t.headline.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        logWindow(r.trace),
      ],
    );
  }

  /// The "Valid" summary badge: a solid pill, filled with the app's accent
  /// blue in light mode and solid white in dark mode (rather than the plain
  /// icon+text row used for the error/failure state).
  Widget _validPill(BuildContext context, MacosTypography t, String text) {
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final pillColor = isDark ? MacosColors.white : MacosColors.systemBlueColor;
    final contentColor = isDark ? MacosColors.black : MacosColors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MacosIcon(
            CupertinoIcons.checkmark_circle_fill,
            color: contentColor,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.headline.copyWith(
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiRow(MacosTypography t, Gs1AiValue v, {required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label (${v.ai})  ${v.title}:  ',
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: v.value, style: t.body),
          ],
        ),
      ),
    );
  }

  Widget _plainRow(MacosTypography t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label:  ',
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value, style: t.body),
          ],
        ),
      ),
    );
  }

  Widget _issueRow(MacosTypography t, DigitalLinkIssue issue) {
    final isError = issue.severity == DigitalLinkSeverity.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MacosIcon(
            isError
                ? CupertinoIcons.exclamationmark_triangle_fill
                : CupertinoIcons.info_circle_fill,
            color: isError
                ? MacosColors.systemRedColor
                : MacosColors.systemOrangeColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(issue.message, style: t.body)),
        ],
      ),
    );
  }
}

/// The bulk validator sheet (Serialization Log "Validate all" button): runs
/// [DigitalLink.parse] over every entry already generated in the current
/// workspace and lists a pass/fail line per code.
Future<void> showDigitalLinkBulkValidatorSheet(
  BuildContext context,
  List<String> entries,
) async {
  final results = entries.map(DigitalLink.parse).toList();
  await showMacosSheet(
    context: context,
    builder: (context) => MacosSheet(
      child: _BulkValidatorSheetBody(entries: entries, results: results),
    ),
  );
}

class _BulkValidatorSheetBody extends StatefulWidget {
  final List<String> entries;
  final List<DigitalLinkResult> results;

  const _BulkValidatorSheetBody({required this.entries, required this.results});

  @override
  State<_BulkValidatorSheetBody> createState() =>
      _BulkValidatorSheetBodyState();
}

class _BulkValidatorSheetBodyState extends State<_BulkValidatorSheetBody> {
  // Rows are collapsed by default (a run can carry hundreds of codes); tap a
  // row's status mark to reveal the full validation-log trace for that link.
  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final t = MacosTheme.of(context).typography;
    final results = widget.results;
    final entries = widget.entries;
    final validCount = results.where((r) => r.isValid).length;
    final invalidCount = results.length - validCount;
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final okColor = isDark ? MacosColors.white : MacosColors.systemBlueColor;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MacosIcon(CupertinoIcons.checkmark_shield, size: 26),
              const SizedBox(width: 10),
              Text(
                'Validate All — Serialization Log',
                style: t.largeTitle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${results.length} code${results.length == 1 ? '' : 's'} checked · '
            '$validCount valid'
            '${invalidCount > 0 ? ', $invalidCount invalid' : ''}'
            ' · tap a row to see why it parsed and passed',
            style: t.caption1.copyWith(color: MacosColors.systemGrayColor),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) =>
                  _row(t, i, entries[i], results[i], okColor),
            ),
          ),
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
    );
  }

  Widget _row(
    MacosTypography t,
    int i,
    String entry,
    DigitalLinkResult r,
    Color okColor,
  ) {
    final errors = r.issues
        .where((x) => x.severity == DigitalLinkSeverity.error)
        .length;
    final num = (i + 1).toString().padLeft(
      widget.results.length.toString().length,
    );
    final isOpen = _expanded.contains(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(
                () => isOpen ? _expanded.remove(i) : _expanded.add(i),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$num.',
                      style: t.caption1.copyWith(
                        fontFamily: 'monospace',
                        color: MacosColors.systemGrayColor,
                      ),
                    ),
                  ),
                  MacosIcon(
                    errors > 0
                        ? CupertinoIcons.xmark_circle_fill
                        : CupertinoIcons.checkmark_circle_fill,
                    color: errors > 0 ? MacosColors.systemRedColor : okColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry,
                          style: t.caption1.copyWith(fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (errors > 0)
                          Text(
                            r.issues
                                .where(
                                  (x) =>
                                      x.severity == DigitalLinkSeverity.error,
                                )
                                .map((x) => x.message)
                                .join('; '),
                            style: t.caption2.copyWith(
                              color: MacosColors.systemRedColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  MacosIcon(
                    isOpen
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 12,
                    color: MacosColors.systemGrayColor,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
              child: logWindow(r.trace),
            ),
        ],
      ),
    );
  }
}
