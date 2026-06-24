// Foundation showcases for the bull_ui design system — Colours, Radius,
// Spacing and TextStyles. These render the design *tokens* (not components),
// so the catalogue documents the foundation the same way the design's
// `DesignSystem{Color,Radius,Spacing,TextStyles}` screens do. Grouped under a
// `Foundation/` node via `@UseCase(path:)`.

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' as m;
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ---------------------------------------------------------------------------
// Colours — the BullTheme palette (mirrors AppColors), light/dark via the addon
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Colours', type: FoundationColours, path: 'Foundation')
m.Widget foundationColoursUseCase(m.BuildContext context) =>
    const FoundationColours();

class FoundationColours extends m.StatelessWidget {
  const FoundationColours({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    final b = context.bull;
    final t = m.Theme.of(context).textTheme;
    final swatches = <(String, m.Color)>[
      ('primary', b.primary),
      ('onPrimary', b.onPrimary),
      ('secondary', b.secondary),
      ('onSecondary', b.onSecondary),
      ('tertiary', b.tertiary),
      ('onTertiary', b.onTertiary),
      ('tertiaryContainer', b.tertiaryContainer),
      ('bitcoinOrange', b.bitcoinOrange),
      ('background', b.background),
      ('surface', b.surface),
      ('surfaceContainer', b.surfaceContainer),
      ('surfaceContainerHighest', b.surfaceContainerHighest),
      ('surfaceBright', b.surfaceBright),
      ('cardBackground', b.cardBackground),
      ('inverseSurface', b.inverseSurface),
      ('text', b.text),
      ('textMuted', b.textMuted),
      ('onSurface', b.onSurface),
      ('onSurfaceVariant', b.onSurfaceVariant),
      ('border', b.border),
      ('outline', b.outline),
      ('outlineVariant', b.outlineVariant),
      ('error', b.error),
      ('onError', b.onError),
      ('errorContainer', b.errorContainer),
      ('success', b.success),
      ('warning', b.warning),
      ('warningContainer', b.warningContainer),
      ('info', b.info),
      ('scrim', b.scrim),
      ('overlay', b.overlay),
      ('shimmerBase', b.shimmerBase),
      ('shimmerHighlight', b.shimmerHighlight),
    ];
    return m.ColoredBox(
      color: b.surface,
      child: m.ListView(
        padding: const m.EdgeInsets.all(BullSpacing.md),
        children: [
          for (final (name, color) in swatches)
            m.Padding(
              padding: const m.EdgeInsets.only(bottom: BullSpacing.xs),
              child: m.Row(
                children: [
                  m.Container(
                    width: 44,
                    height: 44,
                    decoration: m.BoxDecoration(
                      color: color,
                      borderRadius: m.BorderRadius.circular(BullRadius.sm),
                      border: m.Border.all(color: b.outlineVariant),
                    ),
                  ),
                  const m.SizedBox(width: BullSpacing.sm),
                  m.Expanded(child: m.Text(name, style: t.bodyMedium)),
                  m.Text(
                    _hex(color),
                    style: t.labelSmall?.copyWith(color: b.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hex(m.Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

// ---------------------------------------------------------------------------
// Radius — BullRadius scale
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Radius', type: FoundationRadius, path: 'Foundation')
m.Widget foundationRadiusUseCase(m.BuildContext context) =>
    const FoundationRadius();

class FoundationRadius extends m.StatelessWidget {
  const FoundationRadius({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    final b = context.bull;
    final t = m.Theme.of(context).textTheme;
    const steps = <(String, double)>[
      ('zero', BullRadius.zero),
      ('xs', BullRadius.xs),
      ('sm', BullRadius.sm),
      ('md', BullRadius.md),
      ('lg', BullRadius.lg),
      ('xl', BullRadius.xl),
      ('xxl', BullRadius.xxl),
      ('full', BullRadius.full),
    ];
    return m.ColoredBox(
      color: b.surface,
      child: m.SingleChildScrollView(
        padding: const m.EdgeInsets.all(BullSpacing.md),
        child: m.Wrap(
          spacing: BullSpacing.md,
          runSpacing: BullSpacing.md,
          children: [
            for (final (name, r) in steps)
              m.Column(
                mainAxisSize: m.MainAxisSize.min,
                children: [
                  m.Container(
                    width: 72,
                    height: 72,
                    decoration: m.BoxDecoration(
                      color: b.surfaceContainerHighest,
                      borderRadius: m.BorderRadius.circular(r),
                      border: m.Border.all(color: b.outline),
                    ),
                  ),
                  const m.SizedBox(height: BullSpacing.xs),
                  m.Text(name, style: t.labelMedium),
                  m.Text(
                    '${r.toInt()}px',
                    style: t.labelSmall?.copyWith(color: b.textMuted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spacing — BullSpacing scale
// ---------------------------------------------------------------------------

@widgetbook.UseCase(name: 'Spacing', type: FoundationSpacing, path: 'Foundation')
m.Widget foundationSpacingUseCase(m.BuildContext context) =>
    const FoundationSpacing();

class FoundationSpacing extends m.StatelessWidget {
  const FoundationSpacing({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    final b = context.bull;
    final t = m.Theme.of(context).textTheme;
    const steps = <(String, double)>[
      ('zero', BullSpacing.zero),
      ('xxs', BullSpacing.xxs),
      ('xs', BullSpacing.xs),
      ('sm', BullSpacing.sm),
      ('md', BullSpacing.md),
      ('lg', BullSpacing.lg),
      ('xl', BullSpacing.xl),
      ('xxl', BullSpacing.xxl),
      ('xxxl', BullSpacing.xxxl),
    ];
    return m.ColoredBox(
      color: b.surface,
      child: m.ListView(
        padding: const m.EdgeInsets.all(BullSpacing.md),
        children: [
          for (final (name, s) in steps)
            m.Padding(
              padding: const m.EdgeInsets.only(bottom: BullSpacing.sm),
              child: m.Row(
                children: [
                  m.SizedBox(width: 56, child: m.Text(name, style: t.labelMedium)),
                  m.Container(width: s == 0 ? 1 : s, height: 16, color: b.primary),
                  const m.SizedBox(width: BullSpacing.sm),
                  m.Text(
                    '${s.toInt()}px',
                    style: t.labelSmall?.copyWith(color: b.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TextStyles — the Material TextTheme roles (sourced from AppFonts)
// ---------------------------------------------------------------------------

@widgetbook.UseCase(
  name: 'TextStyles',
  type: FoundationTextStyles,
  path: 'Foundation',
)
m.Widget foundationTextStylesUseCase(m.BuildContext context) =>
    const FoundationTextStyles();

class FoundationTextStyles extends m.StatelessWidget {
  const FoundationTextStyles({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    final b = context.bull;
    final t = m.Theme.of(context).textTheme;
    final styles = <(String, m.TextStyle?)>[
      ('displayLarge', t.displayLarge),
      ('displayMedium', t.displayMedium),
      ('displaySmall', t.displaySmall),
      ('headlineLarge', t.headlineLarge),
      ('headlineMedium', t.headlineMedium),
      ('headlineSmall', t.headlineSmall),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('bodySmall', t.bodySmall),
      ('labelLarge', t.labelLarge),
      ('labelMedium', t.labelMedium),
      ('labelSmall', t.labelSmall),
    ];
    return m.ColoredBox(
      color: b.surface,
      child: m.ListView(
        padding: const m.EdgeInsets.all(BullSpacing.md),
        children: [
          for (final (name, style) in styles)
            if (style != null)
              m.Padding(
                padding: const m.EdgeInsets.only(bottom: BullSpacing.md),
                child: m.Column(
                  crossAxisAlignment: m.CrossAxisAlignment.start,
                  children: [
                    m.Text(
                      name.toUpperCase(),
                      style: t.labelSmall?.copyWith(color: b.textMuted),
                    ),
                    m.Text(
                      'The quick brown fox',
                      style: style.copyWith(color: b.text),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
