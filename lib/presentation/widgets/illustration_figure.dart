import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';

class IllustrationFigure extends StatelessWidget {
  const IllustrationFigure({
    super.key,
    required this.figure,
    required this.accent,
    this.height = 220,
  });

  final Figure figure;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: scheme.brightness == Brightness.light
              ? const Color(0xFFFBF6EC)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showIllustrationDialog(
              context,
              asset: figure.asset,
              caption: figure.caption,
              legend: figure.legend,
            ),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: SvgPicture.asset(
                figure.asset,
                bundle: DefaultAssetBundle.of(context),
                fit: BoxFit.contain,
                semanticsLabel: figure.caption,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.account_tree_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                figure.caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تكبير المخطط',
              visualDensity: VisualDensity.compact,
              onPressed: () => showIllustrationDialog(
                context,
                asset: figure.asset,
                caption: figure.caption,
                legend: figure.legend,
              ),
              icon: Icon(Icons.zoom_out_map, size: 18, color: accent),
            ),
          ],
        ),
        if (figure.legend.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: figure.legend
                .map((item) => _LegendChip(legend: item))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.legend});

  final FigureLegend legend;

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(legend.color) ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              legend.label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showIllustrationDialog(
  BuildContext context, {
  required String asset,
  required String caption,
  required List<FigureLegend> legend,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (BuildContext context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog(
        backgroundColor: scheme.surface,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940, maxHeight: 740),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        caption,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: SvgPicture.asset(
                        asset,
                        bundle: DefaultAssetBundle.of(context),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                if (legend.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: legend
                          .map((item) => _LegendChip(legend: item))
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Color? _parseHex(String value) {
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
