import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'ark_localizations_en.dart';
import 'ark_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ArkLocalizations
/// returned by `ArkLocalizations.of(context)`.
///
/// Applications need to include `ArkLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/ark_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ArkLocalizations.localizationsDelegates,
///   supportedLocales: ArkLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ArkLocalizations.supportedLocales
/// property.
abstract class ArkLocalizations {
  ArkLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ArkLocalizations? of(BuildContext context) {
    return Localizations.of<ArkLocalizations>(context, ArkLocalizations);
  }

  static const LocalizationsDelegate<ArkLocalizations> delegate =
      _ArkLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Ark'**
  String get title;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading Ark…'**
  String get loading;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Ark is unavailable. Try again.'**
  String get unavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @spendable.
  ///
  /// In en, this message translates to:
  /// **'Spendable'**
  String get spendable;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @reserve.
  ///
  /// In en, this message translates to:
  /// **'On-chain fee reserve'**
  String get reserve;

  /// No description provided for @stale.
  ///
  /// In en, this message translates to:
  /// **'Last observed data. Refresh before reviewing a payment.'**
  String get stale;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unknown;

  /// No description provided for @renewalWarning.
  ///
  /// In en, this message translates to:
  /// **'Your VTXOs need renewing. Open Ark to protect your funds.'**
  String get renewalWarning;

  /// No description provided for @expiryTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent: Ark funds expire soon'**
  String get expiryTitle;

  /// No description provided for @expiryBody.
  ///
  /// In en, this message translates to:
  /// **'Open Ark to check and renew your VTXOs. Block times and background delivery vary.'**
  String get expiryBody;

  /// No description provided for @renewalDelegated.
  ///
  /// In en, this message translates to:
  /// **'Renewal started. Your warning stays until replacement VTXOs are observed.'**
  String get renewalDelegated;

  /// No description provided for @offFunded.
  ///
  /// In en, this message translates to:
  /// **'Ark is off for new payments. Existing funds still need renewal and recovery remains available.'**
  String get offFunded;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Ark connects directly without Tor. The configured Ark and Esplora providers can see your IP and wallet queries. The fallback is used only if the primary cannot be reached and has the same privacy exposure.'**
  String get privacy;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable Ark'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Turn off new payments'**
  String get disable;

  /// No description provided for @acceptPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I understand the direct connection'**
  String get acceptPrivacy;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Add funds'**
  String get board;

  /// No description provided for @vtxos.
  ///
  /// In en, this message translates to:
  /// **'VTXOs'**
  String get vtxos;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get history;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Server information'**
  String get info;

  /// No description provided for @exits.
  ///
  /// In en, this message translates to:
  /// **'Emergency exit'**
  String get exits;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Ark address or BOLT11 invoice'**
  String get destination;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount in sats'**
  String get amount;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net amount'**
  String get net;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @pendingOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation submitted. Completion requires an observed update.'**
  String get pendingOperation;

  /// No description provided for @uncertain.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown. Refresh to reconcile this operation before trying again.'**
  String get uncertain;

  /// No description provided for @invalid.
  ///
  /// In en, this message translates to:
  /// **'Check the destination and amount.'**
  String get invalid;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Ark before creating a new payment or receive request.'**
  String get disabled;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'This review has expired. Request a new quote.'**
  String get expired;

  /// No description provided for @busy.
  ///
  /// In en, this message translates to:
  /// **'Ark is busy. Wait for the current operation or restart the app if it was interrupted.'**
  String get busy;

  /// No description provided for @recovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery must finish before spending. Existing funds have been preserved.'**
  String get recovery;

  /// No description provided for @insufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds, including fees.'**
  String get insufficient;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'No items in this observed inventory.'**
  String get empty;

  /// No description provided for @renew.
  ///
  /// In en, this message translates to:
  /// **'Review renewal'**
  String get renew;

  /// No description provided for @expiryHeight.
  ///
  /// In en, this message translates to:
  /// **'Expiry block height'**
  String get expiryHeight;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get id;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @arkAddress.
  ///
  /// In en, this message translates to:
  /// **'Ark address'**
  String get arkAddress;

  /// No description provided for @lightningInvoice.
  ///
  /// In en, this message translates to:
  /// **'Lightning invoice'**
  String get lightningInvoice;

  /// No description provided for @invoiceExpires.
  ///
  /// In en, this message translates to:
  /// **'Invoice expires'**
  String get invoiceExpires;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get generate;

  /// No description provided for @foregroundExit.
  ///
  /// In en, this message translates to:
  /// **'Exit and fee spending require foreground review. Background maintenance never starts or progresses an exit.'**
  String get foregroundExit;

  /// No description provided for @nativeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This Ark action is unavailable in this build.'**
  String get nativeUnavailable;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Expiry reminders could not be scheduled. Check notification permissions and open Ark regularly.'**
  String get notificationsUnavailable;

  /// No description provided for @backgroundNotice.
  ///
  /// In en, this message translates to:
  /// **'Open Ark regularly. Device restrictions can delay Android background renewal. Scheduled renewal on iOS is unavailable.'**
  String get backgroundNotice;

  /// No description provided for @spendableState.
  ///
  /// In en, this message translates to:
  /// **'Spendable'**
  String get spendableState;

  /// No description provided for @lockedState.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockedState;

  /// No description provided for @spentState.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentState;

  /// No description provided for @exitedState.
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get exitedState;

  /// No description provided for @unknownState.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownState;

  /// No description provided for @claimableHeight.
  ///
  /// In en, this message translates to:
  /// **'Claimable at block'**
  String get claimableHeight;

  /// No description provided for @claimTxid.
  ///
  /// In en, this message translates to:
  /// **'Claim transaction'**
  String get claimTxid;

  /// No description provided for @renewalSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Renewal submitted'**
  String get renewalSubmitted;

  /// No description provided for @arkServer.
  ///
  /// In en, this message translates to:
  /// **'Ark server'**
  String get arkServer;

  /// No description provided for @primaryChainSource.
  ///
  /// In en, this message translates to:
  /// **'Primary Esplora'**
  String get primaryChainSource;

  /// No description provided for @fallbackChainSource.
  ///
  /// In en, this message translates to:
  /// **'Unreachable-only fallback'**
  String get fallbackChainSource;

  /// No description provided for @minimumBoard.
  ///
  /// In en, this message translates to:
  /// **'Minimum boarding amount (sats)'**
  String get minimumBoard;

  /// No description provided for @maximumVtxo.
  ///
  /// In en, this message translates to:
  /// **'Maximum VTXO amount (sats)'**
  String get maximumVtxo;

  /// No description provided for @boardConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Board confirmations'**
  String get boardConfirmations;

  /// No description provided for @roundInterval.
  ///
  /// In en, this message translates to:
  /// **'Round interval (seconds)'**
  String get roundInterval;

  /// No description provided for @vtxoLifetime.
  ///
  /// In en, this message translates to:
  /// **'VTXO lifetime (blocks)'**
  String get vtxoLifetime;

  /// No description provided for @renewalThreshold.
  ///
  /// In en, this message translates to:
  /// **'Renewal threshold (blocks)'**
  String get renewalThreshold;

  /// No description provided for @publicServerKey.
  ///
  /// In en, this message translates to:
  /// **'Public server key'**
  String get publicServerKey;

  /// No description provided for @sendFromArk.
  ///
  /// In en, this message translates to:
  /// **'Send from Ark'**
  String get sendFromArk;

  /// No description provided for @sendFromArkAccount.
  ///
  /// In en, this message translates to:
  /// **'Send from Ark ({account})'**
  String sendFromArkAccount(String account);

  /// No description provided for @signedClaimRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recover signed claim'**
  String get signedClaimRecovery;

  /// No description provided for @reannounceSignedClaim.
  ///
  /// In en, this message translates to:
  /// **'Resubmit this signed claim'**
  String get reannounceSignedClaim;

  /// No description provided for @sameSignedClaim.
  ///
  /// In en, this message translates to:
  /// **'Resubmit the same signed transaction with its saved destination and fee. Its network status is checked before sending.'**
  String get sameSignedClaim;

  /// No description provided for @claimDestination.
  ///
  /// In en, this message translates to:
  /// **'On-chain return address'**
  String get claimDestination;

  /// No description provided for @claimConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The saved claim transaction is confirmed.'**
  String get claimConfirmed;

  /// No description provided for @claimConflict.
  ///
  /// In en, this message translates to:
  /// **'A conflicting transaction was observed. This saved claim cannot be resubmitted.'**
  String get claimConflict;

  /// No description provided for @actualVtxos.
  ///
  /// In en, this message translates to:
  /// **'Included VTXOs'**
  String get actualVtxos;

  /// No description provided for @skippedVtxos.
  ///
  /// In en, this message translates to:
  /// **'Skipped VTXOs'**
  String get skippedVtxos;

  /// No description provided for @netInSats.
  ///
  /// In en, this message translates to:
  /// **'Net amount (sats)'**
  String get netInSats;

  /// No description provided for @feeInSats.
  ///
  /// In en, this message translates to:
  /// **'Fee (sats)'**
  String get feeInSats;

  /// No description provided for @reminderMigrationPending.
  ///
  /// In en, this message translates to:
  /// **'Some older Ark reminders remain unresolved. New VTXO reminders can still be scheduled. Open Ark regularly.'**
  String get reminderMigrationPending;

  /// No description provided for @exitStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown exit state'**
  String get exitStatusUnknown;

  /// No description provided for @exitStatusNone.
  ///
  /// In en, this message translates to:
  /// **'No exit observed'**
  String get exitStatusNone;

  /// No description provided for @exitStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Exit pending'**
  String get exitStatusPending;

  /// No description provided for @exitStatusClaimable.
  ///
  /// In en, this message translates to:
  /// **'Exit claimable'**
  String get exitStatusClaimable;

  /// No description provided for @exitStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Claim submitted'**
  String get exitStatusSubmitted;

  /// No description provided for @exitStatusClaimed.
  ///
  /// In en, this message translates to:
  /// **'Exit claimed'**
  String get exitStatusClaimed;

  /// No description provided for @exitStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Exit needs attention'**
  String get exitStatusFailed;

  /// No description provided for @spendableInSats.
  ///
  /// In en, this message translates to:
  /// **'Spendable (sats)'**
  String get spendableInSats;

  /// No description provided for @pendingInSats.
  ///
  /// In en, this message translates to:
  /// **'Pending (sats)'**
  String get pendingInSats;

  /// No description provided for @reserveInSats.
  ///
  /// In en, this message translates to:
  /// **'On-chain fee reserve (sats)'**
  String get reserveInSats;

  /// No description provided for @operationPrepared.
  ///
  /// In en, this message translates to:
  /// **'Prepared'**
  String get operationPrepared;

  /// No description provided for @operationAdmitted.
  ///
  /// In en, this message translates to:
  /// **'Admitted'**
  String get operationAdmitted;

  /// No description provided for @operationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get operationPending;

  /// No description provided for @operationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get operationCompleted;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get operationFailed;

  /// No description provided for @operationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get operationUnknown;

  /// No description provided for @operationConflicted.
  ///
  /// In en, this message translates to:
  /// **'Conflicting transaction observed'**
  String get operationConflicted;

  /// No description provided for @observedActivity.
  ///
  /// In en, this message translates to:
  /// **'Observed activity'**
  String get observedActivity;

  /// No description provided for @activityObservationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity observations unavailable'**
  String get activityObservationsUnavailable;

  /// No description provided for @movementBoard.
  ///
  /// In en, this message translates to:
  /// **'Board funding'**
  String get movementBoard;

  /// No description provided for @movementPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get movementPayment;

  /// No description provided for @movementRenewal.
  ///
  /// In en, this message translates to:
  /// **'Renewal'**
  String get movementRenewal;

  /// No description provided for @movementExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get movementExit;

  /// No description provided for @movementLightningReceipt.
  ///
  /// In en, this message translates to:
  /// **'Lightning receipt'**
  String get movementLightningReceipt;

  /// No description provided for @observedTimeUtc.
  ///
  /// In en, this message translates to:
  /// **'Observed time (UTC)'**
  String get observedTimeUtc;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @boardDestination.
  ///
  /// In en, this message translates to:
  /// **'Board destination: {account}'**
  String boardDestination(String account);

  /// No description provided for @boardFastPolicy.
  ///
  /// In en, this message translates to:
  /// **'FAST fee policy only. No fee speed selection.'**
  String get boardFastPolicy;

  /// No description provided for @boardFeeReview.
  ///
  /// In en, this message translates to:
  /// **'The actual miner fee and source debit are determined in the future funding review.'**
  String get boardFeeReview;

  /// No description provided for @boardAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive whole amount in sats within the Bitcoin supply limit.'**
  String get boardAmountInvalid;
}

class _ArkLocalizationsDelegate
    extends LocalizationsDelegate<ArkLocalizations> {
  const _ArkLocalizationsDelegate();

  @override
  Future<ArkLocalizations> load(Locale locale) {
    return SynchronousFuture<ArkLocalizations>(lookupArkLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_ArkLocalizationsDelegate old) => false;
}

ArkLocalizations lookupArkLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ArkLocalizationsEn();
    case 'fr':
      return ArkLocalizationsFr();
  }

  throw FlutterError(
    'ArkLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
