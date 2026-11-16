// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'ark_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ArkLocalizationsEn extends ArkLocalizations {
  ArkLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Ark';

  @override
  String get loading => 'Loading Ark…';

  @override
  String get unavailable => 'Ark is unavailable. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get spendable => 'Spendable';

  @override
  String get pending => 'Pending';

  @override
  String get reserve => 'On-chain fee reserve';

  @override
  String get stale => 'Last observed data. Refresh before reviewing a payment.';

  @override
  String get unknown => 'Unavailable';

  @override
  String get renewalWarning =>
      'Your VTXOs need renewing. Open Ark to protect your funds.';

  @override
  String get expiryTitle => 'Urgent: Ark funds expire soon';

  @override
  String get expiryBody =>
      'Open Ark to check and renew your VTXOs. Block times and background delivery vary.';

  @override
  String get renewalDelegated =>
      'Renewal started. Your warning stays until replacement VTXOs are observed.';

  @override
  String get offFunded =>
      'Ark is off for new payments. Existing funds still need renewal and recovery remains available.';

  @override
  String get privacy =>
      'Ark connects directly without Tor. The configured Ark and Esplora providers can see your IP and wallet queries. The fallback is used only if the primary cannot be reached and has the same privacy exposure.';

  @override
  String get enable => 'Enable Ark';

  @override
  String get disable => 'Turn off new payments';

  @override
  String get acceptPrivacy => 'I understand the direct connection';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get board => 'Add funds';

  @override
  String get vtxos => 'VTXOs';

  @override
  String get history => 'Activity';

  @override
  String get info => 'Server information';

  @override
  String get exits => 'Emergency exit';

  @override
  String get destination => 'Ark address or BOLT11 invoice';

  @override
  String get amount => 'Amount in sats';

  @override
  String get review => 'Review';

  @override
  String get confirm => 'Confirm';

  @override
  String get fee => 'Fee';

  @override
  String get net => 'Net amount';

  @override
  String get cancel => 'Cancel';

  @override
  String get pendingOperation =>
      'Operation submitted. Completion requires an observed update.';

  @override
  String get uncertain =>
      'Outcome unknown. Refresh to reconcile this operation before trying again.';

  @override
  String get invalid => 'Check the destination and amount.';

  @override
  String get disabled =>
      'Enable Ark before creating a new payment or receive request.';

  @override
  String get expired => 'This review has expired. Request a new quote.';

  @override
  String get busy =>
      'Ark is busy. Wait for the current operation or restart the app if it was interrupted.';

  @override
  String get recovery =>
      'Recovery must finish before spending. Existing funds have been preserved.';

  @override
  String get insufficient => 'Insufficient funds, including fees.';

  @override
  String get empty => 'No items in this observed inventory.';

  @override
  String get renew => 'Review renewal';

  @override
  String get expiryHeight => 'Expiry block height';

  @override
  String get state => 'State';

  @override
  String get id => 'Identifier';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get arkAddress => 'Ark address';

  @override
  String get lightningInvoice => 'Lightning invoice';

  @override
  String get invoiceExpires => 'Invoice expires';

  @override
  String get generate => 'Create request';

  @override
  String get foregroundExit =>
      'Exit and fee spending require foreground review. Background maintenance never starts or progresses an exit.';

  @override
  String get nativeUnavailable =>
      'This Ark action is unavailable in this build.';

  @override
  String get notificationsUnavailable =>
      'Expiry reminders could not be scheduled. Check notification permissions and open Ark regularly.';

  @override
  String get backgroundNotice =>
      'Open Ark regularly. Device restrictions can delay Android background renewal. Scheduled renewal on iOS is unavailable.';

  @override
  String get spendableState => 'Spendable';

  @override
  String get lockedState => 'Locked';

  @override
  String get spentState => 'Spent';

  @override
  String get exitedState => 'Exited';

  @override
  String get unknownState => 'Unknown';

  @override
  String get claimableHeight => 'Claimable at block';

  @override
  String get claimTxid => 'Claim transaction';

  @override
  String get renewalSubmitted => 'Renewal submitted';

  @override
  String get arkServer => 'Ark server';

  @override
  String get primaryChainSource => 'Primary Esplora';

  @override
  String get fallbackChainSource => 'Unreachable-only fallback';

  @override
  String get minimumBoard => 'Minimum boarding amount (sats)';

  @override
  String get maximumVtxo => 'Maximum VTXO amount (sats)';

  @override
  String get boardConfirmations => 'Board confirmations';

  @override
  String get roundInterval => 'Round interval (seconds)';

  @override
  String get vtxoLifetime => 'VTXO lifetime (blocks)';

  @override
  String get renewalThreshold => 'Renewal threshold (blocks)';

  @override
  String get publicServerKey => 'Public server key';

  @override
  String get sendFromArk => 'Send from Ark';

  @override
  String sendFromArkAccount(String account) {
    return 'Send from Ark ($account)';
  }
}
