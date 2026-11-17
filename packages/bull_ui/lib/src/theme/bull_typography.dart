import 'package:material_ui/material_ui.dart';

/// A text role of the [BullTypography] scale.
enum BullTextRole { display, headline, title, subtitle, body, label, caption }

/// The `bull_ui` type scale, one [TextStyle] per role, injected by the app as a [ThemeExtension] next to [BullTheme].
///
/// Components read a role through [BullTypographyX.bullType] (e.g. `context.bullType.body`) or `BullText(role: …)`. [standard] holds Bull's values.
///
/// Sizes are logical px, never pre-multiplied: [Text] applies the system text scaler. A caller may `copyWith` a role's `fontWeight` or `color`, never its `fontSize`.
@immutable
class BullTypography extends ThemeExtension<BullTypography> {
  /// Large figures, such as a balance.
  final TextStyle display;

  /// Screen headings.
  final TextStyle headline;

  /// Section and dialog titles.
  final TextStyle title;

  /// Card and list headings.
  final TextStyle subtitle;

  /// Running text and entered values.
  final TextStyle body;

  /// Buttons, tabs and field labels.
  final TextStyle label;

  /// Hints, tags and fine print; the smallest size in the scale.
  final TextStyle caption;

  const BullTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.label,
    required this.caption,
  });

  /// The family of every role, declared by the app's `pubspec.yaml`.
  static const fontFamily = 'Golos Text';

  /// Bull's type scale: size and line height in logical px, in Golos Text, which ships only the 400, 500 and 700 weights.
  static const standard = BullTypography(
    display: TextStyle(
      fontFamily: fontFamily,
      fontSize: 45,
      height: 52 / 45,
      fontWeight: FontWeight.w500,
    ),
    headline: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w500,
    ),
    title: TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w500,
    ),
    subtitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w500,
    ),
    body: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
    ),
    label: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
    ),
    caption: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
    ),
  );

  /// The style of [role].
  TextStyle of(BullTextRole role) => switch (role) {
    BullTextRole.display => display,
    BullTextRole.headline => headline,
    BullTextRole.title => title,
    BullTextRole.subtitle => subtitle,
    BullTextRole.body => body,
    BullTextRole.label => label,
    BullTextRole.caption => caption,
  };

  /// Projects the roles onto Material's [TextTheme] slots, so widgets that read `Theme.of(context).textTheme` follow the same scale.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: headline,
    headlineLarge: subtitle.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: subtitle.copyWith(fontWeight: FontWeight.w500),
    headlineSmall: subtitle.copyWith(fontWeight: FontWeight.w400),
    titleLarge: title,
    titleMedium: body.copyWith(fontWeight: FontWeight.w500),
    titleSmall: label,
    bodyLarge: body.copyWith(fontWeight: FontWeight.w500),
    bodyMedium: body,
    bodySmall: label.copyWith(fontWeight: FontWeight.w400),
    labelLarge: label,
    labelMedium: caption,
    labelSmall: caption,
  );

  @override
  BullTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return BullTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  BullTypography lerp(
    covariant ThemeExtension<BullTypography>? other,
    double t,
  ) {
    if (other is! BullTypography) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t) ?? a;
    return BullTypography(
      display: mix(display, other.display),
      headline: mix(headline, other.headline),
      title: mix(title, other.title),
      subtitle: mix(subtitle, other.subtitle),
      body: mix(body, other.body),
      label: mix(label, other.label),
      caption: mix(caption, other.caption),
    );
  }
}

/// Accessor for the injected [BullTypography] off any [BuildContext].
extension BullTypographyX on BuildContext {
  /// The active [BullTypography]. Throws a [StateError] if the app did not register one in its `ThemeData.extensions`.
  BullTypography get bullType {
    final type = Theme.of(this).extension<BullTypography>();
    if (type == null) {
      throw StateError(
        'No BullTypography registered: add BullTypography.standard to ThemeData.extensions.',
      );
    }
    return type;
  }
}
