// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'backup_metadata_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class BackupMetadataLocalizationsFr extends BackupMetadataLocalizations {
  BackupMetadataLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get dataBackup => 'Sauvegarde des données';

  @override
  String get intro =>
      'BULL conserve une copie chiffrée et à jour des données de vos portefeuilles pour les récupérer sur un nouveau téléphone.';

  @override
  String get whatIsSaved => 'Données sauvegardées';

  @override
  String get labels => 'Libellés';

  @override
  String get labelsDescription =>
      'Vos notes sur les transactions, les adresses et les pièces, ainsi que les pièces qui sont gelées.';

  @override
  String get neverRecoveryPhrase => 'Votre phrase de récupération reste privée';

  @override
  String get physicalBackup =>
      'Conservez votre sauvegarde physique. Sans le portefeuille, cette copie ne peut pas être ouverte.';

  @override
  String get whoCanRead => 'Qui peut lire la sauvegarde';

  @override
  String get privacy =>
      'La copie est chiffrée sur ce téléphone. Toute personne qui possède la phrase de récupération du portefeuille ou sa clé publique (xpub) peut l’ouvrir.';

  @override
  String get where => 'Emplacement';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get iCloud => 'iCloud';

  @override
  String get customLocation => 'Emplacement personnalisé';

  @override
  String get driveDescription =>
      'Dossier masqué de l’application dans votre compte Google';

  @override
  String get iCloudDescription => 'Le dossier de BULL dans votre iCloud Drive';

  @override
  String get folderDescription =>
      'Un dossier de votre choix sur le téléphone, une carte SD, une clé USB ou dans une autre application';

  @override
  String get continueAction => 'Continuer';

  @override
  String get walletsTitle => 'Portefeuilles à sauvegarder';

  @override
  String get walletsIntro =>
      'Un fichier chiffré par phrase de récupération. Seul le portefeuille correspondant permet de l’ouvrir.';

  @override
  String get testBackup => 'Tester la sauvegarde';

  @override
  String get turnOn => 'Activer la sauvegarde';

  @override
  String get unverified =>
      'La sauvegarde physique n’a pas été testée. Gardez-la à portée de main pour récupérer ce portefeuille.';

  @override
  String get publicKeyWarning =>
      'La clé publique peut ouvrir cette copie. Les applications ou serveurs qui la connaissent pourraient lire ces libellés.';

  @override
  String get unsupported => 'Ce portefeuille n’est pas encore pris en charge.';

  @override
  String get wallets => 'Portefeuilles';

  @override
  String get upToDate => 'À jour';

  @override
  String get actionNeeded => 'Action requise';

  @override
  String get backUpNow => 'Sauvegarder maintenant';

  @override
  String get destination => 'Emplacement';

  @override
  String get restoreFromBackup => 'Restaurer une sauvegarde';

  @override
  String get turnOff => 'Désactiver';

  @override
  String get turnOffTitle => 'Désactiver la sauvegarde automatique ?';

  @override
  String get turnOffMessage =>
      'Les nouvelles modifications resteront sur ce téléphone. Pour supprimer aussi les sauvegardes créées par ce téléphone, sélectionnez l’option ci-dessous.';

  @override
  String get alsoDelete => 'Supprimer aussi les sauvegardes';

  @override
  String get cancel => 'Annuler';

  @override
  String get restorePrompt => 'Restaurer vos libellés ?';

  @override
  String get restorePromptMessage =>
      'Si la sauvegarde automatique était activée, vous pouvez retrouver vos libellés et vos pièces gelées. BULL recherche uniquement la sauvegarde de ce portefeuille.';

  @override
  String get lookInDrive => 'Chercher dans Google Drive';

  @override
  String get lookInICloud => 'Chercher dans iCloud';

  @override
  String get chooseFile => 'Choisir un fichier de sauvegarde';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get restoreLater =>
      'Vous pourrez le faire plus tard dans Sauvegarde › Sauvegarde des données.';

  @override
  String get restoreLabels => 'Restaurer les libellés';

  @override
  String get version => 'Version';

  @override
  String get changesTitle => 'Modifications sur ce téléphone';

  @override
  String get labelsToAdd => 'Libellés à ajouter';

  @override
  String get coinsToFreeze => 'Pièces à geler';

  @override
  String get alreadySame => 'Déjà identiques';

  @override
  String get different => 'Différents sur ce téléphone';

  @override
  String get nothingDeleted =>
      'Aucune donnée de ce téléphone ne sera supprimée.';

  @override
  String get restore => 'Restaurer';

  @override
  String get labelsRestored => 'Libellés restaurés';

  @override
  String get restorePartial => 'Restauration partielle';

  @override
  String freezePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces n’ont pas encore été trouvées.',
      one: '1 pièce n’a pas encore été trouvée.',
    );
    return '$_temp0';
  }

  @override
  String freezeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces n’ont pas pu être gelées.',
      one: '1 pièce n’a pas pu être gelée.',
    );
    return '$_temp0';
  }

  @override
  String get retryFreezes => 'Réessayer de geler les pièces';

  @override
  String get done => 'Terminé';

  @override
  String get enableAfterRestore => 'Activer la sauvegarde automatique';

  @override
  String get failureNotReady =>
      'Ouvrez BULL et réessayez une fois le démarrage terminé.';

  @override
  String get failureStalePlan =>
      'Vos libellés ont changé. Vérifiez à nouveau la sauvegarde avant de restaurer.';

  @override
  String get failureTooLarge => 'Cette sauvegarde est trop volumineuse.';

  @override
  String get failureUnexpected =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String privacyProvider(String provider) {
    return 'Sans ces informations, $provider ne peut pas l’ouvrir.';
  }

  @override
  String backUpWallet(String wallet) {
    return 'Sauvegarder $wallet';
  }

  @override
  String unattributedLabels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libellés sans portefeuille ne sont pas sauvegardés.',
      one: '1 libellé sans portefeuille n’est pas sauvegardé.',
    );
    return '$_temp0';
  }

  @override
  String changesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
    );
    return '$_temp0';
  }

  @override
  String reconnect(String provider) {
    return 'Reconnecter $provider';
  }

  @override
  String walletCount(int selected, int total) {
    return '$selected sur $total';
  }

  @override
  String foundIn(String provider) {
    return 'Sauvegarde trouvée dans $provider';
  }

  @override
  String keepLabel(String label) {
    return 'Conserver « $label »';
  }

  @override
  String useBackupLabel(String label) {
    return 'Restaurer « $label »';
  }

  @override
  String restoredAmounts(int labels, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      labels,
      locale: localeName,
      other: '$labels libellés',
      one: '1 libellé',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins pièces gelées',
      one: '1 pièce gelée',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String pendingAmounts(int labels, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      labels,
      locale: localeName,
      other: '$labels libellés',
      one: '1 libellé',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins pièces en attente',
      one: '1 pièce en attente',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String labelsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libellés n’ont pas pu être restaurés.',
      one: '1 libellé n’a pas pu être restauré.',
    );
    return '$_temp0';
  }

  @override
  String differencesResolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count différences réglées selon vos choix.',
      one: '1 différence réglée selon votre choix.',
    );
    return '$_temp0';
  }

  @override
  String handedTo(String provider, String when) {
    return 'Envoyée à $provider $when';
  }

  @override
  String pendingStatus(String when) {
    return 'Sauvegarde dès que le téléphone est en ligne. Dernière sauvegarde $when.';
  }

  @override
  String reconnectStatus(String provider, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications sont conservées',
      one: '1 modification est conservée',
    );
    return 'BULL ne peut plus accéder à $provider. $_temp0 sur ce téléphone jusqu’à la reconnexion.';
  }

  @override
  String labelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libellés',
      one: '1 libellé',
    );
    return '$_temp0';
  }

  @override
  String previousVersionKept(String labels) {
    return '$labels · version précédente conservée';
  }

  @override
  String latestVersion(String date) {
    return 'Dernière · $date';
  }

  @override
  String previousVersion(String date) {
    return 'Précédente · $date';
  }

  @override
  String get sameRecoveryPhrase => 'Même phrase de récupération';

  @override
  String get importedPhrase => 'Phrase importée';

  @override
  String get watchOnly => 'Lecture seule';

  @override
  String get off => 'Désactivée';

  @override
  String recentStatus(String when) {
    return 'À jour · $when';
  }
}
