// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/generator.dart';
import 'components/license_gate.dart';

/// Single source of truth for the displayed site version — keep in sync with
/// site/pubspec.yaml and the CHANGELOG.
const qseqVersion = '1.5.2';

/// The page shell. Static marketing chrome is injected as raw HTML (identical to
/// the previous static site); the interactive generator is a hydrated @client
/// island. Server-prerendered for SEO.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      const LicenseGate(),
      RawText(_header),
      RawText(_hero),
      const Generator(),
      RawText(_mission),
      RawText(_about),
      RawText(_support),
      RawText(_siot),
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
    <button id="themeBtn" class="themebtn" type="button" aria-label="Switch between dark and light mode" title="Dark / light mode">☀</button>
    <a href="#generator">Generator</a>
    <a href="#mission">Mission</a>
    <a href="#about">About</a>
    <a href="#support">Support</a>
    <a class="ghost" href="https://github.com/Meerv-Inc/QSeq" target="_blank" rel="noopener">Source</a>
  </nav>
</header>
''';

const _hero = r'''
<section class="hero">
  <p class="kicker">Sustainable Identity on Every&nbsp;Thing</p>
  <h1><span class="meerv">Sustainable Identity Generator</span><br/>for <span>Every Thing</span></h1>
  <p class="lede">QSeq mints Barcodes, QR&nbsp;Codes and Data&nbsp;Matrix carriers for <b>SGTINs</b>, <b>GS1&nbsp;Digital&nbsp;Links</b> and <b>EPC&nbsp;URIs</b> — with a print-true physical-size calculator so what you design is exactly what prints.</p>
  <div class="cta">
    <a class="btn primary" href="#generator">Open the generator</a>
    <a class="btn" href="/QSeq.dmg" download>Download for macOS</a>
    <a class="btn" href="/qseq-windows-setup.exe" download>Download for Windows</a>
  </div>
  <p class="muted small">Native macOS app (Apple silicon, signed &amp; notarized) &amp; Windows x64 · the Windows build is also signed and SmartScreen reputation is accruing — click “More info → Run anyway” past SmartScreen · © 2026 Meerv Inc.</p>
</section>
''';

const _mission = r'''
<section id="mission" class="mission">
  <h2>Why this is source-available</h2>
  <p>QSeq is released as source-available (PolyForm Noncommercial) to accelerate the transition to <b>Sustainable Identity on Every Thing</b> (SIoT): a future where every physical object carries an open, web-resolvable, standards-based identity — GS1 Digital Links, SGTINs and compatible carriers — that anyone can read, verify and build upon without proprietary lock-in.</p>
  <p>Durable, interoperable identity is the foundation of the circular economy. Reuse, repair, recall, provenance and end-of-life tracking all depend on a code that still resolves years after it was printed. Keeping the tools that <i>mint</i> those identities open means the infrastructure of identity stays a public good — not a toll booth.</p>
  <div class="pillars">
    <div><h3>Standards-first</h3><p>GS1 Digital Link, SGTIN, EPC Tag URI, GS1-128, Data Matrix — no bespoke formats.</p></div>
    <div><h3>Print-true</h3><p>Exact-DPI sizing with mm + inch + vernier rulers so the print matches the intent.</p></div>
    <div><h3>Yours to fork</h3><p>Raw parameters export to editable JSON. Generate designs from your own pipelines.</p></div>
  </div>
  <div class="copyrow">
    <span class="copylabel">Source code</span>
    <div class="copybox">
      <code id="repoUrl">https://github.com/Meerv-Inc/QSeq</code>
      <button type="button" class="copybtn" data-copy-target="repoUrl" aria-label="Copy repository URL" title="Copy">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
      </button>
    </div>
  </div>
</section>
''';

const _about = '''
<section id="about" class="about">
  <h2>Why “QSeq”?</h2>
  <p><b>Seq</b> is <i>sequence</i> — QSeq exists to mint ordered, serialized identities. The <b>Q</b> is chosen deliberately: every reading of it lands on exactly what a well-formed sequence of identity codes must be — ordered, robust and resolvable.</p>
  <ul class="register">
    <li><b>Q — Quality factor.</b> In physics, <i>Q</i> measures how well a resonator preserves energy against loss; a higher Q survives more disturbance. A QSeq code is engineered the same way: its error-correction budget and structure-aware dead-space are a literal quality factor for how much damage an identity can take and still resolve.</li>
    <li><b>Q — Time quanta.</b> A <i>quantum</i> is the smallest indivisible step. Serialization advances one quantum at a time — each code is the next discrete tick in the sequence, never skipped, never repeated.</li>
    <li><b>Q — Queue.</b> A <i>queue</i> is an ordered set processed in order. A serialized sheet <em>is</em> a queue of identities, minted and consumed first-to-last.</li>
    <li><b>Q — Cue.</b> A <i>cue</i> is the signal that triggers the next action. Every scannable code is a cue: scan it, it resolves, and the next supply-chain step fires.</li>
    <li><b>Q — QR.</b> And of course the canonical 2D carrier itself begins with Q.</li>
  </ul>
  <p>Quality factor, quanta, queue, cue, QR — four meanings and a carrier, each independently true, all pointing to the same idea: <b>a quality-assured, ordered, resolvable sequence of identity codes.</b> That is QSeq.</p>
  <h2 style="margin-top:48px">Why Flutter &amp; Dart?</h2>
  <p>QSeq is written in <b>Flutter / Dart</b> so a <b>single codebase</b> serves every surface. The <b>macOS and Windows</b> desktop apps are built from it, and the same Dart core powers this website: the web generator now runs the <i>exact</i> encoders and sizing engine as the desktop, compiled to the browser. One implementation of the encoders, capacity tables and sizing math means an identity minted on macOS, Windows or the browser is byte-for-byte the same.</p>
  <p class="muted">QSeq v$qseqVersion · © 2026 Meerv Inc. · Licensed under the PolyForm Noncommercial License 1.0.0 — released as source-available in service of Sustainable Identity on Every Thing.</p>
</section>
''';

const _support = r'''
<section id="support" class="support">
  <h2>Support</h2>
  <p>Questions, bug reports or feature requests? We read every message — QSeq is built in the open and we want it to work for you.</p>
  <p>Email <a class="mail" href="mailto:support@meerv.com?subject=QSeq%20support">support@meerv.com</a> and we'll get back to you. Telling us your <b>QSeq version</b> and your <b>platform</b> — macOS, Windows or web — helps us help you faster.</p>
  <div class="cta">
    <a class="btn primary" href="mailto:support@meerv.com?subject=QSeq%20support">Email support@meerv.com</a>
    <a class="btn" href="https://github.com/Meerv-Inc/QSeq/issues" target="_blank" rel="noopener">Open a GitHub issue →</a>
  </div>
</section>
''';

const _siot = r'''
<section id="siot" class="about">
  <h2>What “Sustainable Identity” requires</h2>
  <p>The phrase is a double condition, and both halves must hold — implicitly, anything that fails either one is outside it.</p>
  <ul class="register">
    <li><b>It must be an Identity.</b> A Stock Keeping Unit (SKU) — or any bare, class-level GTIN — names a <i>kind</i> of thing, not a thing. Unserialized, it is shared by every unit in the batch and can never resolve to the record of <i>this</i> one; it is ultimately not resolvable to a Digital Product Passport. So an SKU is <b>not an Identity</b>. Identity begins at serialization: an SGTIN carried in a web-resolvable GS1 Digital Link, where each physical item resolves to its own passport.</li>
    <li><b>It must be Sustainable.</b> An identity printed in a way that is not sustainable is <b>not sustainable either</b>. A code printed at the wrong physical size, with its error-correction budget spent on a logo, or with no margin left for the scuffs, fading and curvature of real life stops scanning — and an identity that stops resolving takes reuse, repair, recall and end-of-life tracking with it. Print-true sizing and a protected error-correction margin are what let the identity survive as long as the thing it marks.</li>
  </ul>
  <p>An SKU alone fails the first condition; a fragile print fails the second. <b>Sustainable Identity on Every Thing means meeting both</b> — and QSeq exists so every code it mints does.</p>
</section>
''';

const _footer = '''
<footer>
  <span>QSeq.app Version $qseqVersion © 2026 Meerv Inc.</span>
  <a href="https://github.com/Meerv-Inc/QSeq" target="_blank" rel="noopener"><strong>github.com/Meerv-Inc/QSeq</strong></a>
  <span>Sustainable Identity on Every Thing</span>
</footer>
''';
