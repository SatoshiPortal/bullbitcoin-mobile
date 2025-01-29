import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension LocalizedBuildContext on BuildContext {
  // Avoid having to type `AppLocalizations.of(context)` everywhere,
  // by using `context.loc` instead.
  AppLocalizations get loc => AppLocalizations.of(this);
}

extension ThemedBuildContext on BuildContext {
  // Avoid having to type `Theme.of(context)` everywhere,
  // by using `context.theme` instead.
  ThemeData get theme => Theme.of(this);
}
