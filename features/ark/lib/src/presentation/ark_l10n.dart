import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/ark_localizations.dart';
import '../../generated/l10n/ark_localizations_en.dart';
import '../../generated/l10n/ark_localizations_fr.dart';

/// Public entry widgets also work when native Ark composition is unavailable.
/// The app locale still controls the package's French/English fallback.
ArkLocalizations arkLocalizationsOf(BuildContext context) =>
    ArkLocalizations.of(context) ??
    (Localizations.maybeLocaleOf(context)?.languageCode == 'fr'
        ? ArkLocalizationsFr()
        : ArkLocalizationsEn());
