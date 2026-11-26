import 'package:flutter/widgets.dart';

import '../generated/l10n/onboarding_localizations.dart';

extension OnboardingLocalizationsContext on BuildContext {
  OnboardingLocalizations get loc => OnboardingLocalizations.of(this);
}
