import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';

/// Vertical space reserved at the bottom of the SafeArea for the
/// floating chrome (dots + Next button OR Yes/No row). Step layouts
/// add this much bottom padding to their scrollable so the last item
/// can settle right above the chrome at max-scroll instead of being
/// hidden behind it.
const double kWizardChromeHeight = 140;

/// The fixed pages of the install/upgrade wizard, in declaration order.
/// Used by `WizardScreen` to gate chrome (header, dots, Next button,
/// Yes/No row) and by each step widget to forward its position to
/// `WizardStepLayout`'s eyebrow.
///
/// Not every declared page necessarily renders for a given build — see
/// [available].
enum WizardPage {
  welcome,
  customize,
  mission,
  privacy,
  journey;

  /// The pages actually shown, in render order, for this build/binary.
  ///
  /// [privacy] is included only in the explicit CBF test build. The wizard
  /// runs before `Bull.init`'s locator exists, so it cannot safely consult
  /// the runtime developer-mode setting. Showing the choice in an ordinary
  /// debug build would let a user select an option that wallet creation then
  /// silently ignores.
  static List<WizardPage> get available => [
    for (final page in values)
      if (page != privacy || _isPrivacyPageAvailable) page,
  ];

  static bool get _isPrivacyPageAvailable =>
      CheckCompactBlockFiltersAvailableUsecase.enableCbfFlag;

  /// 1-indexed step number for the user-facing "PAGE x / total" eyebrow,
  /// within [available] — not this enum's fixed declaration order.
  int get number => available.indexOf(this) + 1;

  static int get total => available.length;

  /// 0-indexed position within [available]; what `PageController`/`PageView`
  /// actually use, since a hidden [privacy] shifts every later page back.
  int get pageViewIndex => number - 1;

  bool get isFirst => this == available.first;
  bool get isLast => this == available.last;
}
