// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/generator.dart';

/// The page shell. Static marketing chrome is injected as raw HTML (identical to
/// the previous static site); the interactive generator is a hydrated @client
/// island. Server-prerendered for SEO.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      RawText(_header),
      RawText(_hero),
      const Generator(),
      RawText(_footer),
    ]);
  }
}

const _header = r'''
<header class="nav">
  <div class="brand">
    <span class="logo" aria-hidden="true"></span>
    <span>QSeq</span>
  </div>
  <nav>
    <a href="#generator">Generator</a>
    <a href="#support">Support</a>
    <a class="ghost" href="https://github.com/meerv-fmenard/qseq" target="_blank" rel="noopener">Source</a>
  </nav>
</header>
''';

const _hero = r'''
<section class="hero">
  <p class="kicker">Sustainable Identity on Every&nbsp;Thing</p>
  <h1>Open identity tooling for<br/><span>every physical object.</span></h1>
  <p class="lede">QSeq mints Barcodes, QR&nbsp;Codes and Data&nbsp;Matrix carriers for <b>SGTINs</b>, <b>GS1&nbsp;Digital&nbsp;Links</b>, <b>EPC&nbsp;URIs</b> and <b>NATO&nbsp;Stock&nbsp;Numbers</b> — with a print-true physical-size calculator so what you design is exactly what prints.</p>
  <div class="cta">
    <a class="btn primary" href="#generator">Open the generator</a>
    <a class="btn" href="/QSeq.dmg" download>Download for macOS</a>
    <a class="btn" href="/qseq-windows-setup.exe" download>Download for Windows</a>
  </div>
  <p class="muted small">Native macOS app (Apple silicon, signed &amp; notarized) &amp; Windows x64 · the Windows build is unsigned — click “More info → Run anyway” past SmartScreen · © 2026 Meerv Inc.</p>
</section>
''';

const _footer = r'''
<footer id="support">
  <span>QSeq · © 2026 Meerv Inc.</span>
  <a href="https://github.com/meerv-fmenard/qseq" target="_blank" rel="noopener"><strong>github.com/meerv-fmenard/qseq</strong></a>
  <a href="mailto:support@meerv.com?subject=QSeq%20support">support@meerv.com</a>
  <span>Sustainable Identity on Every Thing</span>
</footer>
''';
