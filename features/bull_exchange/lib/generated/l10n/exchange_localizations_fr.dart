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

  @override
  String get settingsScreenTitle => 'Paramètres';

  @override
  String get transactionHistoryTitle => 'Historique des transactions';

  @override
  String get exchangeHomeDepositButton => 'Dépôt';

  @override
  String get exchangeHomeWithdrawButton => 'Retrait';

  @override
  String get exchangeDcaUnableToGetConfig =>
      'Impossible d\'obtenir la configuration DCA';

  @override
  String get exchangeDcaDeactivateTitle => 'Désactiver l\'achat récurrent';

  @override
  String get exchangeDcaActivateTitle => 'Activer l\'achat récurrent';

  @override
  String get exchangeDcaHideSettings => 'Masquer les paramètres';

  @override
  String get exchangeDcaViewSettings => 'Voir les paramètres';

  @override
  String get exchangeDcaCancelDialogTitle =>
      'Annuler l\'achat récurrent de Bitcoin ?';

  @override
  String get exchangeDcaCancelDialogMessage =>
      'Votre plan d\'achat récurrent de Bitcoin s\'arrêtera et les achats planifiés prendront fin. Pour recommencer, vous devrez configurer un nouveau plan.';

  @override
  String get exchangeDcaCancelDialogCancelButton => 'Annuler';

  @override
  String get exchangeDcaCancelDialogConfirmButton => 'Oui, désactiver';

  @override
  String get exchangeDcaFrequencyHour => 'heure';

  @override
  String get exchangeDcaFrequencyDay => 'jour';

  @override
  String get exchangeDcaFrequencyWeek => 'semaine';

  @override
  String get exchangeDcaFrequencyMonth => 'mois';

  @override
  String get exchangeDcaNetworkBitcoin => 'Réseau Bitcoin';

  @override
  String get exchangeDcaNetworkLightning => 'Réseau Lightning';

  @override
  String get exchangeDcaNetworkLiquid => 'Réseau Liquid';

  @override
  String exchangeDcaSummaryMessage(
    String amount,
    String frequency,
    String network,
  ) {
    return 'Vous achetez $amount chaque $frequency via $network tant qu\'il y a des fonds dans votre compte.';
  }

  @override
  String exchangeDcaAddressDisplay(String addressLabel, String address) {
    return '$addressLabel : $address';
  }

  @override
  String get exchangeKycLevelLight => 'Légère';

  @override
  String get exchangeKycLevelLimited => 'Limitée';

  @override
  String get exchangeKycCardTitle => 'Complétez votre vérification KYC';

  @override
  String get exchangeKycCardSubtitle =>
      'Pour supprimer les limites de transaction';

  @override
  String get homeActionBuy => 'Acheter';

  @override
  String get homeActionSell => 'Vendre';

  @override
  String get homeActionPay => 'Payer';

  @override
  String get homeActionTransfer => 'Échanger';

  @override
  String get priceChartShowTooltip => 'Afficher le graphique des prix';

  @override
  String get recipientsSearchHint =>
      'Rechercher des destinataires par nom ou étiquette';

  @override
  String get recipientsScreenTitle => 'Sélectionner un destinataire';

  @override
  String get recipientsScreenSubtitle => 'À qui payez-vous ?';

  @override
  String get recipientsTabNew => 'Nouveau destinataire';

  @override
  String get recipientsTabList => 'Mes destinataires fiat';

  @override
  String get recipientsPayoutMethod => 'Méthode de paiement';

  @override
  String get recipientsFilterByJurisdiction => 'Filtrer par juridiction :';

  @override
  String get recipientsListEmpty => 'Aucun destinataire trouvé.';

  @override
  String get recipientsContinue => 'Continuer';

  @override
  String get recipientsJurisdictionAll => 'Toutes les juridictions';

  @override
  String get recipientsJurisdictionCanada => '🇨🇦 Canada';

  @override
  String get recipientsJurisdictionEurope => '🇪🇺 Europe (SEPA)';

  @override
  String get recipientsJurisdictionMexico => '🇲🇽 Mexique';

  @override
  String get recipientsJurisdictionCostaRica => '🇨🇷 Costa Rica';

  @override
  String get recipientsJurisdictionArgentina => '🇦🇷 Argentine';

  @override
  String get recipientsJurisdictionColombia => '🇨🇴 Colombie';

  @override
  String get recipientsTypeInteracEmail => 'Virement par courriel';

  @override
  String get recipientsTypeBillPayment => 'Paiement de facture';

  @override
  String get recipientsTypeBankTransfer => 'Virement bancaire';

  @override
  String get recipientsTypeSepa => 'Virement SEPA';

  @override
  String get recipientsTypeSpeiClabe => 'SPEI CLABE';

  @override
  String get recipientsTypeSpeiSms => 'SPEI SMS';

  @override
  String get recipientsTypeSpeiCard => 'SPEI Carte';

  @override
  String get recipientsTypeSinpeIbanUsd => 'SINPE IBAN (USD)';

  @override
  String get recipientsTypeSinpeIbanCrc => 'SINPE IBAN (CRC)';

  @override
  String get recipientsTypeSinpeMovil => 'SINPE Móvil';

  @override
  String get recipientsTypeBankAccountAr => 'CBU/CVU Argentine';

  @override
  String get recipientsTypeBankAccountCo => 'Compte bancaire COP';

  @override
  String get recipientsTypeNequi => 'Nequi';

  @override
  String get recipientsInfoEmail => 'E-mail';

  @override
  String get recipientsInfoPayee => 'Bénéficiaire';

  @override
  String get recipientsInfoAccount => 'Compte';

  @override
  String get recipientsInfoPhone => 'Téléphone';

  @override
  String get recipientsInfoCard => 'Carte';

  @override
  String get recipientsInfoLabel => 'Libellé';

  @override
  String get recipientsValidationFieldRequired =>
      'Ce champ ne peut pas être vide';

  @override
  String get recipientsLabelOptional => 'Libellé (facultatif)';

  @override
  String get recipientsLabelHint => 'Saisissez un libellé pour ce destinataire';

  @override
  String get recipientsFieldName => 'Nom';

  @override
  String get recipientsFieldNameHint => 'Saisissez le nom du destinataire';

  @override
  String get recipientsFieldRecipientNameLabel => 'Nom du destinataire';

  @override
  String get recipientsFieldPhoneNumber => 'Numéro de téléphone';

  @override
  String get recipientsFieldPhoneNumberHint =>
      'Saisissez le numéro de téléphone';

  @override
  String get recipientsFieldSinpePhoneNumberHint =>
      '8 chiffres sans l\'indicatif du pays';

  @override
  String get recipientsFieldDocumentType =>
      'Type de pièce d\'identité du bénéficiaire';

  @override
  String get recipientsFieldDocumentNumberHint =>
      'Saisir le numéro de pièce d\'identité du bénéficiaire';

  @override
  String get recipientsFieldOwnerName => 'Nom du titulaire';

  @override
  String get recipientsFieldOwnerNameHint => 'Saisissez le nom du titulaire';

  @override
  String get recipientsAccountOwnerQuestion => 'À qui appartient ce compte ?';

  @override
  String get recipientsAccountOwnerMine => 'C\'est mon compte';

  @override
  String get recipientsAccountOwnerSomeoneElse =>
      'C\'est le compte de quelqu\'un d\'autre';

  @override
  String get recipientsFieldIban => 'IBAN';

  @override
  String get recipientsFieldIbanHint => 'Saisissez l\'IBAN';

  @override
  String get recipientsFieldClabe => 'CLABE';

  @override
  String get recipientsFieldClabeHint => 'Saisissez le numéro CLABE';

  @override
  String get recipientsFieldCvuCbu => 'CBU/CVU';

  @override
  String get recipientsFieldCvuCbuHint => 'Saisissez le numéro CVU/CBU';

  @override
  String get recipientsFieldBankInstitution => 'Établissement bancaire';

  @override
  String get recipientsFieldBankInstitutionPlaceholder =>
      'Sélectionnez un établissement bancaire';

  @override
  String get recipientsValidationBankInstitution =>
      'Veuillez sélectionner un établissement bancaire';

  @override
  String get recipientsFieldAccountType => 'Type de compte';

  @override
  String get recipientsAccountTypeSavings => 'Épargne';

  @override
  String get recipientsAccountTypeChecking => 'Courant';

  @override
  String get recipientsFieldBankAccountNumber => 'Numéro de compte bancaire';

  @override
  String get recipientsFieldBankAccountNumberHint =>
      'Saisissez le numéro de compte bancaire';

  @override
  String get recipientsCopDocCc => 'Cédula de Ciudadanía';

  @override
  String get recipientsCopDocCe => 'Cédula de Extranjería';

  @override
  String get recipientsCopDocNit => 'Número de Identificación Tributaria';

  @override
  String get recipientsCopDocPassport => 'Passeport';

  @override
  String get recipientsCopDocTi => 'Tarjeta de Identidad';

  @override
  String get recipientsCopDocRegistroCivil => 'Registro Civil';

  @override
  String get recipientsCopDocCcRecipientNumber =>
      'Numéro de cédula du bénéficiaire';

  @override
  String get recipientsCopDocCeRecipientNumber =>
      'Numéro de cédula de extranjería du bénéficiaire';

  @override
  String get recipientsCopDocNitRecipientNumber =>
      'Numéro d\'identification fiscale du bénéficiaire';

  @override
  String get recipientsCopDocPassportRecipientNumber =>
      'Numéro de passeport du bénéficiaire';

  @override
  String get recipientsCopDocTiRecipientNumber =>
      'Numéro de carte d\'identité du bénéficiaire';

  @override
  String get recipientsCopDocRegistroCivilRecipientNumber =>
      'Numéro d\'état civil du bénéficiaire';

  @override
  String get recipientsFieldDebitCard => 'Numéro de carte de débit';

  @override
  String get recipientsFieldDebitCardHint =>
      'Saisissez le numéro de carte de débit';

  @override
  String get recipientsFieldOwnerNameSinpeHint =>
      'Le nom du titulaire apparaîtra ici';

  @override
  String get recipientsValidationSinpePhoneCountryCode =>
      'Retirez l\'indicatif du pays (+506). Saisissez uniquement le numéro à 8 chiffres';

  @override
  String get recipientsValidationSinpePhoneInvalidChars =>
      'Utilisez uniquement des chiffres (pas de lettres ni de symboles)';

  @override
  String get recipientsValidationSinpePhoneTooShort =>
      'Saisissez les 8 chiffres du numéro de téléphone';

  @override
  String get recipientsValidationSinpeOwner =>
      'Veuillez valider le numéro de téléphone';

  @override
  String get recipientsFieldEmailAddress => 'Adresse e-mail';

  @override
  String get recipientsFieldEmailAddressHint => 'Saisissez l\'adresse e-mail';

  @override
  String get recipientsFieldSecurityQuestion => 'Question de sécurité';

  @override
  String get recipientsFieldSecurityQuestionHint =>
      'Saisissez la question de sécurité (10-40 caractères)';

  @override
  String get recipientsFieldSecurityAnswer => 'Réponse de sécurité';

  @override
  String get recipientsFieldSecurityAnswerHint =>
      'Saisissez la réponse de sécurité';

  @override
  String get recipientsValidationSecurityQuestionMin =>
      'La question de sécurité doit comporter au moins 10 caractères';

  @override
  String recipientsCharCounter(int count) {
    return '$count/40 caractères';
  }

  @override
  String get recipientsFieldInstitutionCode => 'Code de l\'établissement';

  @override
  String get recipientsFieldInstitutionCodeHint =>
      'Saisissez le code de l\'établissement';

  @override
  String get recipientsFieldInstitutionNumber => 'Numéro d\'institution';

  @override
  String get recipientsFieldInstitutionNumberHint =>
      'Saisissez le numéro d\'institution';

  @override
  String get recipientsFieldTransitNumber => 'Numéro de transit';

  @override
  String get recipientsFieldTransitNumberHint =>
      'Saisissez le numéro de transit';

  @override
  String get recipientsFieldAccountNumber => 'Numéro de compte';

  @override
  String get recipientsFieldAccountNumberHint =>
      'Saisissez le numéro de compte';

  @override
  String get recipientsFieldDefaultComment =>
      'Commentaire par défaut (facultatif)';

  @override
  String get recipientsFieldDefaultCommentHint =>
      'Saisissez le commentaire par défaut';

  @override
  String get recipientsFieldCorporateAccount => 'Compte d\'entreprise';

  @override
  String get recipientsFieldFirstName => 'Prénom';

  @override
  String get recipientsFieldFirstNameHint => 'Saisissez le prénom';

  @override
  String get recipientsFieldLastName => 'Nom de famille';

  @override
  String get recipientsFieldLastNameHint => 'Saisissez le nom de famille';

  @override
  String get recipientsFieldCorporateName => 'Raison sociale';

  @override
  String get recipientsFieldCorporateNameHint => 'Saisissez la raison sociale';

  @override
  String get recipientsFieldBillerName => 'Nom du fournisseur';

  @override
  String get recipientsFieldBillerNameHint =>
      'Rechercher et sélectionner un fournisseur';

  @override
  String get recipientsValidationBillerSearchMin =>
      'Saisissez 3 caractères ou plus pour rechercher';

  @override
  String get recipientsValidationBillerSelect =>
      'Veuillez sélectionner un fournisseur dans la liste';

  @override
  String get recipientsFieldPayeeAccountNumber =>
      'Numéro de compte du bénéficiaire';

  @override
  String get recipientsErrorLoadFailed =>
      'Vos bénéficiaires n’ont pas pu être chargés. Veuillez réessayer.';

  @override
  String get recipientsErrorSaveFailed =>
      'Ce bénéficiaire n’a pas pu être enregistré. Vérifiez les informations et réessayez.';

  @override
  String get recipientsErrorSinpeLookupFailed =>
      'Nous n’avons pas pu vérifier ce numéro de téléphone. Vérifiez-le et réessayez.';

  @override
  String get recipientsErrorBillerSearchFailed =>
      'La recherche de facturiers a échoué. Veuillez réessayer.';

  @override
  String get recipientsErrorNetwork =>
      'Vérifiez votre connexion Internet et réessayez.';

  @override
  String get recipientsListPullToRetry => 'Tirez vers le bas pour réessayer.';

  @override
  String get recipientsErrorSavedButNotSelected =>
      'Ce bénéficiaire a été enregistré, mais nous n’avons pas pu continuer. Retrouvez-le dans votre liste pour poursuivre.';

  @override
  String get recipientsTypeConfidentialSepa => 'SEPA Confidentiel';

  @override
  String get recipientsErrorVirtualIbanNotAvailable =>
      'Vous n\'avez pas les autorisations requises pour accéder à cette option de financement. Soit votre KYC est insuffisant, soit cette option n\'est pas disponible pour votre compte';

  @override
  String get recipientsErrorEuResidencyRequired =>
      'Vous devez être résident de l\'Union européenne pour activer le SEPA confidentiel.';

  @override
  String get recipientsConfidentialSepaActivatingTitle =>
      'Activation du destinataire';

  @override
  String get recipientsConfidentialSepaActivatingDescription =>
      'Votre destinataire est en cours d\'activation pour le SEPA Confidentiel. Cela peut prendre quelques minutes.';

  @override
  String get recipientsConfidentialSepaNotActivatedTitle =>
      'Destinataire non activé pour le SEPA Confidentiel';

  @override
  String get recipientsConfidentialSepaNotActivatedDescription =>
      'Ce destinataire n\'est pas encore activé pour le SEPA Confidentiel. Nous l\'activons actuellement. Cela peut prendre quelques minutes. Vous pouvez utiliser le SEPA Instantané et Standard à la place.';

  @override
  String get recipientsConfidentialSepaActivatedTitle => 'Destinataire activé';

  @override
  String get recipientsConfidentialSepaActivatedDescription =>
      'Votre destinataire est désormais actif pour le SEPA Confidentiel.';

  @override
  String get recipientsConfidentialSepaUseRegularSepa =>
      'Utiliser le SEPA Instantané et Standard à la place';

  @override
  String get recipientsReturnHome => 'Return Home';

  @override
  String get recipientsVirtualIbanIntroTitle =>
      'Activer le SEPA Confidentiel ?';

  @override
  String get recipientsVirtualIbanNewBadge => 'Nouveau';

  @override
  String get recipientsVirtualIbanIntroDescription =>
      'Financez votre compte en privé en utilisant un IBAN virtuel personnel à votre nom. C\'est gratuit.';

  @override
  String get recipientsVirtualIbanIntroSelfTransfer =>
      'Lorsque vous envoyez des fonds à Bull Bitcoin depuis votre banque, cela apparaît comme un transfert à vous-même.';

  @override
  String get recipientsVirtualIbanIntroNoTransferCode =>
      'Aucun code de transfert requis.';

  @override
  String get recipientsVirtualIbanNameWarningTitle =>
      'Important : Correspondance des noms requise';

  @override
  String get recipientsVirtualIbanNameWarningDescription =>
      'Le nom du compte bancaire doit correspondre exactement au nom de votre IBAN virtuel Bull Bitcoin, sinon le transfert sera retourné automatiquement. Les noms ne correspondent pas ? Contactez le support.';

  @override
  String get recipientsVirtualIbanAccountOwnerName =>
      'Nom du Titulaire du Compte';

  @override
  String get recipientsVirtualIbanNameConfirmation =>
      'Je confirme que le nom correspond à mon/mes compte(s) bancaire(s)';

  @override
  String get recipientsVirtualIbanActivate => 'Activer le SEPA Confidentiel';

  @override
  String get recipientsVirtualIbanActivatingTitle =>
      'Activation du SEPA Confidentiel...';

  @override
  String get recipientsVirtualIbanActivatingDescription =>
      'Création de votre IBAN virtuel. Cela peut prendre quelques minutes.';

  @override
  String get recipientsVirtualIbanActivatedTitle => 'SEPA Confidentiel Activé';

  @override
  String get recipientsVirtualIbanActivatedDescription =>
      'Vous pouvez maintenant utiliser votre IBAN virtuel personnel pour retirer de l\'argent en toute confidentialité.';

  @override
  String get recipientsVirtualIbanCopied => 'Copié dans le presse-papiers';

  @override
  String get recipientsVirtualIbanDone => 'Terminé';

  @override
  String get recipientsVirtualIbanRecipientName => 'Nom du destinataire';

  @override
  String get recipientsVirtualIbanIbanLabel => 'Numéro de compte IBAN virtuel';

  @override
  String get recipientsVirtualIbanCountry => 'Pays du compte bancaire';

  @override
  String get recipientsVirtualIbanBic => 'Code BIC';

  @override
  String get recipientsVirtualIbanActivatedFundingDescription =>
      'Vous pouvez maintenant utiliser votre IBAN virtuel personnel pour déposer de l\'argent en toute confidentialité.';

  @override
  String get recipientsVirtualIbanShowDetails =>
      'Afficher les détails de mon IBAN virtuel';

  @override
  String get recipientsVirtualIbanDetailsDescription =>
      'Alimentez votre compte en toute confidentialité en utilisant un IBAN virtuel personnel à votre nom. Le dépôt apparaîtra comme un paiement à vous-même, sans code de transfert requis.';

  @override
  String get recipientsVirtualIbanBankAddress => 'Adresse de la banque';

  @override
  String get recipientsVirtualIbanBankAddressHelp =>
      'L\'adresse officielle de la banque, au cas où elle serait requise par votre banque.';

  @override
  String get recipientsConfidentialSepaNameMustMatchHint =>
      'Les noms doivent correspondre entre votre banque et votre IBAN virtuel, sinon les virements seront automatiquement retournés.';

  @override
  String get recipientsFieldBankAccountIban =>
      'Numéro de compte bancaire (IBAN)';

  @override
  String get recipientsTypeConfidentialSepaDescription =>
      'Les retraits apparaissent comme un virement à vous-même au nom de votre compte';

  @override
  String get withdrawAmountTitle => 'Retirer des fonds fiat';

  @override
  String get withdrawAmountContinue => 'Continuer';

  @override
  String get withdrawConfirmTitle => 'Confirmer le retrait';

  @override
  String get withdrawConfirmRecipientName => 'Nom du destinataire';

  @override
  String get withdrawConfirmAmount => 'Montant';

  @override
  String get withdrawConfirmEmail => 'Courriel';

  @override
  String get withdrawConfirmPayee => 'Bénéficiaire';

  @override
  String get withdrawConfirmAccount => 'Compte';

  @override
  String get withdrawConfirmIban => 'IBAN';

  @override
  String get withdrawConfirmClabe => 'CLABE';

  @override
  String get withdrawConfirmPhone => 'Téléphone';

  @override
  String get withdrawConfirmCard => 'Carte';

  @override
  String get withdrawConfirmButton => 'Confirmer le retrait';

  @override
  String get withdrawSuccessTitle => 'Retrait initié';

  @override
  String get withdrawSuccessOrderDetails => 'Détails de la commande';

  @override
  String get withdrawConfirmBankAccount => 'Compte bancaire';

  @override
  String get withdrawOwnershipQuestion => 'À qui appartient ce compte ?';

  @override
  String get withdrawOwnershipMyAccount => 'C\'est mon compte';

  @override
  String get withdrawOwnershipOtherAccount =>
      'C\'est le compte de quelqu\'un d\'autre';

  @override
  String get withdrawUnauthenticatedError =>
      'Vous n\'êtes pas authentifié. Veuillez vous connecter pour continuer.';

  @override
  String withdrawBelowMinAmountError(String amount, String currency) {
    return 'Le montant minimum est $amount $currency';
  }

  @override
  String withdrawAboveMaxAmountError(String amount, String currency) {
    return 'Le montant maximum est $amount $currency';
  }

  @override
  String get withdrawInteracSecurityDetailsTitle =>
      'Détails de sécurité du virement';

  @override
  String get withdrawInteracSaveAsDefault =>
      'Enregistrer ces renseignements par défaut';

  @override
  String get withdrawInteracSecurityQuestionLengthError =>
      'La question de sécurité doit contenir de 3 à 40 caractères';

  @override
  String get withdrawInteracSecurityAnswerLengthError =>
      'La réponse de sécurité doit contenir de 3 à 40 caractères';

  @override
  String get withdrawInteracSecurityAnswerFormatError =>
      'Utilisez des lettres, des chiffres ou des traits d’union sans espaces';

  @override
  String get withdrawUnexpectedError =>
      'Votre retrait n\'a pas pu être finalisé pour le moment. Veuillez réessayer ou contacter le support.';

  @override
  String get withdrawConfidentialSepaNotActivatedError =>
      'Veuillez activer l\'option de paiement confidentiel pour ce destinataire SEPA.';

  @override
  String get limitOrdersTitle => 'Limit orders';

  @override
  String get limitOrdersActiveTitle => 'Active limit orders';

  @override
  String get limitOrdersCreateNew => 'Create new';

  @override
  String get limitOrdersMaximumActiveHint =>
      'Cancel an active order before creating another one.';

  @override
  String limitOrdersBuyAt(String price) {
    return 'Buy at $price';
  }

  @override
  String get limitOrdersCancelAll => 'Cancel all';

  @override
  String get limitOrdersCancelAllTitle => 'Cancel all active limit orders?';

  @override
  String get limitOrdersCancelAllMessage =>
      'This is permanent. None of these orders will execute after cancellation.';

  @override
  String get limitOrdersDialogConfirm => 'Confirm';

  @override
  String get limitOrdersDone => 'Done';

  @override
  String get limitOrdersTargetPrice => 'Target price';

  @override
  String get limitOrdersFiatAmount => 'Amount';

  @override
  String get limitOrdersEstimatedBuyPrice => 'Estimated buy price';

  @override
  String get limitOrderDetailsTitle => 'Limit order details';

  @override
  String get limitOrderDetailsStatus => 'Status';

  @override
  String get limitOrderDetailsNumber => 'Order number';

  @override
  String get limitOrderDetailsAddress => 'Payout address';

  @override
  String get limitOrderDetailsCreated => 'Created';

  @override
  String get limitOrderDetailsExpires => 'Expires';

  @override
  String get limitOrderCancel => 'Cancel limit order';

  @override
  String get limitOrderCancelTitle => 'Cancel this limit order?';

  @override
  String get limitOrderCancelMessage =>
      'Cancellation is permanent and this order will no longer execute.';

  @override
  String get limitOrderStatusActive => 'Active';

  @override
  String get limitOrderStatusExecuted => 'Executed';

  @override
  String get limitOrderStatusCancelled => 'Cancelled';

  @override
  String get limitOrderStatusExpired => 'Expired';

  @override
  String get limitOrderStatusFailed => 'Failed';

  @override
  String get limitOrdersAccountUnavailableError =>
      'Your Bull Bitcoin account or balances could not be loaded. Please try again.';

  @override
  String get limitOrderNotFoundError => 'This limit order could not be found.';

  @override
  String get limitOrdersLoadError =>
      'Limit orders could not be loaded. Please try again.';

  @override
  String get limitOrderCancellationError =>
      'The limit order could not be cancelled. Please try again.';

  @override
  String get limitOrderDetailsEstimatedBitcoin => 'Estimated bitcoin';

  @override
  String get limitOrdersMaximumActiveError =>
      'You already have five active limit orders. Cancel one before creating another.';

  @override
  String get limitOrderInvalidAddressError =>
      'The selected payout address is not valid.';

  @override
  String get limitOrderCreationError =>
      'The limit order could not be created. Please try again.';

  @override
  String get exchangeSettingsLogOutTitle => 'Se déconnecter';

  @override
  String get logoutConfirmationTitle => 'Confirmer la déconnexion';

  @override
  String get logoutConfirmationDescription =>
      'Êtes-vous sûr de vouloir vous déconnecter de votre compte Bull Bitcoin? Vous devrez vous reconnecter pour accéder aux fonctionnalités d\'échange.';

  @override
  String get logoutConfirmationCancel => 'Annuler';

  @override
  String get logoutConfirmationLogout => 'Déconnexion';

  @override
  String get exchangeSettingsDeleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmationDescription =>
      'Cela enverra une demande de suppression de compte à notre équipe de support. Votre compte sera supprimé sous 5 jours ouvrables.';

  @override
  String get deleteAccountConfirmationCancel => 'Cancel';

  @override
  String get deleteAccountConfirmationDelete => 'Delete Account';

  @override
  String get deleteAccountSuccessTitle => 'Suppression de compte demandée';

  @override
  String get deleteAccountSuccessDescription =>
      'Votre demande de suppression de compte a été effectuée. Elle sera traitée sous 5 jours ouvrables.';

  @override
  String get deleteAccountSuccessClose => 'Close';

  @override
  String get buyEnterAmount => 'Entrez le montant';

  @override
  String get buyPaymentMethod => 'Méthode de paiement';

  @override
  String get buyMax => 'Max';

  @override
  String get buySelectWallet => 'Sélectionner le portefeuille';

  @override
  String get buyEnterBitcoinAddress => 'Entrez l\'adresse Bitcoin';

  @override
  String get buyBitcoinAddressHint => 'BC1QYL7J673H...6Y6ALV70M0';

  @override
  String get buyConfirmPurchase => 'Confirmer l\'achat';

  @override
  String buyYouBought(String amount, String fiatAmount) {
    return 'Vous avez acheté $amount pour $fiatAmount';
  }

  @override
  String get buyPayoutWillBeSentIn => 'Votre paiement sera envoyé dans ';

  @override
  String get buyViewDetails => 'Voir les détails';

  @override
  String get buyAccelerateTransaction => 'Accélérer la transaction';

  @override
  String get buyGetConfirmedFaster => 'Faites-la confirmer plus rapidement';

  @override
  String get buyConfirmExpressWithdrawal => 'Confirmer le retrait express';

  @override
  String get buyNetworkFeeExplanation =>
      'Les frais de réseau Bitcoin seront déduits du montant que vous recevez et collectés par les mineurs de Bitcoin';

  @override
  String get buyNetworkFees => 'Frais de réseau';

  @override
  String get buyEstimatedFeeValue => 'Valeur estimée des frais';

  @override
  String get buyNetworkFeeRate => 'Taux des frais de réseau';

  @override
  String get buyConfirmationTime => 'Temps de confirmation';

  @override
  String get buyConfirmationTimeValue => '~10 minutes';

  @override
  String get buyWaitForFreeWithdrawal => 'Attendre le retrait gratuit';

  @override
  String get buyConfirmExpress => 'Confirmer l\'express';

  @override
  String get buyBitcoinSent => 'Bitcoin envoyé !';

  @override
  String get buyThatWasFast => 'C\'était rapide, n\'est-ce pas ?';

  @override
  String get globalDefaultBitcoinWalletLabel => 'Bitcoin sécurisé';

  @override
  String get globalDefaultLiquidWalletLabel => 'Paiements instantanés';

  @override
  String get dcaSuccessTitle => 'Achat récurrent activé !';

  @override
  String dcaSuccessMessageHourly(String amount) {
    return 'Vous achèterez $amount chaque heure';
  }

  @override
  String dcaSuccessMessageDaily(String amount) {
    return 'Vous achèterez $amount chaque jour';
  }

  @override
  String dcaSuccessMessageWeekly(String amount) {
    return 'Vous achèterez $amount chaque semaine';
  }

  @override
  String dcaSuccessMessageMonthly(String amount) {
    return 'Vous achèterez $amount chaque mois';
  }

  @override
  String get dcaBackToHomeButton => 'Retour à l\'accueil';

  @override
  String get dcaChooseWalletTitle => 'Choisir un portefeuille Bitcoin';

  @override
  String get dcaWalletSelectionDescription =>
      'Les achats de Bitcoin seront effectués automatiquement selon ce calendrier.';

  @override
  String get dcaNetworkValidationError => 'Veuillez sélectionner un réseau';

  @override
  String get dcaEnterLightningAddressLabel => 'Entrer une adresse Lightning';

  @override
  String get dcaUseDefaultLightningAddress =>
      'Utiliser mon adresse Lightning par défaut.';

  @override
  String get dcaWalletSelectionContinueButton => 'Continuer';

  @override
  String get dcaSelectFrequencyLabel => 'Sélectionner la fréquence';

  @override
  String get dcaSelectWalletTypeLabel =>
      'Sélectionner le type de portefeuille Bitcoin';

  @override
  String get dcaWalletTypeBitcoin => 'Bitcoin (BTC)';

  @override
  String get dcaWalletTypeLightning => 'Lightning Network (LN)';

  @override
  String get dcaWalletTypeLiquid => 'Liquid (LBTC)';

  @override
  String get dcaWalletBitcoinSubtitle => 'Minimum 0,001 BTC';

  @override
  String get dcaWalletLightningSubtitle =>
      'Nécessite un portefeuille compatible, maximum 0,25 BTC';

  @override
  String get dcaWalletLiquidSubtitle => 'Nécessite un portefeuille compatible';

  @override
  String get dcaSetupTitle => 'Configurer l\'achat récurrent';

  @override
  String get dcaSetupInsufficientBalance => 'Solde insuffisant';

  @override
  String get dcaSetupInsufficientBalanceMessage =>
      'Vous n\'avez pas assez de solde pour créer cette commande.';

  @override
  String get dcaSetupFundAccount => 'Financer votre compte';

  @override
  String get dcaSetupScheduleMessage =>
      'Les achats de Bitcoin seront placés automatiquement selon ce calendrier.';

  @override
  String get dcaSetupFrequencyError => 'Veuillez sélectionner une fréquence';

  @override
  String get dcaSetupContinue => 'Continuer';

  @override
  String get dcaConfirmTitle => 'Confirmer l\'achat récurrent';

  @override
  String get dcaConfirmAutoMessage =>
      'Les ordres d\'achat seront placés automatiquement selon ces paramètres. Vous pouvez les désactiver à tout moment.';

  @override
  String get dcaConfirmFrequency => 'Fréquence';

  @override
  String get dcaConfirmFrequencyHourly => 'Toutes les heures';

  @override
  String get dcaConfirmFrequencyDaily => 'Tous les jours';

  @override
  String get dcaConfirmFrequencyWeekly => 'Toutes les semaines';

  @override
  String get dcaConfirmFrequencyMonthly => 'Tous les mois';

  @override
  String get dcaConfirmAmount => 'Montant';

  @override
  String get dcaConfirmPaymentMethod => 'Méthode de paiement';

  @override
  String dcaConfirmPaymentBalance(String currency) {
    return 'Solde $currency';
  }

  @override
  String get dcaConfirmOrderType => 'Type de commande';

  @override
  String get dcaConfirmOrderTypeValue => 'Achat récurrent';

  @override
  String get dcaConfirmNetwork => 'Réseau';

  @override
  String get dcaConfirmNetworkBitcoin => 'Bitcoin';

  @override
  String get dcaConfirmNetworkLightning => 'Lightning';

  @override
  String get dcaConfirmNetworkLiquid => 'Liquid';

  @override
  String get dcaConfirmLightningAddress => 'Adresse Lightning';

  @override
  String get dcaConfirmContinue => 'Continuer';

  @override
  String get buyInputTitle => 'Acheter du Bitcoin';

  @override
  String get buyInputMinAmountError => 'Vous devez acheter au moins';

  @override
  String get buyInputMaxAmountError => 'Vous ne pouvez pas acheter plus de';

  @override
  String get buyInputKycPending => 'Vérification d\'identité KYC en attente';

  @override
  String get buyInputKycMessage =>
      'Vous devez d\'abord compléter la vérification d\'identité';

  @override
  String get buyInputCompleteKyc => 'Compléter le KYC';

  @override
  String get buyInputInsufficientBalance => 'Solde insuffisant';

  @override
  String get buyInputInsufficientBalanceMessage =>
      'Vous n\'avez pas assez de solde pour créer cette commande.';

  @override
  String get buyInputFundAccount => 'Financer votre compte';

  @override
  String get buyInputContinue => 'Continuer';

  @override
  String get buyConfirmTitle => 'Acheter du Bitcoin';

  @override
  String get buyConfirmYouPay => 'Vous payez';

  @override
  String get buyConfirmYouReceive => 'Vous recevez';

  @override
  String get buyConfirmBitcoinPrice => 'Prix du Bitcoin';

  @override
  String get buyConfirmPayoutWallet => 'Portefeuille de paiement';

  @override
  String get buyConfirmPayoutMethod => 'Méthode de paiement';

  @override
  String get buyPayoutMethodLiquid => 'L-BTC sur Liquid';

  @override
  String get buyPayoutMethodBitcoin => 'BTC sur la chaîne Bitcoin';

  @override
  String get buyConfirmExternalWallet => 'Portefeuille Bitcoin externe';

  @override
  String get buyConfirmAwaitingConfirmation => 'En attente de confirmation ';

  @override
  String get buyUnauthenticatedError =>
      'Vous n\'êtes pas authentifié. Veuillez vous connecter pour continuer.';

  @override
  String get buyBelowMinAmountError =>
      'Vous essayez d\'acheter en dessous du montant minimum.';

  @override
  String get buyAboveMaxAmountError =>
      'Vous essayez d\'acheter au-dessus du montant maximum.';

  @override
  String get buyUnexpectedError =>
      'Votre ordre n\'a pas pu être créé pour le moment. Veuillez réessayer ou contacter le support.';

  @override
  String get dcaAccountUnavailableError =>
      'Impossible de charger votre compte. Vérifiez votre connexion, assurez-vous d\'être connecté et réessayez.';

  @override
  String get dcaLightningAddressRequiredError =>
      'Saisissez une adresse Lightning pour recevoir vos achats.';

  @override
  String get dcaReceiveAddressError =>
      'Impossible de préparer une adresse de réception dans votre portefeuille. Veuillez réessayer.';

  @override
  String get dcaOrderCreationError =>
      'L\'achat récurrent n\'a pas pu être créé. Veuillez réessayer plus tard.';

  @override
  String get payjoinInProgress => 'Payjoin en cours';

  @override
  String get payjoinSucceeded => 'Payjoin réussi';

  @override
  String get payjoinBuyRegularSend =>
      'Bitcoin envoyé à votre portefeuille par une transaction ordinaire';

  @override
  String get payjoinUseToggle => 'Utiliser Payjoin';

  @override
  String get limitOrdersLightningAddressHint => 'you@domain.com';

  @override
  String get exchangeQuoteUnavailableError =>
      'Impossible d\'obtenir un nouveau prix. Réessayez, ou revenez en arrière pour créer un nouvel ordre.';

  @override
  String get buyQuoteExpiredError =>
      'Ce prix a expiré. Un nouveau prix est en cours de chargement ; vérifiez-le avant de confirmer.';

  @override
  String get sellTitle => 'Vendre du Bitcoin';

  @override
  String get sellSelectWallet => 'Sélectionner le portefeuille';

  @override
  String get sellWhichWalletQuestion =>
      'De quel portefeuille voulez-vous vendre ?';

  @override
  String get sellExternalWallet => 'Portefeuille externe';

  @override
  String get sellFromAnotherWallet =>
      'Vendre depuis un autre portefeuille Bitcoin';

  @override
  String get sellAboveMaxAmountError =>
      'Vous essayez de vendre au-dessus du montant maximum qui peut être vendu avec ce portefeuille.';

  @override
  String get sellBelowMinAmountError =>
      'Vous essayez de vendre en dessous du montant minimum qui peut être vendu avec ce portefeuille.';

  @override
  String get sellInsufficientBalanceError =>
      'Solde insuffisant dans le portefeuille sélectionné pour compléter cette commande de vente.';

  @override
  String get sellUnauthenticatedError =>
      'Vous n\'êtes pas authentifié. Veuillez vous connecter pour continuer.';

  @override
  String get sellOrderNotFoundError =>
      'La commande de vente n\'a pas été trouvée. Veuillez réessayer.';

  @override
  String get sellOrderAlreadyConfirmedError =>
      'Cette commande de vente a déjà été confirmée.';

  @override
  String get sellSelectNetwork => 'Sélectionner le réseau';

  @override
  String get sellHowToPayInvoice => 'Comment voulez-vous payer cette facture ?';

  @override
  String get sellBitcoinOnChain => 'Bitcoin on-chain';

  @override
  String get sellLightningNetwork => 'Réseau Lightning';

  @override
  String get sellLiquidNetwork => 'Réseau Liquid';

  @override
  String get sellConfirmPayment => 'Confirmer le paiement';

  @override
  String get sellPriceWillRefreshIn => 'Le prix sera actualisé dans ';

  @override
  String get sellOrderNumber => 'Numéro de commande';

  @override
  String get sellPayoutRecipient => 'Bénéficiaire du paiement';

  @override
  String get sellCadBalance => 'Solde CAD';

  @override
  String get sellCrcBalance => 'Solde CRC';

  @override
  String get sellEurBalance => 'Solde EUR';

  @override
  String get sellUsdBalance => 'Solde USD';

  @override
  String get sellMxnBalance => 'Solde MXN';

  @override
  String get sellArsBalance => 'Solde ARS';

  @override
  String get sellCopBalance => 'Solde COP';

  @override
  String get sellPayinAmount => 'Montant à payer';

  @override
  String get sellPayoutAmount => 'Montant à recevoir';

  @override
  String get sellExchangeRate => 'Taux de change';

  @override
  String get sellPayFromWallet => 'Payer depuis le portefeuille';

  @override
  String get sellInstantPayments => 'Paiements instantanés';

  @override
  String get sellSecureBitcoinWallet => 'Portefeuille Bitcoin sécurisé';

  @override
  String get sellFeePriority => 'Priorité des frais';

  @override
  String get sellFastest => 'Le plus rapide';

  @override
  String get sellAdvancedSettings => 'Paramètres avancés';

  @override
  String get sellAdvancedOptions => 'Options avancées';

  @override
  String get sellReplaceByFeeActivated => 'Remplacement par frais activé';

  @override
  String get sellSelectCoinsManually => 'Sélectionner les pièces manuellement';

  @override
  String get sellDone => 'Terminé';

  @override
  String get sellPleasePayInvoice => 'Veuillez payer cette facture';

  @override
  String get sellBitcoinAmount => 'Montant Bitcoin';

  @override
  String get sellCopyInvoice => 'Copier la facture';

  @override
  String get sellShowQrCode => 'Afficher le code QR';

  @override
  String get sellQrCode => 'Code QR';

  @override
  String get sellNoInvoiceData => 'Aucune donnée de facture disponible';

  @override
  String get sellInProgress => 'Vente en cours...';

  @override
  String get sellGoHome => 'Aller à l\'accueil';

  @override
  String get sellOrderCompleted => 'Commande terminée !';

  @override
  String get sellBalanceWillBeCredited =>
      'Le solde de votre compte sera crédité après que votre transaction reçoive 1 confirmation on-chain.';

  @override
  String sellYouSold(String amount, String fiatAmount) {
    return 'You sold $amount for $fiatAmount';
  }

  @override
  String get payTitle => 'Payer';

  @override
  String get payDescriptionLabel => 'Description du paiement (facultatif)';

  @override
  String get payDescriptionHint => 'Ajoutez une note à ce paiement';

  @override
  String get payPaymentDescription => 'Description du paiement';

  @override
  String get payRecipientType => 'Type de destinataire';

  @override
  String get payRecipientName => 'Nom du destinataire';

  @override
  String get payRecipientDetails => 'Détails du destinataire';

  @override
  String get payNoDetailsAvailable => 'Aucun détail disponible';

  @override
  String get paySelectWallet => 'Sélectionner le Portefeuille';

  @override
  String get payExternalWallet => 'Portefeuille externe';

  @override
  String payAboveMaxAmountError(String amount) {
    return 'Le montant maximum que vous pouvez payer avec ce portefeuille est de $amount.';
  }

  @override
  String payBelowMinAmountError(String amount) {
    return 'Le montant minimum que vous pouvez payer avec ce portefeuille est de $amount.';
  }

  @override
  String get payInsufficientBalanceError =>
      'Solde insuffisant dans le portefeuille sélectionné pour compléter cette commande de paiement.';

  @override
  String get payUnauthenticatedError =>
      'Vous n\'êtes pas authentifié. Veuillez vous connecter pour continuer.';

  @override
  String get paySelectNetwork => 'Sélectionner le réseau';

  @override
  String get payHowToPayInvoice => 'Comment voulez-vous payer cette facture ?';

  @override
  String get payLightningNetwork => 'Réseau Lightning';

  @override
  String get payLiquidNetwork => 'Réseau Liquid';

  @override
  String get payConfirmPayment => 'Confirmer le Paiement';

  @override
  String get payOrderNumber => 'Numéro de commande';

  @override
  String get payPayinAmount => 'Montant à payer';

  @override
  String get payPayoutAmount => 'Montant à recevoir';

  @override
  String get payExchangeRate => 'Taux de change';

  @override
  String get payPayFromWallet => 'Payer depuis le portefeuille';

  @override
  String get payInstantPayments => 'Paiements instantanés';

  @override
  String get paySecureBitcoinWallet => 'Portefeuille Bitcoin sécurisé';

  @override
  String get payFeePriority => 'Priorité des frais';

  @override
  String get payFastest => 'Le plus rapide';

  @override
  String get payNetworkFees => 'Frais de réseau';

  @override
  String get payAdvancedSettings => 'Paramètres avancés';

  @override
  String get payAdvancedOptions => 'Options avancées';

  @override
  String get paySelectCoinsManually => 'Sélectionner les pièces manuellement';

  @override
  String get payDone => 'Terminé';

  @override
  String get payContinue => 'Continuer';

  @override
  String get payPleasePayInvoice => 'Veuillez payer cette facture';

  @override
  String get payBitcoinAmount => 'Montant Bitcoin';

  @override
  String get payBitcoinPrice => 'Prix du Bitcoin';

  @override
  String get payCopyInvoice => 'Copier la Facture';

  @override
  String get payShowQrCode => 'Afficher le code QR';

  @override
  String get payQrCode => 'Code QR';

  @override
  String get payNoInvoiceData => 'Aucune donnée de facture disponible';

  @override
  String get payInvalidState => 'État invalide';

  @override
  String get payViewDetails => 'Voir les détails';

  @override
  String get paySinpeReceipt => 'Reçu SINPE';

  @override
  String get payCompleted => 'Paiement terminé !';

  @override
  String payCompletedDescriptionDetails(String fiatAmount, String recipient) {
    return 'The payment of $fiatAmount to $recipient has been completed.';
  }

  @override
  String get paySinpeEnviado => 'SINPE ENVIADO !';

  @override
  String get payOrderDetails => 'Détails de la commande';

  @override
  String get paySinpeMonto => 'Montant';

  @override
  String get paySinpeNumeroOrden => 'Numéro de commande';

  @override
  String get paySinpeNumeroComprobante => 'Numéro de référence';

  @override
  String get paySinpeBeneficiario => 'Bénéficiaire';

  @override
  String get paySinpeOrigen => 'Origine';

  @override
  String get payNotAvailable => 'N/D';

  @override
  String get payBitcoinOnchain => 'Bitcoin on-chain';

  @override
  String get payPaymentInProgress => 'Paiement en cours!';

  @override
  String payPaymentInProgressDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'The payment of $fiatAmount to $recipient will be sent after your transaction receives 1 confirmation onchain.';
  }

  @override
  String payPaymentPayinConfirmedDescriptionDetails(
    String fiatAmount,
    String recipient,
  ) {
    return 'Your transaction is confirmed. The payment of $fiatAmount to $recipient is being processed.';
  }

  @override
  String get payPriceRefreshIn => 'Le prix sera actualisé dans ';

  @override
  String get payWhichWallet => 'De quel portefeuille souhaitez-vous payer?';

  @override
  String get payExternalWalletDescription =>
      'Payer depuis un autre portefeuille Bitcoin';

  @override
  String get payRbfActivated => 'Replace-by-fee activé';

  @override
  String get copyDialogButton => 'Copier';

  @override
  String get closeDialogButton => 'Fermer';

  @override
  String get sellCompleteKYC => 'Compléter le KYC';

  @override
  String get sellSendPaymentNetworkFees => 'Frais de réseau';

  @override
  String get sellSendPaymentContinue => 'Continuer';

  @override
  String get exchangeSendingPayment => 'Sending payment…';

  @override
  String get exchangePaymentSentRefreshingOrder =>
      'Payment sent, refreshing your order…';

  @override
  String get sellBitcoinPriceLabel => 'Prix Bitcoin';

  @override
  String get sellViewDetailsButton => 'Voir les détails';

  @override
  String get sellKycPendingTitle => 'Vérification KYC en attente';

  @override
  String get sellKycPendingDescription =>
      'Vous devez d\'abord compléter la vérification d\'identité';

  @override
  String get sellLoadingGeneric => 'Chargement...';

  @override
  String get viewerTapToCopy => 'Appuyez pour copier';

  @override
  String get invoiceViewerTitle => 'Facture';

  @override
  String get payjoinViaPayjoin => 'via Payjoin';

  @override
  String get payjoinViaRegularSend => 'par une transaction ordinaire';

  @override
  String get sellDepositAddress => 'Adresse de dépôt';

  @override
  String get payDepositAddress => 'Adresse de dépôt';

  @override
  String get sellDepositAddressChangedError =>
      'L\'adresse de dépôt de cet ordre a changé de façon inattendue. Pour votre sécurité, ne payez pas cet ordre : revenez en arrière et créez-en un nouveau.';

  @override
  String get payDepositAddressChangedError =>
      'L\'adresse de dépôt de cet ordre a changé de façon inattendue. Pour votre sécurité, ne payez pas cet ordre : revenez en arrière et créez-en un nouveau.';

  @override
  String get sellUnexpectedError =>
      'Votre ordre de vente n\'a pas pu être finalisé pour le moment. Veuillez réessayer ou contacter le support.';

  @override
  String get sellErrorFeeBelowRelayFloor =>
      'Frais de réseau trop bas. Choisissez des frais plus élevés.';

  @override
  String get sellErrorFeesUnavailable =>
      'Les frais de réseau n\'ont pas pu être chargés. Vérifiez votre connexion et réessayez.';

  @override
  String get payUnexpectedError =>
      'Your payment could not be completed right now. Please try again or contact support.';

  @override
  String get payErrorFeeBelowRelayFloor =>
      'Network fee too low. Choose a higher fee.';

  @override
  String get payErrorFeesUnavailable =>
      'Network fees could not be loaded. Check your connection and try again.';

  @override
  String get withdrawRecipientsPrompt =>
      'Where and how should we send the money?';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get sellQuoteExpiredError =>
      'Ce prix a expiré. Un nouveau prix est en cours de chargement ; vérifiez-le avant de confirmer.';

  @override
  String get exchangePaymentSentPastDeadline =>
      'Paiement envoyé. L’exchange indique que le délai de paiement de cette commande a expiré. Conservez l’identifiant de transaction ci-dessous et contactez le support si la commande n’est pas mise à jour.';

  @override
  String get exchangePaymentSentLeave => 'Quitter';

  @override
  String get payQuoteExpiredError =>
      'Ce prix a expiré. Un nouveau prix est en cours de chargement ; vérifiez-le avant de confirmer.';

  @override
  String get sellPayoutBalance => 'Ajouter à mon solde de compte';

  @override
  String get sellPayoutSepaDescription =>
      'Les retraits apparaissent comme envoyés par Leonod';

  @override
  String get sellPayoutTitle => 'Sélectionner le destinataire';

  @override
  String get sellPayoutNewBadge => 'NOUVEAU';

  @override
  String get walletSpendAwaitingObservation =>
      'Les dépenses sont indisponibles tant que ce portefeuille n’est pas synchronisé et n’a pas vu ses paiements précédents sur le réseau. Actualisez le portefeuille ou recherchez les transactions manquantes, puis réessayez.';

  @override
  String get sendPayjoinSpendPaused =>
      'Ce paiement Payjoin est en pause car le portefeuille ne peut pas continuer en toute sécurité. Ses entrées restent réservées. Actualisez le portefeuille ou utilisez Rechercher les transactions manquantes, puis réessayez cette proposition tant qu’elle est valide. Si elle a expiré, vérifiez le paiement dans Transactions avant toute autre action.';

  @override
  String get walletSpendBusy =>
      'Le portefeuille est occupé. Réessayez dans un instant.';

  @override
  String get broadcastSignedTxErrorOutcomeUnknown =>
      'Impossible de confirmer que votre transaction a été diffusée. Vérifiez dans un explorateur de blocs avant de réessayer.';

  @override
  String get sendSelectedUtxosInsufficient =>
      'Les UTXO sélectionnés ne couvrent pas le montant requis';

  @override
  String get selectAmountTitle => 'Sélectionner le montant';

  @override
  String amountRequestedLabel(String amount) {
    return 'Montant demandé : $amount';
  }

  @override
  String get addressLabel => 'Adresse : ';

  @override
  String get typeLabel => 'Type : ';

  @override
  String get coinsKeychainReceive => 'Réception';

  @override
  String get coinsKeychainChange => 'Monnaie';
}
