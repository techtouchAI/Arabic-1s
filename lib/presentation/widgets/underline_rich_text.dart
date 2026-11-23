import 'package:flutter/material.dart';

import '../../core/utils/arabic_text.dart';

/// Renders Arabic exam strings containing `_underlined_` phrases using real
/// single underlines matching the exported `.docx` output.
class UnderlineRichText extends StatelessWidget {
  const UnderlineRichText(
    this.source, {
    super.key,
    this.style,
    this.underlineColor,
    this.textAlign = TextAlign.start,
  });

  final String source;
  final TextStyle? style;
  final Color? underlineColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    final segments = parseUnderlinedSegments(source);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          for (final seg in segments)
            TextSpan(
              text: seg.text,
              style: seg.underlined
                  ? baseStyle.copyWith(
                      decoration: TextDecoration.underline,
                      decorationThickness: 2.0,
                      decorationColor: underlineColor ?? baseStyle.color,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
