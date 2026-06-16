import 'package:flutter/material.dart';

/// The `bull_ui` colour palette, injected by the app as a [ThemeExtension].
///
/// `bull_ui` is brightness-agnostic: it never hardcodes a colour. The app
/// builds one [BullTheme] from its light palette and another from its dark
/// palette, and registers each on the matching [ThemeData] via `extensions:`.
/// Components read colours through [BullThemeX.bull] (e.g. `context.bull.red`);
/// derived fills use `tokenColor.withValues(alpha: …)` so they adapt to both
/// brightnesses automatically. This declares only the **shape** — no values.
@immutable
class BullTheme extends ThemeExtension<BullTheme> {
  const BullTheme({
    required this.red,
    required this.onRed,
    required this.surface,
    required this.card,
    required this.text,
    required this.muted,
    required this.info,
    required this.success,
    required this.warning,
    required this.btc,
    required this.outlineVariant,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryFixedDim,
    required this.border,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.scrim,
  });

  /// Brand red — accents and the selected state.
  final Color red;

  /// Foreground colour used on top of [red] fills.
  final Color onRed;

  /// Screen / bar background.
  final Color surface;

  /// Card / tile background.
  final Color card;

  /// Primary text colour.
  final Color text;

  /// Muted text — subtitles, addresses, secondary badges.
  final Color muted;

  /// Info accent — the frozen state (left border, snowflake, Frozen pill).
  final Color info;

  /// Success accent — the confirmed check.
  final Color success;

  /// Warning accent — the Pending pill.
  final Color warning;

  /// Bitcoin orange — the Receive keychain badge.
  final Color btc;

  /// Hairline divider colour between rows.
  final Color outlineVariant;

  /// Shimmer skeleton base colour.
  final Color shimmerBase;

  /// Shimmer skeleton highlight colour.
  final Color shimmerHighlight;

  /// High-contrast secondary fill (inverse of [surface]) — dial-pad glyphs,
  /// direction-badge icon.
  final Color secondary;

  /// Foreground on [secondary] fills; also the elevated tile / badge surface
  /// (cards that sit above [surface]).
  final Color onSecondary;

  /// Dimmed secondary — hairline borders on bordered tiles.
  final Color secondaryFixedDim;

  /// Default border / outline colour for inputs, cards and dropdowns.
  final Color border;

  /// Foreground for content on [surface] (input text, icons, list titles).
  final Color onSurface;

  /// Secondary foreground on [surface] — descriptions, captions.
  final Color onSurfaceVariant;

  /// Scrim colour for shadows behind floating elements.
  final Color scrim;

  @override
  BullTheme copyWith({
    Color? red,
    Color? onRed,
    Color? surface,
    Color? card,
    Color? text,
    Color? muted,
    Color? info,
    Color? success,
    Color? warning,
    Color? btc,
    Color? outlineVariant,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryFixedDim,
    Color? border,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? scrim,
  }) {
    return BullTheme(
      red: red ?? this.red,
      onRed: onRed ?? this.onRed,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      info: info ?? this.info,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      btc: btc ?? this.btc,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryFixedDim: secondaryFixedDim ?? this.secondaryFixedDim,
      border: border ?? this.border,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  BullTheme lerp(covariant BullTheme? other, double t) {
    if (other == null) return this;
    return BullTheme(
      red: Color.lerp(red, other.red, t)!,
      onRed: Color.lerp(onRed, other.onRed, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      btc: Color.lerp(btc, other.btc, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryFixedDim: Color.lerp(
        secondaryFixedDim,
        other.secondaryFixedDim,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Accessor for the injected [BullTheme] off any [BuildContext].
extension BullThemeX on BuildContext {
  /// The active [BullTheme]. Throws if the app did not register one — every
  /// `bull_ui` consumer must wrap its tree in a [Theme] carrying a [BullTheme]
  /// extension (the app does this in its `ThemeData`).
  BullTheme get bull => Theme.of(this).extension<BullTheme>()!;
}
