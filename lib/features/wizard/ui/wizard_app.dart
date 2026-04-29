import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';

/// Standalone app shown before `Bull.init` runs. Intentionally has no
/// dependency on the locator, FRB bridges or bloc providers — anything
/// needed later must not be required to render this wizard.
///
/// Holds the user's current choices in local state so that language and
/// theme changes are applied immediately to the wizard UI.
class WizardApp extends StatefulWidget {
  const WizardApp({super.key, required this.onDone});

  final ValueChanged<WizardChoices> onDone;

  @override
  State<WizardApp> createState() => _WizardAppState();
}

class _WizardAppState extends State<WizardApp> {
  WizardChoices _choices = const WizardChoices();

  void _update(WizardChoices next) => setState(() => _choices = next);

  @override
  Widget build(BuildContext context) {
    Device.init(context);
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final appThemeType = switch (_choices.themeMode) {
      AppThemeMode.light => AppThemeType.light,
      AppThemeMode.dark => AppThemeType.dark,
      AppThemeMode.system =>
        systemBrightness == Brightness.dark
            ? AppThemeType.dark
            : AppThemeType.light,
    };

    return MaterialApp(
      title: 'Bull',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(appThemeType),
      locale: _choices.language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WizardScreen(
        choices: _choices,
        onChange: _update,
        onDone: () => widget.onDone(_choices),
      ),
    );
  }
}
