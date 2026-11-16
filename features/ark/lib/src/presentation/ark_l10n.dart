import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/ark_localizations.dart';
import '../../generated/l10n/ark_localizations_en.dart';
import '../../generated/l10n/ark_localizations_fr.dart';

/// Public entry widgets also work when native Ark composition is unavailable.
/// The app locale still controls the package's French/English fallback.
ArkLocalizations arkLocalizationsOf(BuildContext context) =>
    ArkLocalizations.of(context) ??
    arkLocalizationsForLanguage(
      Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
    );

/// Shared by context-free settings catalogues as well as visible entry widgets.
ArkLocalizations arkLocalizationsForLanguage(String localeName) =>
    localeName.split(RegExp('[-_]')).first.toLowerCase() == 'fr'
    ? ArkLocalizationsFr()
    : ArkLocalizationsEn();
