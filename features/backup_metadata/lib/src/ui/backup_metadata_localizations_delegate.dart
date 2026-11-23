import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/backup_metadata_localizations.dart';

/// Uses the English catalog in app locales awaiting translation.
const LocalizationsDelegate<BackupMetadataLocalizations>
backupMetadataLocalizationsDelegate = _BackupMetadataLocalizationsDelegate();

class _BackupMetadataLocalizationsDelegate
    extends LocalizationsDelegate<BackupMetadataLocalizations> {
  const _BackupMetadataLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<BackupMetadataLocalizations> load(Locale locale) =>
      BackupMetadataLocalizations.delegate.load(
        BackupMetadataLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );

  @override
  bool shouldReload(_BackupMetadataLocalizationsDelegate old) => false;
}
