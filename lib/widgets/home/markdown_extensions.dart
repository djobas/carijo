import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

// --- Markdown Extensions for Tech Editor ---

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'\$([^\$]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1);
    if (content != null) {
      parser.addNode(md.Element.text('latex', content));
    }
    return true;
  }
}

class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$(.*)\$\$$', multiLine: true);

  LatexBlockSyntax() : super();

  @override
  md.Node parse(md.BlockParser parser) {
    if (parser.isDone) return md.Text("");
    final line = parser.current.content;
    final match = pattern.firstMatch(line);
    final content = match != null ? (match.group(1) ?? "") : "";
    parser.advance();
    return md.Element.text('latex-block', content);
  }
}

class MathBuilder extends MarkdownElementBuilder {
  final bool isBlock;
  MathBuilder({this.isBlock = false});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isBlock ? 16 : 0),
      child: Math.tex(
        text,
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
        textStyle: preferredStyle?.copyWith(fontSize: isBlock ? 18 : null),
        onErrorFallback: (err) => Text(text, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
