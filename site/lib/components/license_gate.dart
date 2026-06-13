// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

// The license consent gate. The generator stays hidden (CSS:
// `body:not(.qseq-unlocked) .generator`) until the visitor clicks "Open QSeq".
// On that click — if consent is missing or older than 30 days — the PolyForm
// Noncommercial 1.0.0 terms are shown and must be accepted before the app is
// revealed. Acceptance is stored in localStorage. Renders nothing on the server.
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../qseq/gate_dom.dart';

const _licenseUrl = 'https://polyformproject.org/licenses/noncommercial/1.0.0';

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
    if (!kIsWeb) return; // server prerender: render nothing, wire nothing
    wireOpenButtons(_requestOpen);
  }

  void _requestOpen() {
    if (gateAccepted()) {
      revealGenerator();
    } else {
      setState(() => show = true);
    }
  }

  void _agree() {
    gateStoreAccepted();
    setState(() => show = false);
    revealGenerator();
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
