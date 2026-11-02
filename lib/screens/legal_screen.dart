import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// The app's legal documents. The same Markdown is published on the website
/// as privacy.html / terms.html (see tool/build_legal.py).
enum LegalDoc {
  privacy('Privacy Policy', 'assets/legal/privacy.md', 'privacy.html'),
  terms('Terms of Service', 'assets/legal/terms.md', 'terms.html');

  const LegalDoc(this.title, this.asset, this.webPath);
  final String title;
  final String asset;
  final String webPath;

  static LegalDoc? fromLink(String href) {
    for (final d in values) {
      if (href.endsWith(d.webPath)) return d;
    }
    return null;
  }
}

void openLegal(BuildContext context, LegalDoc doc) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(doc: doc)));
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      appBar: AppBar(
        backgroundColor: Palette.bg0,
        foregroundColor: Palette.textHi,
        elevation: 0,
        title: Text(
          doc.title,
          style: const TextStyle(fontFamily: AppType.sans, fontSize: 16),
        ),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.asset),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox.shrink();
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 48),
                children: MarkdownBlocks.build(context, snap.data!),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Renders the small Markdown subset the legal documents use: `#`/`##`
/// headings, paragraphs, `- ` bullets, `**bold**`, `*italic*` and
/// `[links](url)`.
class MarkdownBlocks {
  static List<Widget> build(BuildContext context, String md) {
    final out = <Widget>[];
    final para = <String>[];

    void flush() {
      if (para.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text.rich(
            TextSpan(children: _inline(context, para.join(' '))),
            style: _body,
          ),
        ),
      );
      para.clear();
    }

    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('# ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              line.substring(2),
              style: AppType.display.copyWith(fontSize: 34),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                fontFamily: AppType.serif,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Palette.textHi,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: _body),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _inline(context, line.substring(2))),
                    style: _body,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        para.add(line);
      }
    }
    flush();
    return out;
  }

  static final _body = TextStyle(
    fontFamily: AppType.sans,
    fontSize: 15.5,
    height: 1.6,
    color: Palette.textMid,
  );

  static final _token = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|\[(.+?)\]\((.+?)\)');

  static List<InlineSpan> _inline(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Palette.textHi,
            ),
          ),
        );
      } else if (m.group(2) != null) {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        final href = m.group(4)!;
        spans.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(
              color: Palette.textHi,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final doc = LegalDoc.fromLink(href);
                if (doc != null) {
                  openLegal(context, doc);
                } else {
                  launchUrl(
                    Uri.parse(href),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
          ),
        );
      }
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return spans;
  }
}
