import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/app_startup/ui/screens/legacy_backup_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:novlang/novlang.dart';
import 'package:secrets/secrets.dart';

/// Terminal pre-initialization app: no locator, database or writable store.
class LegacyBackupApp extends StatelessWidget {
  const LegacyBackupApp({super.key, required this.secrets});

  final List<Secret>? secrets;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.themeData(AppThemeType.dark),
    // Runs before settings exist, like the startup wizard: platform policy only.
    localizationsDelegates: novlangLocalizationsDelegates(
      resolveNovlangPolicy(defaultTargetPlatform, null),
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        Device.init(context);
        return PopScope(
          canPop: false,
          child: LegacyBackupScreen(secrets: secrets),
        );
      },
    ),
  );
}
