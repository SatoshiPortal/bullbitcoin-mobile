import 'package:bb_mobile/_l10n/generated/i18n/app_localizations.dart';
import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  // Avoid having to type `Theme.of(context)` everywhere,
  // by using `context.theme` instead.
  ThemeData get theme => Theme.of(this);
  // Avoid having to type `AppLocalizations.of(context)` everywhere,
  // by using `context.loc` instead.
  AppLocalizations get loc => AppLocalizations.of(this);
}
