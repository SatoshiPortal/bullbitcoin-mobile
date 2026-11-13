// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'local_data_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LocalDataLocalizationsFr extends LocalDataLocalizations {
  LocalDataLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get localDataLockedTitle => 'Déverrouillez votre appareil';

  @override
  String get localDataLockedMessage =>
      'Les données de votre portefeuille restent scellées tant que cet appareil n\'a pas été déverrouillé une fois depuis son démarrage. Déverrouillez-le, puis réessayez.';

  @override
  String get localDataRetryButton => 'Réessayer';

  @override
  String get localDataRecoveryTitle =>
      'Impossible d\'ouvrir les données locales';

  @override
  String get localDataRecoveryMainMessage =>
      'Les données que cette app conserve sur cet appareil (liste des portefeuilles, libellés, historique des transactions, swaps et réglages) sont chiffrées, et la clé qui les ouvre n\'est plus disponible sur cet appareil.';

  @override
  String get localDataRecoveryPayjoinMessage =>
      'Les sessions Payjoin que cette app conserve sur cet appareil sont chiffrées, et la clé qui les ouvre n\'est plus disponible sur cet appareil. Vos portefeuilles ne sont pas concernés.';

  @override
  String get localDataRecoveryRecoverbullMessage =>
      'Les données locales de sauvegarde RecoverBull ne peuvent pas être ouvertes sans risque sur cet appareil.';

  @override
  String get localDataRecoveryRecoverbullRestoreHint =>
      'La réinitialisation efface la vérification locale des sauvegardes, l\'historique du suivi et les alertes. Vos portefeuilles et sauvegardes chiffrées exportées sont conservés. Les anciens réglages du serveur et son autorisation peuvent être réimportés.';

  @override
  String get localDataRecoveryInconsistentMessage =>
      'Une partie des données que cette app conserve sur cet appareil est dans un état qu\'elle ne peut pas ouvrir sans risque.';

  @override
  String get localDataRecoveryRestoreHint =>
      'La réinitialisation les efface. Votre phrase de récupération ou votre sauvegarde chiffrée restaure ensuite vos portefeuilles ; les libellés, les swaps et les sessions Payjoin ne reviennent pas.';

  @override
  String get localDataResetButton => 'Réinitialiser les données locales';

  @override
  String get localDataResetConfirmTitle => 'Effacer les données locales ?';

  @override
  String get localDataResetConfirmMessage => 'Cette action est irréversible.';

  @override
  String get localDataResetConfirmCheckbox =>
      'J\'ai ma phrase de récupération ou ma sauvegarde chiffrée';

  @override
  String get localDataResetConfirmButton => 'Effacer';

  @override
  String get localDataCancelButton => 'Annuler';

  @override
  String get localDataContactSupportButton => 'Contacter le support';

  @override
  String get localDataShareLogsButton => 'Partager les journaux';

  @override
  String get localDataShareLogsFailedMessage => 'Échec du partage des journaux';

  @override
  String get localDataResetFailedMessage =>
      'La réinitialisation n\'a pas abouti. Réessayez.';
}
