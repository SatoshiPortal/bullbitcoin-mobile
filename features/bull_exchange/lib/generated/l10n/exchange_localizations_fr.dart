// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ExchangeLocalizationsFr extends ExchangeLocalizations {
  ExchangeLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get exchangeAccountInfoEmailLabel => 'Courriel';

  @override
  String get exchangeAccountInfoFirstNameLabel => 'Prénom';

  @override
  String get exchangeAccountInfoLastNameLabel => 'Nom de famille';

  @override
  String get exchangeAccountInfoLoadErrorMessage =>
      'Impossible de charger les informations du compte';

  @override
  String get exchangeAccountInfoTitle => 'Informations du compte';

  @override
  String get exchangeAccountInfoUserNumberCopiedMessage =>
      'Numéro d\'utilisateur copié dans le presse-papiers';

  @override
  String get exchangeAccountInfoUserNumberLabel => 'Numéro d\'utilisateur';

  @override
  String get exchangeAccountInfoVerificationIdentityVerified =>
      'Identité vérifiée';

  @override
  String get exchangeAccountInfoVerificationLevelLabel =>
      'Niveau de vérification';

  @override
  String get exchangeAccountInfoVerificationLightVerification =>
      'Vérification légère';

  @override
  String get exchangeAccountInfoVerificationLimitedVerification =>
      'Vérification limitée';

  @override
  String get exchangeAccountInfoVerificationNotVerified => 'Non vérifié';

  @override
  String get exchangeAppSettingsDefaultCurrencyLabel => 'Devise par défaut';

  @override
  String get exchangeAppSettingsEmailNotificationsDescription =>
      'Recevoir des notifications par courriel pour les commandes et les mises à jour de compte';

  @override
  String get exchangeAppSettingsEmailNotificationsLabel =>
      'Notifications par courriel';

  @override
  String get exchangeAppSettingsPreferredLanguageLabel => 'Langue préférée';

  @override
  String get exchangeAppSettingsSaveButton => 'Enregistrer';

  @override
  String get exchangeAppSettingsSaveSuccessMessage =>
      'Paramètres enregistrés avec succès';

  @override
  String get exchangeAppSettingsValidationWarning =>
      'Veuillez définir à la fois la langue et les préférences de devise avant d\'enregistrer.';

  @override
  String get exchangeAuthErrorMessage =>
      'Une erreur s\'est produite, veuillez réessayer de vous connecter.';

  @override
  String get exchangeBitcoinWalletsTitle => 'Portefeuilles Bitcoin par défaut';

  @override
  String get exchangeErrorNetwork =>
      'Vérifiez votre connexion Internet et réessayez.';

  @override
  String get exchangeErrorSavingPreferences =>
      'Vos préférences n\'ont pas pu être enregistrées. Veuillez réessayer.';

  @override
  String get exchangeFileUploadButton => 'Téléverser';

  @override
  String get exchangeFileUploadDocumentTitle => 'Téléverser un document';

  @override
  String get exchangeFileUploadInstructions =>
      'Si vous devez envoyer d\'autres documents, téléversez-les ici.';

  @override
  String get exchangeFileUploadStatusAccepted => 'Acceptée';

  @override
  String get exchangeFileUploadStatusInReview => 'In Review';

  @override
  String get exchangeFileUploadStatusRejectedBadge => 'Rejeté';

  @override
  String get exchangeFileUploadSuccess => 'Fichier téléchargé avec succès';

  @override
  String get exchangeFileUploadTapToReupload =>
      'Touchez pour téléverser à nouveau';

  @override
  String get exchangeFileUploadTitle => 'Téléversement sécurisé de fichiers';

  @override
  String get exchangeReferralsApplyToJoinMessage =>
      'Postulez pour rejoindre le programme ici';

  @override
  String get exchangeReferralsContactSupportMessage =>
      'Contactez le support pour en savoir plus sur notre programme de parrainage';

  @override
  String get exchangeReferralsJoinMissionTitle => 'Rejoignez la mission';

  @override
  String get exchangeReferralsMissionLink => 'bullbitcoin.com/mission';

  @override
  String get exchangeReferralsTitle => 'Codes de parrainage';

  @override
  String get exchangeSecurityAccessSettingsButton => 'Accéder aux paramètres';

  @override
  String get exchangeSecurityManage2FAPasswordLabel =>
      'Gérer l\'authentification à deux facteurs et le mot de passe';

  @override
  String get exchangeSettingsAccountInformationTitle =>
      'Informations du compte';

  @override
  String get exchangeSettingsErrorDocumentAlreadySubmitted =>
      'Un document a déjà été soumis.';

  @override
  String get exchangeSettingsErrorDocumentEmpty =>
      'Ce fichier est vide. Choisissez-en un autre.';

  @override
  String get exchangeSettingsErrorDocumentTooLarge =>
      'Ce fichier est trop volumineux. Choisissez-en un plus petit.';

  @override
  String get exchangeSettingsErrorDocumentTypeNotAllowed =>
      'Ce type de fichier n\'est pas accepté. Choisissez-en un autre.';

  @override
  String get exchangeSettingsErrorDocumentUnreadable =>
      'Ce fichier n\'a pas pu être lu. Choisissez-en un autre.';

  @override
  String get exchangeSettingsErrorLoadingAccount =>
      'Les détails de votre compte n\'ont pas pu être chargés. Veuillez réessayer.';

  @override
  String get exchangeSettingsErrorLoadingStatistics =>
      'Vos statistiques de trading n\'ont pas pu être chargées. Veuillez réessayer.';

  @override
  String get exchangeSettingsErrorLoadingUploadStatus =>
      'Le statut de votre téléversement n\'a pas pu être chargé. Veuillez réessayer.';

  @override
  String get exchangeSettingsErrorUploadingDocument =>
      'Le document n\'a pas pu être téléversé. Veuillez réessayer.';

  @override
  String get exchangeSettingsLogInTitle => 'Se connecter';

  @override
  String get exchangeSettingsRecipientsTitle => 'Destinataires';

  @override
  String get exchangeSettingsReferralsTitle => 'Parrainages';

  @override
  String get exchangeSettingsSecuritySettingsTitle => 'Paramètres de sécurité';

  @override
  String get exchangeSettingsTransactionsTitle => 'Transactions';

  @override
  String exchangeStatisticsAsOf(String date) {
    return 'À partir de $date';
  }

  @override
  String get exchangeStatisticsAveragePrice => 'Prix moyen';

  @override
  String get exchangeStatisticsBillerStats => 'Statistiques Biller';

  @override
  String get exchangeStatisticsBuyAvgPriceDesc =>
      'Prix moyen payé par bitcoin lors des achats';

  @override
  String get exchangeStatisticsBuySellRatio => 'Acheter/Sell Ratio';

  @override
  String get exchangeStatisticsBuySellRatioDesc =>
      'Pourcentage du volume total entre achats et ventes';

  @override
  String get exchangeStatisticsBuyStats => 'Acheter des statistiques';

  @override
  String get exchangeStatisticsBuyTradeCountDesc =>
      'Nombre de transactions d\'achat de bitcoin';

  @override
  String get exchangeStatisticsBuyVolumeDesc =>
      'Montant total dépensé pour acheter des bitcoins';

  @override
  String exchangeStatisticsCurrency(String currency) {
    return 'Devise : $currency';
  }

  @override
  String get exchangeStatisticsNoData => 'Pas de statistiques disponibles';

  @override
  String get exchangeStatisticsOrderStats => 'Statistiques des ordres';

  @override
  String get exchangeStatisticsSellAvgPriceDesc =>
      'Prix moyen reçu par bitcoin lors des ventes';

  @override
  String get exchangeStatisticsSellStats => 'Statistiques de vente';

  @override
  String get exchangeStatisticsSellTradeCountDesc =>
      'Nombre de transactions de vente de bitcoin';

  @override
  String get exchangeStatisticsSellVolumeDesc =>
      'Montant total reçu de la vente de bitcoins';

  @override
  String get exchangeStatisticsTitle => 'Statistiques';

  @override
  String get exchangeStatisticsTotalAmount => 'Montant Total';

  @override
  String get exchangeStatisticsTotalVolume => 'Total Trading Volume';

  @override
  String get exchangeStatisticsTotalVolumeDesc =>
      'Volumes combinés d\'achat et de vente en devises fiat';

  @override
  String get exchangeStatisticsTradeCount => 'Trade Count';

  @override
  String exchangeStatisticsTradeCountByCurrency(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opérations ($currency)',
      one: '1 opération ($currency)',
    );
    return '$_temp0';
  }

  @override
  String exchangeStatisticsTradeCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opérations',
      one: '1 opération',
    );
    return '$_temp0';
  }

  @override
  String get exchangeStatisticsVolume => 'Volume';

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Joindre un fichier';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Échec de l\'ajout des journaux. Veuillez réessayer.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Joindre les journaux';

  @override
  String get exchangeSupportChatAttachmentImage => 'Image';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Fichier inconnu';

  @override
  String get exchangeSupportChatEmptyState =>
      'Aucun message pour le moment. Commencez une conversation !';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Échec de la récupération des données du fichier.';

  @override
  String get exchangeSupportChatInputHint => 'Tapez un message...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Impossible d\'ouvrir la pièce jointe. Veuillez réessayer.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Impossible de charger les messages. Veuillez réessayer.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Le message ne peut pas être vide';

  @override
  String get exchangeSupportChatMessageRequired => 'Un message est requis';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Échec de la sélection des fichiers. Veuillez réessayer.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Impossible d\'envoyer votre message. Veuillez réessayer.';

  @override
  String get exchangeSupportChatSendTooltip => 'Envoyer le message';

  @override
  String get exchangeSupportChatTitle => 'Chat de Support';

  @override
  String get exchangeSupportChatYesterday => 'Hier';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Pour obtenir de l\'aide humaine, vous devez d\'abord vous connecter à votre compte Bull Bitcoin. C\'est 100 % gratuit et aucun KYC n\'est requis, seulement une adresse courriel.';

  @override
  String get loginButton => 'CONNEXION';

  @override
  String get notLoggedInTitle => 'Vous n\'êtes pas connecté';

  @override
  String get oopsSomethingWentWrong => 'Oups ! Une erreur s\'est produite';

  @override
  String get retry => 'Réessayer';

  @override
  String get settingsAppSettingsTitle => 'Paramètres de l\'application';

  @override
  String get exchangeSupportChatLogDraft => 'Voici mes journaux';
}
