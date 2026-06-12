// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// The license consent gate: on first visit — and again every 30 days — the
// user must read and agree to the PolyForm Noncommercial 1.0.0 terms granted
// by Meerv Inc. before using the generator. Renders nothing on the server and
// nothing once consent is current (stored in localStorage).
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as uw;

const _licenseUrl = 'https://polyformproject.org/licenses/noncommercial/1.0.0';
const _storageKey = 'qseq-license-accepted';

@client
class LicenseGate extends StatefulComponent {
  const LicenseGate({super.key});

  @override
  State<LicenseGate> createState() => LicenseGateState();
}

class LicenseGateState extends State<LicenseGate> {
  bool show = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return; // server prerender: render nothing
    try {
      final at = DateTime.tryParse(
          uw.window.localStorage.getItem(_storageKey) ?? '');
      // Re-confirm every 30 days.
      show = at == null || DateTime.now().difference(at).inDays >= 30;
    } catch (_) {
      show = true;
    }
  }

  void _agree() {
    try {
      uw.window.localStorage
          .setItem(_storageKey, DateTime.now().toIso8601String());
    } catch (_) {}
    setState(() => show = false);
  }

  @override
  Component build(BuildContext context) {
    if (!show) return Component.fragment(const []);
    return div(classes: 'licgate', [
      div(classes: 'licbox', [
        h2([text('License agreement')]),
        p([
          text('QSeq is source-available under the '),
          b([text('PolyForm Noncommercial License 1.0.0')]),
          text(', © 2026 Meerv Inc. Please read and agree before using it:'),
        ]),
        ul([
          li([
            b([text('What you are granted.')]),
            text(' A non-exclusive, worldwide, royalty-free license to use, '
                'copy, modify and distribute QSeq — for noncommercial '
                'purposes only.'),
          ]),
          li([
            b([text('Noncommercial means.')]),
            text(' Personal use, and use by charitable organizations, '
                'educational institutions, public research, public safety or '
                'health organizations, environmental protection organizations '
                'and government institutions.'),
          ]),
          li([
            b([text('Required notice.')]),
            text(' Copies you distribute must keep: “Required Notice: '
                'Copyright Meerv Inc. (https://qseq.app)”.'),
          ]),
          li([
            b([text('Commercial use')]),
            text(' requires a separate license from Meerv Inc. — '
                'support@meerv.com.'),
          ]),
          li([
            b([text('No warranty.')]),
            text(' Provided as-is; the license ends if its terms are '
                'violated.'),
          ]),
        ]),
        p([
          text('Full text: '),
          a(href: _licenseUrl, target: Target.blank, [text(_licenseUrl)]),
        ]),
        div(classes: 'licactions', [
          button([text('I have read the terms and agree')],
              classes: 'btn primary', onClick: _agree),
        ]),
        p(classes: 'muted small', [
          text('You will be asked to re-confirm every 30 days.')
        ]),
      ]),
    ]);
  }
}
