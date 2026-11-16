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
  String get destination => 'Adresse Ark ou facture BOLT11';

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
}
