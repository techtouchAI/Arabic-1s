import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Compact +/- text zoom buttons placed in reading and tool AppBars.
class TextScaleControls extends StatelessWidget {
  const TextScaleControls({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'تصغير الخط',
          visualDensity: VisualDensity.compact,
          onPressed: state.textScale <= 0.86
              ? null
              : () => state.adjustTextScale(-0.08),
          icon: const Icon(Icons.text_decrease, size: 19),
        ),
        IconButton(
          tooltip: 'تكبير الخط',
          visualDensity: VisualDensity.compact,
          onPressed: state.textScale >= 1.38
              ? null
              : () => state.adjustTextScale(0.08),
          icon: const Icon(Icons.text_increase, size: 19),
        ),
      ],
    );
  }
}
