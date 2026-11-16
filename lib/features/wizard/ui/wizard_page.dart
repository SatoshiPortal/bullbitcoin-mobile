/// Vertical space reserved at the bottom of the SafeArea for the
/// floating chrome (dots + Next button OR Yes/No row). Step layouts
/// add this much bottom padding to their scrollable so the last item
/// can settle right above the chrome at max-scroll instead of being
/// hidden behind it.
const double kWizardChromeHeight = 140;

/// The 4 fixed pages of the install/upgrade wizard, in render order.
/// Used by `WizardScreen` to gate chrome (header, dots, Next button,
/// Yes/No row) and by each step widget to forward its position to
/// `WizardStepLayout`'s eyebrow.
enum WizardPage {
  welcome,
  customize,
  mission,
  journey;

  /// 1-indexed step number for the user-facing "PAGE x / total" eyebrow.
  int get number => index + 1;

  static int get total => values.length;

  bool get isFirst => index == 0;
  bool get isLast => index == values.length - 1;
}
