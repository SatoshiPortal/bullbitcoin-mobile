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

  @override
  String get settingsAccountSettingsTitle => 'Account Settings';

  @override
  String get settingsErrorSavingSetting =>
      'Ce paramètre n\'a pas pu être enregistré. Veuillez réessayer.';

  @override
  String get exchangeAccessSettingsTitle => 'BULL Exchange';

  @override
  String get exchangeAccessSettingsLabel => 'Fonctionnalités de l’exchange';

  @override
  String get exchangeAccessSettingsOffHint =>
      'Activez cette option pour vous connecter ou créer un compte Bull Bitcoin.';

  @override
  String get exchangeAccessSettingsOnHint =>
      'Les fonctionnalités de l’exchange sont activées.';

  @override
  String get exchangeAccessSignIn => 'Se connecter ou créer un compte';

  @override
  String get exchangeAccessDisableTitle =>
      'Désactiver les fonctionnalités de l’exchange ?';

  @override
  String get exchangeAccessDisableBody =>
      'Cette action vous déconnecte sur cet appareil. Les ordres existants, AutoBuy et les achats récurrents ne sont pas annulés.';

  @override
  String get exchangeAccessDisableConfirm => 'Se déconnecter et désactiver';

  @override
  String get exchangeTradingRetry => 'Réessayer';

  @override
  String get exchangeAccessUnreadable =>
      'Impossible de lire l’accès à la plateforme. Réessayez ou réinitialisez-le.';

  @override
  String get exchangeAccessReset => 'Réinitialiser l’accès à la plateforme';

  @override
  String get exchangeAccessLogoutIncomplete =>
      'La déconnexion est incomplète. Terminez-la avant d’activer la plateforme.';

  @override
  String get exchangeAccessRetryLogout => 'Terminer la déconnexion';

  @override
  String get fundExchangeTitle => 'Financement';

  @override
  String get fundExchangeAccountTitle => 'Approvisionner votre compte';

  @override
  String get fundExchangeAccountSubtitle =>
      'Sélectionnez votre pays et votre mode de paiement';

  @override
  String get fundExchangeRestrictedTitle => 'Financement indisponible';

  @override
  String get fundExchangeRestrictedMessage =>
      'Le financement n\'est pas disponible sur votre compte. Veuillez contacter le support pour plus d\'informations.';

  @override
  String get fundExchangeWarningTitle => 'Attention aux escrocs';

  @override
  String get fundExchangeWarningDescription =>
      'Si quelqu\'un vous demande d\'acheter du Bitcoin ou vous « aide », soyez prudent, il pourrait essayer de vous escroquer !';

  @override
  String get fundExchangeWarningTacticsTitle =>
      'Tactiques courantes des escrocs';

  @override
  String get fundExchangeWarningTactic1 =>
      'Ils promettent des rendements sur investissement';

  @override
  String get fundExchangeWarningTactic2 => 'Ils vous offrent un prêt';

  @override
  String get fundExchangeWarningTactic3 =>
      'Ils disent travailler pour le recouvrement de dettes ou d\'impôts';

  @override
  String get fundExchangeWarningTactic4 =>
      'Ils demandent d\'envoyer du Bitcoin à leur adresse';

  @override
  String get fundExchangeWarningTactic5 =>
      'Ils demandent d\'envoyer du Bitcoin sur une autre plateforme';

  @override
  String get fundExchangeWarningTactic6 =>
      'Ils veulent que vous partagiez votre écran';

  @override
  String get fundExchangeWarningTactic7 =>
      'Ils vous disent de ne pas vous inquiéter de cet avertissement';

  @override
  String get fundExchangeWarningTactic8 =>
      'Ils vous pressent d\'agir rapidement';

  @override
  String get fundExchangeWarningConfirmation =>
      'Je confirme que personne ne me demande d\'acheter du Bitcoin.';

  @override
  String get fundExchangeContinueButton => 'Continuer';

  @override
  String get fundExchangeScamConsentError =>
      'Échec de l\'enregistrement de votre consentement. Veuillez réessayer.';

  @override
  String get fundExchangeDoneButton => 'Terminé';

  @override
  String get fundExchangeJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get fundExchangeJurisdictionEurope => '🇪🇺 Europe (SEPA)';

  @override
  String get fundExchangeJurisdictionMexico => '🇲🇽 Mexique';

  @override
  String get fundExchangeJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get fundExchangeJurisdictionArgentina => '🇦🇷 Argentine';

  @override
  String get fundExchangeJurisdictionColombia => '🇨🇴 Colombie';

  @override
  String get fundExchangeMethodEmailETransfer => 'Virement électronique';

  @override
  String get fundExchangeMethodEmailETransferSubtitle =>
      'Méthode la plus simple et la plus rapide (instantané)';

  @override
  String get fundExchangeMethodBankTransferWire =>
      'Virement bancaire (Wire ou TEF)';

  @override
  String get fundExchangeMethodBankTransferWireSubtitle =>
      'Meilleure option la plus fiable pour les montants importants (jour même ou jour suivant)';

  @override
  String get fundExchangeMethodOnlineBillPayment =>
      'Paiement de facture en ligne';

  @override
  String get fundExchangeMethodOnlineBillPaymentSubtitle =>
      'Option la plus lente, mais peut être effectuée via les services bancaires en ligne (3-4 jours ouvrables)';

  @override
  String get fundExchangeMethodCanadaPost =>
      'Espèces ou débit en personne à Postes Canada';

  @override
  String get fundExchangeMethodCanadaPostSubtitle =>
      'Idéal pour ceux qui préfèrent payer en personne';

  @override
  String get fundExchangeMethodInstantSepa => 'SEPA régulier et instantané';

  @override
  String get fundExchangeMethodInstantSepaSubtitle =>
      'Le plus rapide - Uniquement pour les transactions inférieures à 30 000 €';

  @override
  String get fundExchangeMethodRegularSepa => 'SEPA régulier';

  @override
  String get fundExchangeMethodRegularSepaSubtitle =>
      'À utiliser uniquement pour les transactions supérieures à 30 000 €';

  @override
  String get fundExchangeBankTransferWireTitle => 'Virement bancaire (wire)';

  @override
  String get fundExchangeBankTransferWireDescription =>
      'Envoyez un virement bancaire depuis votre compte bancaire en utilisant les coordonnées bancaires de Bull Bitcoin ci-dessous. Votre banque peut ne nécessiter qu\'une partie de ces informations.';

  @override
  String get fundExchangeBankTransferWireTimeframe =>
      'Tous les fonds que vous envoyez seront ajoutés à votre Bull Bitcoin dans un délai de 1 à 2 jours ouvrables.';

  @override
  String get fundExchangeLabelBeneficiaryName => 'Nom du bénéficiaire';

  @override
  String get fundExchangeHelpBeneficiaryName =>
      'Utilisez notre nom corporatif officiel. N\'utilisez pas « Bull Bitcoin ».';

  @override
  String get fundExchangeLabelTransferCode =>
      'Code de transfert (ajoutez-le comme description de paiement)';

  @override
  String get fundExchangeHelpTransferCode =>
      'Ajoutez ceci comme raison du transfert';

  @override
  String get fundExchangeInfoTransferCode =>
      'Vous devez ajouter le code de transfert comme « message » ou « raison » lors du paiement.';

  @override
  String get fundExchangeLabelBankAccountDetails =>
      'Détails du compte bancaire';

  @override
  String get fundExchangeLabelSwiftCode => 'Code SWIFT';

  @override
  String get fundExchangeLabelInstitutionNumber => 'Numéro d\'institution';

  @override
  String get fundExchangeLabelTransitNumber => 'Numéro de transit';

  @override
  String get fundExchangeLabelRoutingNumber => 'Numéro d\'acheminement';

  @override
  String get fundExchangeLabelBeneficiaryAddress => 'Adresse du bénéficiaire';

  @override
  String get fundExchangeLabelBankName => 'Nom de la banque';

  @override
  String get fundExchangeLabelBankAddress => 'Adresse de notre banque';

  @override
  String get fundExchangeETransferTitle => 'Détails du virement électronique';

  @override
  String get fundExchangeETransferDescription =>
      'Tout montant que vous envoyez depuis votre banque par virement électronique en utilisant les informations ci-dessous sera crédité sur votre solde de compte Bull Bitcoin dans quelques minutes.';

  @override
  String get fundExchangeETransferLabelBeneficiaryName =>
      'Utilisez ceci comme nom du bénéficiaire du virement électronique';

  @override
  String get fundExchangeETransferLabelEmail =>
      'Envoyez le virement électronique à cette adresse courriel';

  @override
  String get fundExchangeETransferLabelSecretQuestion => 'Question secrète';

  @override
  String get fundExchangeETransferLabelSecretAnswer => 'Réponse secrète';

  @override
  String get fundExchangeOnlineBillPaymentTitle =>
      'Paiement de facture en ligne';

  @override
  String get fundExchangeOnlineBillPaymentDescription =>
      'Tout montant que vous envoyez via la fonctionnalité de paiement de facture en ligne de votre banque en utilisant les informations ci-dessous sera crédité sur votre solde de compte Bull Bitcoin dans un délai de 3 à 4 jours ouvrables.';

  @override
  String get fundExchangeOnlineBillPaymentLabelBillerName =>
      'Recherchez dans la liste des fournisseurs de votre banque ce nom';

  @override
  String get fundExchangeOnlineBillPaymentHelpBillerName =>
      'Ajoutez cette entreprise comme bénéficiaire - c\'est le processeur de paiement de Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostTitle =>
      'Espèces ou débit en personne à Postes Canada';

  @override
  String get fundExchangeCanadaPostStep1 =>
      '1. Rendez-vous dans n\'importe quel bureau de Postes Canada';

  @override
  String get fundExchangeCanadaPostStep2 =>
      '2. Demandez au caissier de scanner le code QR « Loadhub »';

  @override
  String get fundExchangeCanadaPostStep3 =>
      '3. Indiquez au caissier le montant que vous souhaitez charger';

  @override
  String get fundExchangeCanadaPostStep4 =>
      '4. Le caissier vous demandera de présenter une pièce d\'identité émise par le gouvernement et vérifiera que le nom sur votre pièce d\'identité correspond à votre compte Bull Bitcoin';

  @override
  String get fundExchangeCanadaPostStep5 =>
      '5. Payez en espèces ou par carte de débit';

  @override
  String get fundExchangeCanadaPostStep6 =>
      '6. Le caissier vous remettra un reçu, conservez-le comme preuve de paiement';

  @override
  String get fundExchangeCanadaPostStep7 =>
      '7. Les fonds seront ajoutés à votre solde de compte Bull Bitcoin dans les 30 minutes';

  @override
  String get fundExchangeCanadaPostQrCodeLabel => 'Code QR Loadhub';

  @override
  String get fundExchangeSepaTitle => 'Virement SEPA';

  @override
  String get fundExchangeSepaDescription =>
      'Envoyez un virement SEPA depuis votre compte bancaire en utilisant les détails ci-dessous ';

  @override
  String get fundExchangeSepaDescriptionExactly => 'exactement.';

  @override
  String get fundExchangeInstantSepaInfo =>
      'À utiliser uniquement pour les transactions inférieures à 20 000 €. Pour les transactions plus importantes, utilisez l\'option SEPA régulier.';

  @override
  String get fundExchangeRegularSepaInfo =>
      'À utiliser uniquement pour les transactions supérieures à 20 000 €. Pour les transactions plus petites, utilisez l\'option SEPA instantané.';

  @override
  String get fundExchangeLabelIban => 'Numéro de compte IBAN';

  @override
  String get fundExchangeLabelBicCode => 'Code BIC';

  @override
  String get fundExchangeLabelBankAccountCountry => 'Pays du compte bancaire';

  @override
  String get fundExchangeInfoBankCountryUk =>
      'Le pays de notre banque est le Royaume-Uni.';

  @override
  String get fundExchangeInfoBeneficiaryNameLeonod =>
      'Le nom du bénéficiaire doit être LEONOD. Si vous mettez autre chose, votre paiement sera rejeté.';

  @override
  String get fundExchangeInfoPaymentDescription =>
      'Dans la description du paiement, ajoutez votre code de transfert.';

  @override
  String get fundExchangeHelpBeneficiaryAddress =>
      'Notre adresse officielle, au cas où votre banque l\'exigerait';

  @override
  String get fundExchangeLabelRecipientName => 'Nom du destinataire';

  @override
  String get fundExchangeLabelBankCountry => 'Pays de la banque';

  @override
  String get fundExchangeLabelRecipientAddress => 'Adresse du destinataire';

  @override
  String get fundExchangeSpeiTitle => 'Virement SPEI';

  @override
  String get fundExchangeSpeiDescription =>
      'Transférez des fonds en utilisant votre CLABE';

  @override
  String get fundExchangeSpeiInfo =>
      'Effectuez un dépôt par virement SPEI (instantané).';

  @override
  String get fundExchangeLabelClabe => 'CLABE';

  @override
  String get fundExchangeLabelMemo => 'Mémo';

  @override
  String get fundExchangeSinpeTitle => 'Virement SINPE';

  @override
  String get fundExchangeSinpeDescription =>
      'Transférez des colones en utilisant SINPE';

  @override
  String get fundExchangeCrIbanCrcTitle => 'Virement bancaire (CRC)';

  @override
  String get fundExchangeCrIbanUsdTitle => 'Virement bancaire (USD)';

  @override
  String get fundExchangeArsBankTransferTitle => 'Virement bancaire';

  @override
  String get fundExchangeArsBankTransferDescription =>
      'Envoyez un virement bancaire depuis votre compte bancaire en utilisant les coordonnées bancaires exactes de l\'Argentine ci-dessous.';

  @override
  String get fundExchangeLabelRecipientNameArs => 'Nom du destinataire';

  @override
  String get fundExchangeLabelCvu => 'CVU';

  @override
  String get fundExchangeErrorLoadingDetails =>
      'Les détails du paiement n\'ont pas pu être chargés pour le moment. Veuillez revenir en arrière et réessayer, choisir un autre mode de paiement ou revenir plus tard.';

  @override
  String get fundExchangeErrorTitleOrdPo404 =>
      'Option de paiement indisponible';

  @override
  String get fundExchangeErrorOrdPo404 =>
      'Aucune option de paiement disponible';

  @override
  String get fundExchangeErrorTitleRcpPo404 =>
      'Option de paiement non disponible';

  @override
  String get fundExchangeErrorRcpPo404 =>
      'Vous n\'avez pas les autorisations requises pour accéder à cette option de financement. Soit votre KYC est insuffisant, soit cette option n\'est pas disponible pour votre compte';

  @override
  String get fundExchangeErrorTitleRcpPosinpe404 => 'SINPE non disponible';

  @override
  String get fundExchangeErrorRcpPosinpe404 =>
      'Pour accéder à cette option de financement, votre numéro de téléphone doit être enregistré auprès du réseau SINPE au Costa Rica.';

  @override
  String get fundExchangeErrorTitleOrdKyc400 => 'Exigences KYC manquantes';

  @override
  String get fundExchangeErrorOrdKyc400 =>
      'Vous ne remplissez pas les exigences KYC pour cette action';

  @override
  String get fundExchangeErrorTitleOrdCop400 =>
      'Données de financement COP invalides';

  @override
  String get fundExchangeErrorOrdCop400 =>
      'Données de demande invalides pour le financement COP';

  @override
  String get fundExchangeErrorOpeningPaymentLink =>
      'Le lien de paiement n\'a pas pu être ouvert. Veuillez réessayer.';

  @override
  String get fundExchangeErrorTitleOrdCsrcp400 => 'Paiement virtuel non activé';

  @override
  String get fundExchangeErrorOrdCsrcp400 =>
      'Veuillez activer l\'option de paiement virtuel pour ce destinataire SEPA';

  @override
  String get fundExchangeErrorTitleRcp400 => 'Requête invalide';

  @override
  String get fundExchangeErrorRcp400 => 'Requête invalide';

  @override
  String get fundExchangeErrorFetchingBankCodes =>
      'Erreur lors de la récupération des codes bancaires. Veuillez réessayer plus tard.';

  @override
  String get fundExchangeSinpeDescriptionBold => 'il sera rejeté.';

  @override
  String get fundExchangeSinpeAddedToBalance =>
      'Une fois le paiement envoyé, il sera ajouté au solde de votre compte.';

  @override
  String get fundExchangeSinpeLabelPhone => 'Envoyer à ce numéro de téléphone';

  @override
  String get fundExchangeSinpeLabelRecipientName => 'Nom du destinataire';

  @override
  String get fundExchangeCrIbanCrcDescription =>
      'Envoyez un virement bancaire depuis votre compte bancaire en utilisant les détails ci-dessous ';

  @override
  String get fundExchangeCrIbanCrcDescriptionBold => 'exactement';

  @override
  String get fundExchangeCrIbanCrcDescriptionEnd =>
      '. Les fonds seront ajoutés au solde de votre compte.';

  @override
  String get fundExchangeCrIbanCrcLabelIban =>
      'Numéro de compte IBAN (Colones seulement)';

  @override
  String get fundExchangeCrIbanCrcLabelPaymentDescription =>
      'Description du paiement';

  @override
  String get fundExchangeCrIbanCrcPaymentDescriptionHelp =>
      'Votre code de virement.';

  @override
  String get fundExchangeCrIbanCrcTransferCodeWarning =>
      'Vous devez ajouter le code de virement comme « message » ou « raison » ou « description » lors du paiement. Si vous oubliez d\'inclure ce code, votre paiement peut être rejeté.';

  @override
  String get fundExchangeCrIbanCrcLabelRecipientName => 'Nom du destinataire';

  @override
  String get fundExchangeCrIbanCrcRecipientNameHelp =>
      'Utilisez notre nom d\'entreprise officiel. N\'utilisez pas « Bull Bitcoin ».';

  @override
  String get fundExchangeCrIbanCrcLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCrIbanUsdDescription =>
      'Envoyez un virement bancaire depuis votre compte bancaire en utilisant les détails ci-dessous ';

  @override
  String get fundExchangeCrIbanUsdDescriptionBold => 'exactement';

  @override
  String get fundExchangeCrIbanUsdDescriptionEnd =>
      '. Les fonds seront ajoutés au solde de votre compte.';

  @override
  String get fundExchangeCrIbanUsdLabelIban =>
      'Numéro de compte IBAN (dollars américains seulement)';

  @override
  String get fundExchangeCrIbanUsdLabelPaymentDescription =>
      'Description du paiement';

  @override
  String get fundExchangeCrIbanUsdPaymentDescriptionHelp =>
      'Votre code de virement.';

  @override
  String get fundExchangeCrIbanUsdTransferCodeWarning =>
      'Vous devez ajouter le code de virement comme « message » ou « raison » ou « description » lors du paiement. Si vous oubliez d\'inclure ce code, votre paiement peut être rejeté.';

  @override
  String get fundExchangeCrIbanUsdLabelRecipientName => 'Nom du destinataire';

  @override
  String get fundExchangeCrIbanUsdRecipientNameHelp =>
      'Utilisez notre nom d\'entreprise officiel. N\'utilisez pas « Bull Bitcoin ».';

  @override
  String get fundExchangeCrIbanUsdLabelCedulaJuridica => 'Cédula Jurídica';

  @override
  String get fundExchangeCostaRicaMethodSinpeTitle => 'SINPE Móvil';

  @override
  String get fundExchangeCostaRicaMethodSinpeSubtitle =>
      'Transférer des Colones en utilisant SINPE';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcTitle => 'IBAN Costa Rica (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanCrcSubtitle =>
      'Transférer des fonds en Colón costaricain (CRC)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdTitle => 'IBAN Costa Rica (USD)';

  @override
  String get fundExchangeCostaRicaMethodIbanUsdSubtitle =>
      'Transférer des fonds en dollars américains (USD)';

  @override
  String get doneButton => 'Terminé';

  @override
  String get fundExchangeSpeiTransfer => 'Virement SPEI';

  @override
  String get fundExchangeSpeiSubtitle =>
      'Transférer des fonds en utilisant votre CLABE';

  @override
  String get fundExchangeBankTransfer => 'Virement bancaire';

  @override
  String get fundExchangeBankTransferSubtitle =>
      'Envoyer un virement bancaire depuis votre compte bancaire';

  @override
  String get fundExchangeCopDailyLimitWarning =>
      'Si vous dépassez votre limite de transaction quotidienne, la transaction échouera. Vous devrez contacter le support client.';

  @override
  String get fundExchangeCopSenderName => 'Nom de l\'expéditeur';

  @override
  String get fundExchangeCopIssuingBank => 'Banque émettrice';

  @override
  String get fundExchangeCopSelectBankError =>
      'Veuillez sélectionner une banque émettrice';

  @override
  String get fundExchangeCopAmount => 'Montant';

  @override
  String get fundExchangeCopEnterAmountError => 'Veuillez entrer un montant';

  @override
  String get fundExchangeCopValidAmountError =>
      'Veuillez entrer un montant valide';

  @override
  String get fundExchangeCopGeneratePaymentLink =>
      'Générer le lien de paiement';

  @override
  String get fundExchangeCopRedirectMessage =>
      'Vous serez redirigé vers une page externe pour effectuer le paiement.';

  @override
  String get fundExchangeCopOpenPaymentLink => 'Ouvrir le lien de paiement';

  @override
  String get fundExchangeErrorNetwork =>
      'Vérifiez votre connexion Internet et réessayez.';

  @override
  String get fundExchangeMethodConfidentialSepa => 'SEPA Confidentiel';

  @override
  String get fundExchangeMethodConfidentialSepaSubtitle =>
      'Un IBAN virtuel personnel pour déposer de l\'argent en toute confidentialité';

  @override
  String get networkFeatureUnavailable =>
      'Cette fonctionnalité est indisponible sur le réseau sélectionné.';

  @override
  String get fundExchangeOnlineBillPaymentLabelAccountNumber =>
      'Ajoutez ceci comme numéro de compte';

  @override
  String get fundExchangeOnlineBillPaymentHelpAccountNumber =>
      'Ce numéro de compte unique est créé spécialement pour vous';

  @override
  String get fundExchangeSinpeWarningNoBitcoin => 'Ne mettez pas';

  @override
  String get fundExchangeSinpeWarningNoBitcoinDescription =>
      ' le mot « Bitcoin » ou « Crypto » dans la description du paiement. Cela bloquera votre paiement.';

  @override
  String get exchangeCurrencyDropdownTitle => 'Sélectionner la devise';

  @override
  String get exchangeCurrencyDropdownValidation =>
      'Veuillez sélectionner une devise';

  @override
  String get exchangeAmountInputTitle => 'Entrer le montant';

  @override
  String get exchangeAmountInputValidationEmpty => 'Veuillez entrer un montant';

  @override
  String get exchangeAmountInputValidationInvalid => 'Montant invalide';

  @override
  String get exchangeAmountInputValidationZero =>
      'Le montant doit être supérieur à zéro';

  @override
  String get exchangeAmountInputValidationInsufficient => 'Solde insuffisant';

  @override
  String get exchangeBitcoinWalletsBitcoinAddressLabel => 'Adresse Bitcoin';

  @override
  String get exchangeBitcoinWalletsLightningAddressLabel =>
      'Lightning (adresse LN)';

  @override
  String get exchangeBitcoinWalletsLiquidAddressLabel => 'Adresse Liquid';

  @override
  String get exchangeBitcoinWalletsEnterAddressHint => 'Entrez l\'adresse';

  @override
  String get exchangeBitcoinWalletsSaveSuccess =>
      'Adresse de portefeuille enregistré avec succès';

  @override
  String get exchangeBitcoinWalletsDescription =>
      'Définir les adresses de portefeuille par défaut pour les retraits automatiques Bitcoin.';

  @override
  String get exchangeDcaAddressLabelBitcoin => 'Adresse Bitcoin';

  @override
  String get exchangeDcaAddressLabelLightning => 'Adresse Lightning';

  @override
  String get exchangeDcaAddressLabelLiquid => 'Adresse Liquid';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get save => 'Sauvegarder';

  @override
  String get exchangeBitcoinWalletsLoadFailed =>
      'Impossible de charger les portefeuilles par défaut';

  @override
  String get exchangeBitcoinWalletsAddressEmpty =>
      'L\'adresse ne peut pas être vide';

  @override
  String get exchangeBitcoinWalletsSaveFailed =>
      'Impossible d\'enregistrer l\'adresse du portefeuille';

  @override
  String get exchangeBitcoinWalletsDeleteFailed =>
      'Impossible de supprimer l\'adresse du portefeuille';

  @override
  String destinationExpectedType(String type) {
    return 'Saisissez ou scannez une adresse valide : $type.';
  }

  @override
  String get wizardExchangeTitle => 'BULL Exchange';

  @override
  String get wizardExchangeDescription =>
      'Achetez, vendez et payez avec Bull Bitcoin directement depuis votre portefeuille.';

  @override
  String get settingsTermsOfServiceTitle => 'Conditions d\'utilisation';

  @override
  String get continueButton => 'Continuer';

  @override
  String get autoBuyTitle => 'Achat Automatique';

  @override
  String get autoBuyDescription =>
      'Achetez automatiquement du bitcoin chaque fois que vous déposez des fonds sur votre compte';

  @override
  String get autoBuyActivate => 'Activer achat automatique';

  @override
  String get autoBuyDeactivate => 'Désactiver achat automatique';

  @override
  String get autoBuyCancelTitle => 'Annuler achat automatique ?';

  @override
  String get autoBuyCancelMessage =>
      'Vous n\'achèterez pas automatiquement de bitcoin la prochaine fois que vous alimenterez votre compte.';

  @override
  String get autoBuyDeactivateConfirm => 'Oui, désactiver';

  @override
  String get autoBuyHowItWorks => 'Comment cela fonctionne';

  @override
  String get autoBuyConnectWallet =>
      'Connectez votre portefeuille Bitcoin, Lightning ou Liquid';

  @override
  String get autoBuyPurchaseCreated =>
      'Un achat de Bitcoin est créé automatiquement chaque fois que vous alimentez votre compte Bull Bitcoin.';

  @override
  String get autoBuyBitcoinSent =>
      'Le bitcoin est envoyé directement vers votre propre portefeuille.';

  @override
  String get autoBuyRiskDisclaimer =>
      'L\'exécution de l\'ordre ne peut pas être garantie. Les retards ou changements de prix entre le dépôt et l\'achat peuvent modifier le taux effectif.';

  @override
  String get autoBuyGetStarted => 'Commencer avec achat automatique';

  @override
  String get autoBuyConfirmTitle => 'Confirmer achat automatique';

  @override
  String get autoBuyInfoMessage =>
      'Tout montant ajouté à votre compte sera converti en Bitcoin au taux de change actuel et envoyé à votre portefeuille.';

  @override
  String get autoBuyAccountUnavailableError =>
      'Votre compte Bull Bitcoin n\'est pas disponible. Réessayez plus tard.';

  @override
  String get autoBuyWalletRequiredError =>
      'Ajoutez au moins une adresse Bitcoin, Lightning ou Liquid par défaut.';

  @override
  String get autoBuyUpdateError =>
      'L\'achat automatique n\'a pas pu être mis à jour. Réessayez plus tard.';

  @override
  String get exchangeAuthLoginFailedTitle => 'Échec de la connexion';

  @override
  String get exchangeAuthLoginFailedMessage =>
      'Une erreur s\'est produite, veuillez réessayer de vous connecter.';

  @override
  String get exchangeAuthLoginFailedOkButton => 'OK';

  @override
  String get exchangeTradingUnavailable => 'Les opérations sont indisponibles.';
}
