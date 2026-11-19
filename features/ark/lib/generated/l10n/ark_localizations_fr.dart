// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'ark_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ArkLocalizationsFr extends ArkLocalizations {
  ArkLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get title => 'Ark';

  @override
  String get loading => 'Chargement d’Ark…';

  @override
  String get unavailable => 'Ark est indisponible. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get spendable => 'Disponible';

  @override
  String get pending => 'En attente';

  @override
  String get reserve => 'Réserve de frais on-chain';

  @override
  String get stale =>
      'Dernières données observées. Actualisez avant de vérifier un paiement.';

  @override
  String get unknown => 'Indisponible';

  @override
  String get renewalWarning =>
      'Vos VTXO doivent être renouvelés. Ouvrez Ark pour protéger vos fonds.';

  @override
  String get expiryTitle => 'Urgent : vos fonds Ark expirent bientôt';

  @override
  String get expiryBody =>
      'Ouvrez Ark pour vérifier et renouveler vos VTXO. Le rythme des blocs et les tâches en arrière-plan varient.';

  @override
  String get renewalDelegated =>
      'Renouvellement lancé. L’alerte reste affichée jusqu’à l’observation des nouveaux VTXO.';

  @override
  String get offFunded =>
      'Ark est désactivé pour les nouveaux paiements. Les fonds existants nécessitent toujours un renouvellement et la récupération reste accessible.';

  @override
  String get privacy =>
      'Ark se connecte directement sans Tor. Les fournisseurs Ark et Esplora configurés peuvent voir votre IP et vos requêtes de wallet. Le secours est utilisé uniquement si le fournisseur principal est injoignable, avec la même exposition.';

  @override
  String get enable => 'Activer Ark';

  @override
  String get disable => 'Désactiver les nouveaux paiements';

  @override
  String get acceptPrivacy => 'Je comprends la connexion directe';

  @override
  String get send => 'Envoyer';

  @override
  String get receive => 'Recevoir';

  @override
  String get board => 'Ajouter des fonds';

  @override
  String get vtxos => 'VTXO';

  @override
  String get history => 'Activité';

  @override
  String get info => 'Informations du serveur';

  @override
  String get exits => 'Sortie d’urgence';

  @override
  String get destination => 'Adresse de paiement ou facture BOLT11';

  @override
  String get amount => 'Montant en sats';

  @override
  String get review => 'Vérifier';

  @override
  String get confirm => 'Confirmer';

  @override
  String get fee => 'Frais';

  @override
  String get net => 'Montant net';

  @override
  String get cancel => 'Annuler';

  @override
  String get pendingOperation =>
      'Opération soumise. Une mise à jour observée doit confirmer sa fin.';

  @override
  String get uncertain =>
      'Résultat inconnu. Actualisez pour vérifier cette opération avant de réessayer.';

  @override
  String get invalid => 'Vérifiez la destination et le montant.';

  @override
  String get disabled =>
      'Activez Ark avant de créer un paiement ou une demande de réception.';

  @override
  String get expired =>
      'Cette vérification a expiré. Demandez une nouvelle estimation.';

  @override
  String get busy =>
      'Ark est occupé. Attendez l’opération en cours ou redémarrez l’application si elle a été interrompue.';

  @override
  String get recovery =>
      'La récupération doit être terminée avant de dépenser. Les fonds existants ont été conservés.';

  @override
  String get insufficient => 'Fonds insuffisants, frais compris.';

  @override
  String get empty => 'Aucun élément dans cet inventaire observé.';

  @override
  String get renew => 'Vérifier le renouvellement';

  @override
  String get expiryHeight => 'Hauteur d’expiration';

  @override
  String get state => 'État';

  @override
  String get id => 'Identifiant';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get arkAddress => 'Adresse Ark';

  @override
  String get lightningInvoice => 'Facture Lightning';

  @override
  String get invoiceExpires => 'Expiration de la facture';

  @override
  String get generate => 'Créer une demande';

  @override
  String get foregroundExit =>
      'Les sorties et dépenses de frais nécessitent une vérification au premier plan. La maintenance en arrière-plan ne lance ni ne fait avancer une sortie.';

  @override
  String get nativeUnavailable =>
      'Cette action Ark n’est pas disponible dans cette version.';

  @override
  String get notificationsUnavailable =>
      'Les rappels d’expiration n’ont pas pu être programmés. Vérifiez les permissions de notification et ouvrez Ark régulièrement.';

  @override
  String get backgroundNotice =>
      'Ouvrez Ark régulièrement. Les restrictions de l’appareil peuvent retarder le renouvellement en arrière-plan sur Android. Le renouvellement planifié sur iOS est indisponible.';

  @override
  String get spendableState => 'Disponible';

  @override
  String get lockedState => 'Verrouillé';

  @override
  String get spentState => 'Dépensé';

  @override
  String get exitedState => 'Sorti';

  @override
  String get unknownState => 'Inconnu';

  @override
  String get claimableHeight => 'Récupérable au bloc';

  @override
  String get claimTxid => 'Transaction de récupération';

  @override
  String get renewalSubmitted => 'Renouvellement soumis';

  @override
  String get arkServer => 'Serveur Ark';

  @override
  String get primaryChainSource => 'Esplora principal';

  @override
  String get fallbackChainSource => 'Secours si injoignable';

  @override
  String get minimumBoard => 'Montant minimum de dépôt (sats)';

  @override
  String get maximumVtxo => 'Montant maximum d’un VTXO (sats)';

  @override
  String get boardConfirmations => 'Confirmations du dépôt';

  @override
  String get roundInterval => 'Intervalle des rounds (secondes)';

  @override
  String get vtxoLifetime => 'Durée de vie des VTXO (blocs)';

  @override
  String get renewalThreshold => 'Seuil de renouvellement (blocs)';

  @override
  String get publicServerKey => 'Clé publique du serveur';

  @override
  String get sendFromArk => 'Envoyer depuis Ark';

  @override
  String sendFromArkAccount(String account) {
    return 'Envoyer depuis Ark ($account)';
  }

  @override
  String get signedClaimRecovery => 'Reprendre le retrait signé';

  @override
  String get reannounceSignedClaim => 'Renvoyer ce retrait signé';

  @override
  String get sameSignedClaim =>
      'Renvoyez la même transaction signée, avec sa destination et ses frais enregistrés. Son état réseau est vérifié avant l’envoi.';

  @override
  String get claimDestination => 'Adresse de retour sur la chaîne';

  @override
  String get claimConfirmed =>
      'La transaction de retrait enregistrée est confirmée.';

  @override
  String get claimConflict =>
      'Une transaction conflictuelle a été observée. Ce retrait enregistré ne peut pas être renvoyé.';

  @override
  String get actualVtxos => 'VTXO inclus';

  @override
  String get skippedVtxos => 'VTXO ignorés';

  @override
  String get netInSats => 'Montant net (sats)';

  @override
  String get feeInSats => 'Frais (sats)';

  @override
  String get reminderMigrationPending =>
      'Certains anciens rappels Ark restent non résolus. De nouveaux rappels VTXO peuvent encore être programmés. Ouvrez Ark régulièrement.';

  @override
  String get exitStatusUnknown => 'État de sortie inconnu';

  @override
  String get exitStatusNone => 'Aucune sortie observée';

  @override
  String get exitStatusPending => 'Sortie en attente';

  @override
  String get exitStatusClaimable => 'Sortie récupérable';

  @override
  String get exitStatusSubmitted => 'Récupération soumise';

  @override
  String get exitStatusClaimed => 'Sortie récupérée';

  @override
  String get exitStatusFailed => 'Sortie à vérifier';

  @override
  String get spendableInSats => 'Disponible (sats)';

  @override
  String get pendingInSats => 'En attente (sats)';

  @override
  String get reserveInSats => 'Réserve de frais sur la chaîne (sats)';

  @override
  String get operationPrepared => 'Préparée';

  @override
  String get operationAdmitted => 'Admise';

  @override
  String get operationPending => 'En attente';

  @override
  String get operationCompleted => 'Terminée';

  @override
  String get operationFailed => 'Échec';

  @override
  String get operationUnknown => 'Résultat inconnu';

  @override
  String get operationConflicted => 'Transaction conflictuelle observée';

  @override
  String get observedActivity => 'Activité observée';

  @override
  String get activityObservationsUnavailable =>
      'Observations d’activité indisponibles';

  @override
  String get movementBoard => 'Financement Ark';

  @override
  String get movementPayment => 'Paiement';

  @override
  String get movementRenewal => 'Renouvellement';

  @override
  String get movementExit => 'Sortie';

  @override
  String get movementLightningReceipt => 'Réception Lightning';

  @override
  String get observedTimeUtc => 'Heure observée (UTC)';

  @override
  String get transactionId => 'Identifiant de transaction';

  @override
  String get share => 'Partager';

  @override
  String boardDestination(String account) {
    return 'Compte Ark à alimenter : $account';
  }

  @override
  String get boardFastPolicy =>
      'Politique de frais FAST uniquement. Aucun choix de vitesse.';

  @override
  String get boardFeeReview =>
      'Les frais miniers réels et le débit du portefeuille source seront déterminés lors de la future revue du financement.';

  @override
  String get boardAmountInvalid =>
      'Saisissez un montant entier positif en sats, dans la limite de l’offre de bitcoins.';

  @override
  String exitProgressAccount(String account) {
    return 'Compte Ark pour la progression de sortie : $account';
  }

  @override
  String get exitProgressFeeRate => 'Taux de frais (sat/vB)';

  @override
  String get exitProgressReserveNotice =>
      'La progression peut exposer la réserve de sortie confirmée de tout le compte. Une future revue devra présenter les frais réels et la réserve exposée.';

  @override
  String get exitProgressRateInvalid =>
      'Saisissez un taux entier positif en sat/vB, dans la plage de saisie à représentation entière exacte.';

  @override
  String get exitProgressEstimatedFee => 'Frais estimés (sats)';

  @override
  String get exitProgressReserveExposure => 'Réserve confirmée exposée (sats)';

  @override
  String get exitProgressReviewWarning =>
      'Cette tentative unique au premier plan concerne tout le compte et peut exposer toute la réserve interne confirmée indiquée par le devis. Les frais sont estimatifs et le taux renvoyé par le devis ne constitue pas un plafond financier strict. Cela ne vaut pas autorisation permanente pour de futures tentatives ou de nouveaux dépôts.';

  @override
  String get exitProgressReviewIncomplete =>
      'Cette revue de progression de sortie est incomplète ou incohérente. La confirmation est indisponible.';

  @override
  String get boardSourceWallet => 'Portefeuille source';

  @override
  String get boardMinerFeeInSats => 'Frais miniers (sats)';

  @override
  String get boardArkFeeInSats => 'Frais d’entrée Ark (sats)';

  @override
  String get boardSourceDebitInSats => 'Débit du portefeuille source (sats)';

  @override
  String get boardValidUntil => 'Devis valable jusqu’à (UTC)';

  @override
  String get exitMaximumClaimFee => 'Frais maximaux de réclamation (sats)';

  @override
  String get abandonedBoardState => 'Board abandonné (jamais signé)';

  @override
  String walletBalance(String amount) {
    return '$amount sats';
  }

  @override
  String get receiveAddress => 'Adresse de réception';

  @override
  String get boardToArk => 'Transférer vers Ark';

  @override
  String get arkInfo => 'Informations Ark';

  @override
  String fiatAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get boardIntro =>
      'Transférez des bitcoins de votre portefeuille sur chaîne vers Ark.';

  @override
  String get availableOnchain => 'Disponible sur chaîne';

  @override
  String get amountToMove => 'Montant à transférer';

  @override
  String get maxAmount => 'Max';

  @override
  String get maxUnavailable =>
      'Max est indisponible sans estimation actuelle des frais rapides.';

  @override
  String get boardAction => 'Transférer';

  @override
  String get satsUnit => 'sats';

  @override
  String get continueAction => 'Continuer';

  @override
  String get recipientAddress => 'Adresse du destinataire';

  @override
  String get paymentAddressHint =>
      'Collez une adresse de paiement ou une facture';

  @override
  String get paymentScanHint =>
      'Scannez un code QR pour payer instantanément via Ark.';

  @override
  String get openCamera => 'Ouvrir la caméra';

  @override
  String get cameraUnavailable =>
      'La caméra est indisponible. Saisissez l’adresse du destinataire.';

  @override
  String get confirmSend => 'Confirmer l’envoi';

  @override
  String get paymentSent => 'Paiement envoyé';

  @override
  String get done => 'Terminé';

  @override
  String get walletLabel => 'Portefeuille :';

  @override
  String get balanceLabel => 'Solde :';

  @override
  String get maxPaymentUnavailable =>
      'Max nécessite un devis actuel des frais du paiement.';

  @override
  String get fromLabel => 'Depuis';

  @override
  String get toLabel => 'Vers';

  @override
  String get amountLabel => 'Montant';

  @override
  String get networkFees => 'Frais de réseau';

  @override
  String get totalLabel => 'Total';

  @override
  String get vtxoDetails => 'Détails du VTXO';

  @override
  String get vtxoCreated => 'Créé';

  @override
  String get vtxoAnchor => 'Ancrage';

  @override
  String get vtxoAll => 'Tous';

  @override
  String get vtxoExpired => 'Expirés';

  @override
  String get vtxoBlocksRemaining => 'Blocs restants';

  @override
  String get vtxoTotal => 'Valeur totale';

  @override
  String get vtxoEmptyTitle => 'Aucun VTXO';

  @override
  String get vtxoEmptyBody =>
      'Vos VTXOs apparaîtront ici après réception de fonds.';

  @override
  String get vtxoNoMatches => 'Aucun VTXO ne correspond à ce filtre.';

  @override
  String get vtxoCount => 'VTXOs';

  @override
  String get emergencyOnlyTitle => 'En cas d’urgence uniquement';

  @override
  String get emergencyOnlyBody =>
      'Utilisez une sortie d’urgence uniquement si le serveur Ark est indisponible ou ne répond pas.';

  @override
  String get emergencySendInstead =>
      'Lorsque Ark fonctionne, envoyez simplement votre solde Ark vers une adresse Bitcoin on-chain.';

  @override
  String get startEmergencyExit => 'Démarrer une sortie d’urgence';

  @override
  String get newEmergencyExit => 'Nouvelle sortie d’urgence';

  @override
  String get noEmergencyExits => 'Aucune sortie d’urgence';

  @override
  String get noEmergencyExitsBody =>
      'Vous n’avez démarré aucune sortie d’urgence. Vos sorties apparaîtront ici.';

  @override
  String get exitChooseBody =>
      'Choisissez de sortir tous les VTXOs éligibles ou seulement certains.';

  @override
  String get exitAllEligible => 'Tous les VTXOs éligibles';

  @override
  String get exitSelected => 'VTXOs sélectionnés';

  @override
  String get exitAvailableValue => 'Montant disponible';

  @override
  String get exitFeesAfterReview =>
      'Les frais réels et la réserve exposée sont disponibles dans la revue native.';

  @override
  String get exitProgressTitle => 'Faire avancer les sorties d’urgence';

  @override
  String get exitProgressBody =>
      'Choisissez un taux de frais pour demander une revue au premier plan de la progression des sorties.';

  @override
  String get feeReserveTitle => 'Réserve de frais on-chain';

  @override
  String get feeReserveHelp =>
      'Alimentez cette adresse en bitcoins on-chain avant de démarrer une sortie d’urgence lorsque la réserve de frais est insuffisante.';

  @override
  String feeReserveAmount(String amount) {
    return '$amount sats';
  }

  @override
  String get hiddenAmount => '••••';

  @override
  String get operationRenewalStarted => 'Renouvellement démarré';

  @override
  String get emergencyExitStarted => 'Sortie d’urgence démarrée';

  @override
  String get operationEstimatedNet => 'Montant net estimé';

  @override
  String get arkWalletSubtitle => 'Bitcoin hors chaîne';

  @override
  String get nextRound => 'Prochain round';

  @override
  String get boardDetails => 'Détails de la transaction';

  @override
  String get boardConfirmation => 'Confirmer le dépôt';

  @override
  String get arkActions => 'Actions Ark';

  @override
  String get arkOffTitle => 'Ark est désactivé';

  @override
  String get arkOffBody =>
      'Activez Ark pour envoyer des bitcoins instantanément et à moindre coût.';

  @override
  String get inventoryActive => 'Actifs';

  @override
  String get inventoryExpiring => 'Expiration proche';

  @override
  String get inventoryRenew => 'Renouveler';

  @override
  String get inventoryKeys => 'Clés';

  @override
  String get inventoryBoardingLimits => 'Limites de dépôt';

  @override
  String get inventoryTiming => 'Délais';

  @override
  String get inventoryMailboxKey => 'Clé publique de messagerie';

  @override
  String get inventoryExitDelta => 'Délai de sortie VTXO';

  @override
  String get inventoryAutoRenew => 'Renouveler avant expiration';

  @override
  String get inventoryOnline => 'En ligne';

  @override
  String get inventoryOffline => 'Hors ligne';

  @override
  String get inventoryServerError => 'Serveur Ark inaccessible';

  @override
  String get inventoryServerErrorBody =>
      'Vérifiez votre connexion et réessayez.';

  @override
  String get inventoryCachedInfo =>
      'Serveur Ark inaccessible. Informations de la dernière connexion.';

  @override
  String inventoryBlocks(String count) {
    return '$count blocs';
  }

  @override
  String inventorySeconds(String count) {
    return '$count s';
  }

  @override
  String inventoryExpiresIn(String count) {
    return 'Expire dans $count blocs';
  }

  @override
  String inventoryExpiringIn(String count) {
    return 'Expiration proche · dans $count blocs';
  }

  @override
  String inventoryNextExpiry(String count) {
    return 'Prochaine expiration dans $count blocs';
  }

  @override
  String get inventoryExpiredNote =>
      'Ce VTXO a expiré et ne peut plus être renouvelé.';

  @override
  String get inventoryLockedNote =>
      'Ce VTXO ne peut être dépensé ni renouvelé avant la fin de son opération en cours.';

  @override
  String inventoryRenewNote(String count) {
    return 'Le renouvellement automatique est configuré $count blocs avant expiration. Ouvrez régulièrement l’application pour garder vos VTXOs à jour.';
  }

  @override
  String get inventoryVtxoId => 'Identifiant VTXO';

  @override
  String get inventoryAnchor => 'Point d’ancrage';

  @override
  String get inventoryExpires => 'Expiration';

  @override
  String get inventoryBlocksLeft => 'Blocs restants';

  @override
  String get inventoryTotal => 'Total hors VTXOs expirés';

  @override
  String get inventoryEmptyTitle => 'Aucun VTXO pour le moment';

  @override
  String get inventoryEmptyBody => 'Les bitcoins reçus apparaissent ici.';

  @override
  String get inventoryTechnicalDetails => 'Détails techniques';

  @override
  String get inventoryOpenAccount => 'Ouvrir le portefeuille Ark';

  @override
  String get inventoryServerPublicKey => 'Clé publique du serveur';

  @override
  String get inventoryMinimumBoard => 'Montant minimum de dépôt';

  @override
  String get inventoryMaximumVtxo => 'Montant maximum d’un VTXO';

  @override
  String get inventoryConfirmations => 'Confirmations requises';

  @override
  String get inventoryLifetime => 'Durée de vie des VTXOs';

  @override
  String get inventoryRoundInterval => 'Intervalle des rounds';

  @override
  String get payFrom => 'Payer depuis';

  @override
  String get additionalInformation => 'Informations supplémentaires';

  @override
  String get additionalInformationHint =>
      'Ajouter un montant ou un message pour l’expéditeur';

  @override
  String get arkAddressInformationUnavailable =>
      'Aucun montant ni message ne peut être ajouté à cette adresse Ark. Utilisez une facture Lightning pour demander un montant.';

  @override
  String get noteOptional => 'Note (facultative)';

  @override
  String get paymentNoteUnavailable =>
      'Les notes ne sont pas prises en charge pour ce paiement.';

  @override
  String get addressActions => 'Adresse';

  @override
  String get maxBalanceInputHint =>
      'Le montant final et les frais réseau sont vérifiés avant confirmation.';

  @override
  String boardMinimumWithNetworkFees(String minimum) {
    return 'Montant minimum : $minimum + frais de réseau';
  }

  @override
  String boardAmountBelowMinimum(String minimum) {
    return 'Montant trop faible. Minimum : $minimum + frais';
  }

  @override
  String get boardFeeEstimate => 'Estimation des frais';

  @override
  String get boardArkBalanceReceives => 'Solde Ark crédité';

  @override
  String get boardArkBoardingFee => 'Frais de dépôt sur Ark';

  @override
  String get boardEstimateUnavailable => 'Estimation des frais indisponible';

  @override
  String get boardMinimumUnavailable => 'Montant minimum indisponible';

  @override
  String get boardStarted => 'Dépôt sur Ark démarré';

  @override
  String get boardStartedDescription =>
      'Votre bitcoin on-chain est en cours de transfert vers Ark. Il sera disponible une fois le dépôt terminé.';

  @override
  String get boardFundingTransaction => 'Transaction de financement';

  @override
  String get boardFundingId => 'Identifiant de financement';

  @override
  String boardFundingOptions(String id) {
    return 'Transaction de financement $id. Afficher les options';
  }

  @override
  String get boardFundingIdCopied => 'Identifiant de financement copié';

  @override
  String get boardFundingUnavailable =>
      'Transaction de financement indisponible';

  @override
  String get boardCopyFundingId => 'Copier l’identifiant de transaction';

  @override
  String get boardCopyLink => 'Copier le lien';

  @override
  String get boardViewInExplorer => 'Voir dans l’explorateur';

  @override
  String get boardLinkCopied => 'Lien copié';

  @override
  String get boardVerificationPending => 'Le statut du dépôt doit être vérifié';

  @override
  String get exitHoldToStart => 'Maintenez pour démarrer la sortie';

  @override
  String get exitKeepHolding => 'Continuez à maintenir…';

  @override
  String get exitConfirmAccessible => 'Confirmer la sortie d’urgence';

  @override
  String get exitNoCancellation =>
      'Une sortie démarrée ne peut pas être annulée dans cette app. La progression et la réclamation restent des actions explicites.';

  @override
  String get exitIntendedDestination =>
      'Destination prévue pour la réclamation';

  @override
  String get exitReserveFees =>
      'Les frais des transactions de sortie sont payés par la réserve on-chain Ark. Les frais de réclamation seront revus séparément avant la réclamation.';

  @override
  String get exitUnrolling => 'Déploiement des transactions de sortie';

  @override
  String get exitDelay => 'Délai de sortie';

  @override
  String get exitManualClaim =>
      'Revoyez une réclamation quand la sortie est réclamable. Aucune réclamation automatique n’est autorisée.';

  @override
  String get exitYourExits => 'Vos sorties';

  @override
  String get exitReviewTitle => 'Revoir la sortie';

  @override
  String get exitClaimAction => 'Réclamer';

  @override
  String get exitDetailsTitle => 'Détails de la sortie';

  @override
  String exitConfirmedAtBlock(String height) {
    return 'Confirmée au bloc $height';
  }

  @override
  String exitBlocksRemaining(String count) {
    return '$count blocs restants';
  }

  @override
  String get exitCanceled => 'Sortie annulée';

  @override
  String get movementBoardedLabel => 'Déposé';

  @override
  String get movementReceivedLabel => 'Reçu';

  @override
  String get activityStartHint =>
      'Recevez des bitcoins ou déposez-en depuis votre portefeuille on-chain pour commencer à utiliser Ark.';

  @override
  String get pasteAddress => 'Coller l’adresse du destinataire';

  @override
  String get inventoryHtlcSendExpiryDelta =>
      'Délai d’expiration des HTLC sortants';

  @override
  String get inventoryHtlcExpiryDelta =>
      'Écart d’expiration des HTLC Lightning / Ark';

  @override
  String get inventoryRoundNonceCount => 'Nonces par round';

  @override
  String inventoryBlockHeight(String height) {
    return 'Bloc $height';
  }
}
