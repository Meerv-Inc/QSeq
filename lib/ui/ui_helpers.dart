// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// A checked/unchecked box with an explicit, always-visible checkmark —
/// unlike the stock [MacosCheckbox], whose checked-state colour depends on
/// `macos_ui`'s internal window-focus tracking and can render a white
/// checkmark on a near-white background in light mode when that state is
/// unreliable (e.g. a Flutter desktop window that doesn't consistently
/// report itself as the OS "key"/main window). This sidesteps that by never
/// depending on window-focus state at all: checked is solid accent blue
/// with a white check, unchecked is a plain outline, in both themes.
class PlainCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const PlainCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? MacosColors.systemBlueColor : null,
          border: value
              ? null
              : Border.all(color: MacosColors.systemGrayColor, width: 1),
          borderRadius: BorderRadius.circular(3.5),
        ),
        child: value
            ? Icon(
                CupertinoIcons.checkmark,
                size: size - 3,
                color: MacosColors.white,
              )
            : null,
      ),
    );
  }
}

/// A label above a field, the standard macOS inspector layout.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const LabeledField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label,
              style: MacosTheme.of(context).typography.caption1,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A numeric text field that reports parsed doubles back through [onChanged].
class NumberField extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  const NumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.suffix,
  });

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _c = TextEditingController(
    text: _fmt(widget.value),
  );

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void didUpdateWidget(covariant NumberField old) {
    super.didUpdateWidget(old);
    final parsed = double.tryParse(_c.text);
    if (parsed != widget.value) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosTextField(
      controller: _c,
      suffix: widget.suffix == null ? null : Text(widget.suffix!),
      onChanged: (t) {
        final v = double.tryParse(t.trim());
        if (v != null) widget.onChanged(v);
      },
    );
  }
}

/// A text field that owns its controller and only resets from outside when the
/// incoming [value] genuinely differs (so typing doesn't reset the cursor).
class PlainTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PlainTextField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PlainTextField> createState() => _PlainTextFieldState();
}

class _PlainTextFieldState extends State<PlainTextField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant PlainTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosTextField(controller: _c, onChanged: widget.onChanged);
  }
}

/// A small titled card used to group inspector controls.
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: theme.typography.headline.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
