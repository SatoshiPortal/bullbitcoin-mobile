import 'package:flutter/widgets.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';

extension WizardLocalizationsContext on BuildContext {
  WizardLocalizations get loc => WizardLocalizations.of(this);
}
