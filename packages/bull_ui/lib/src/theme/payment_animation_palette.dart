import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Colors used by the payment storyboard, independently of the app theme.
class PaymentAnimationPalette extends ThemeExtension<PaymentAnimationPalette> {
  const PaymentAnimationPalette();

  static const standard = PaymentAnimationPalette();

  @override
  PaymentAnimationPalette copyWith() => this;

  @override
  PaymentAnimationPalette lerp(PaymentAnimationPalette? other, double t) =>
      this;

  Color get background => const Color(0xff15171c);
  Color get foreground => const Color(0xfff2f2f2);
  Color get bitcoin => const Color(0xfff7931a);
  Color get lightning => const Color(0xffffd84a);
  Color get liquid => const Color(0xff00c3b0);
  Color get ark => const Color(0xff6d9bff);
  Color get boltz => const Color(0xffb38cff);
  Color get payjoin => const Color(0xffe86bd8);
  Color get failure => const Color(0xffb7000b);
  Color get success => AppColors.dark.success;

  /// A broadcast transaction waiting for its confirmation.
  Color get broadcast => const Color(0xffff9f0a);
  Color get gray => const Color(0xff888888);
}
