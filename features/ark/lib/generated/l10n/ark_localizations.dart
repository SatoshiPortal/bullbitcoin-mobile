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
  /// **'Payment address or BOLT11 invoice'**
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

  /// No description provided for @exitProgressAccount.
  ///
  /// In en, this message translates to:
  /// **'Exit progression account: {account}'**
  String exitProgressAccount(String account);

  /// No description provided for @exitProgressFeeRate.
  ///
  /// In en, this message translates to:
  /// **'Fee rate (sat/vB)'**
  String get exitProgressFeeRate;

  /// No description provided for @exitProgressReserveNotice.
  ///
  /// In en, this message translates to:
  /// **'Progress may expose the account-wide confirmed exit reserve. A future review must show the actual fee and reserve at risk.'**
  String get exitProgressReserveNotice;

  /// No description provided for @exitProgressRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive whole rate in sat/vB within the supported exact-integer input range.'**
  String get exitProgressRateInvalid;

  /// No description provided for @exitProgressEstimatedFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee (sats)'**
  String get exitProgressEstimatedFee;

  /// No description provided for @exitProgressReserveExposure.
  ///
  /// In en, this message translates to:
  /// **'Confirmed reserve at risk (sats)'**
  String get exitProgressReserveExposure;

  /// No description provided for @exitProgressReviewWarning.
  ///
  /// In en, this message translates to:
  /// **'This one foreground attempt is account-wide and may expose the entire quoted confirmed internal reserve. The fee is an estimate and the returned quote rate is not a strict financial cap. This is not standing consent for later attempts or new deposits.'**
  String get exitProgressReviewWarning;

  /// No description provided for @exitProgressReviewIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This exit progression review is incomplete or mismatched. Confirmation is unavailable.'**
  String get exitProgressReviewIncomplete;

  /// No description provided for @boardSourceWallet.
  ///
  /// In en, this message translates to:
  /// **'Source wallet'**
  String get boardSourceWallet;

  /// No description provided for @boardMinerFeeInSats.
  ///
  /// In en, this message translates to:
  /// **'Miner fee (sats)'**
  String get boardMinerFeeInSats;

  /// No description provided for @boardArkFeeInSats.
  ///
  /// In en, this message translates to:
  /// **'Ark board fee (sats)'**
  String get boardArkFeeInSats;

  /// No description provided for @boardSourceDebitInSats.
  ///
  /// In en, this message translates to:
  /// **'Source debit (sats)'**
  String get boardSourceDebitInSats;

  /// No description provided for @boardValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Review valid until (UTC)'**
  String get boardValidUntil;

  /// No description provided for @exitMaximumClaimFee.
  ///
  /// In en, this message translates to:
  /// **'Maximum claim fee (sats)'**
  String get exitMaximumClaimFee;

  /// No description provided for @abandonedBoardState.
  ///
  /// In en, this message translates to:
  /// **'Abandoned board (never signed)'**
  String get abandonedBoardState;

  /// Observed spendable Ark wallet balance with explicit satoshi units
  ///
  /// In en, this message translates to:
  /// **'{amount} sats'**
  String walletBalance(String amount);

  /// Heading above the current Ark receive address
  ///
  /// In en, this message translates to:
  /// **'Receive Address'**
  String get receiveAddress;

  /// Navigation action for moving on-chain bitcoin into Ark
  ///
  /// In en, this message translates to:
  /// **'Board to Ark'**
  String get boardToArk;

  /// Navigation action opening Ark server information
  ///
  /// In en, this message translates to:
  /// **'Ark info'**
  String get arkInfo;

  /// Fiat equivalent from the app price and selected currency, shown only when available
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String fiatAmount(String amount, String currency);

  /// Board form introduction
  ///
  /// In en, this message translates to:
  /// **'Move bitcoin from your on-chain wallet into Ark.'**
  String get boardIntro;

  /// Current observed spendable source wallet balance
  ///
  /// In en, this message translates to:
  /// **'Available on-chain'**
  String get availableOnchain;

  /// Label for the on-chain amount moved into Ark
  ///
  /// In en, this message translates to:
  /// **'Amount to move'**
  String get amountToMove;

  /// Maximum spend action
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxAmount;

  /// Maximum remains disabled when no applicable miner fee quote exists
  ///
  /// In en, this message translates to:
  /// **'Max is unavailable without a current fast-fee estimate.'**
  String get maxUnavailable;

  /// Continue from the Board amount form to the actual funding review
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardAction;

  /// Satoshi unit displayed in an Ark amount field
  ///
  /// In en, this message translates to:
  /// **'sats'**
  String get satsUnit;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s address'**
  String get recipientAddress;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Paste a payment address or invoice'**
  String get paymentAddressHint;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code to pay instantly over Ark.'**
  String get paymentScanHint;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Open the Camera'**
  String get openCamera;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Camera is unavailable. Enter the recipient\'s address.'**
  String get cameraUnavailable;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Confirm Send'**
  String get confirmSend;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Payment sent'**
  String get paymentSent;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Wallet:'**
  String get walletLabel;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Balance:'**
  String get balanceLabel;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Max requires a current payment fee quote.'**
  String get maxPaymentUnavailable;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Network fees'**
  String get networkFees;

  /// Ark payment journey label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'VTXO details'**
  String get vtxoDetails;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get vtxoCreated;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Anchor'**
  String get vtxoAnchor;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vtxoAll;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get vtxoExpired;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Blocks remaining'**
  String get vtxoBlocksRemaining;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Total value'**
  String get vtxoTotal;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'No VTXOs'**
  String get vtxoEmptyTitle;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Your VTXOs will appear here once you receive funds.'**
  String get vtxoEmptyBody;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'No VTXOs match this filter.'**
  String get vtxoNoMatches;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'VTXOs'**
  String get vtxoCount;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'For emergency use only'**
  String get emergencyOnlyTitle;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Use an emergency exit only if the Ark server is down or not responding.'**
  String get emergencyOnlyBody;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'When Ark is working, just send to an on-chain address from your Ark balance.'**
  String get emergencySendInstead;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Start emergency exit'**
  String get startEmergencyExit;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'New emergency exit'**
  String get newEmergencyExit;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'No emergency exits'**
  String get noEmergencyExits;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'You haven’t started an emergency exit. Exits you start will show up here.'**
  String get noEmergencyExitsBody;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Choose whether to exit all eligible VTXOs or only specific ones.'**
  String get exitChooseBody;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'All eligible VTXOs'**
  String get exitAllEligible;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Selected VTXOs'**
  String get exitSelected;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Available value'**
  String get exitAvailableValue;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Actual fees and reserve exposure are available in the native review.'**
  String get exitFeesAfterReview;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Progress emergency exits'**
  String get exitProgressTitle;

  /// Ark VTXO or emergency exit presentation
  ///
  /// In en, this message translates to:
  /// **'Choose a fee rate to request a foreground review of exit progression.'**
  String get exitProgressBody;

  /// Public funding destination for emergency exit miner fees
  ///
  /// In en, this message translates to:
  /// **'On-chain fee reserve'**
  String get feeReserveTitle;

  /// Explains why the native fee reserve must be funded
  ///
  /// In en, this message translates to:
  /// **'Fund this address with on-chain bitcoin before starting an emergency exit when the fee reserve is insufficient.'**
  String get feeReserveHelp;

  /// Observed native on-chain fee reserve balance
  ///
  /// In en, this message translates to:
  /// **'{amount} sats'**
  String feeReserveAmount(String amount);

  /// Privacy placeholder for hidden balances
  ///
  /// In en, this message translates to:
  /// **'••••'**
  String get hiddenAmount;

  /// Native operation review outcome or estimate
  ///
  /// In en, this message translates to:
  /// **'Renewal started'**
  String get operationRenewalStarted;

  /// Native operation review outcome or estimate
  ///
  /// In en, this message translates to:
  /// **'Emergency exit started'**
  String get emergencyExitStarted;

  /// Native operation review outcome or estimate
  ///
  /// In en, this message translates to:
  /// **'Estimated net amount'**
  String get operationEstimatedNet;

  /// Ark account presentation
  ///
  /// In en, this message translates to:
  /// **'Off-chain bitcoin'**
  String get arkWalletSubtitle;

  /// Ark account presentation
  ///
  /// In en, this message translates to:
  /// **'Next round'**
  String get nextRound;

  /// Expandable technical details of a Board funding review.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get boardDetails;

  /// No description provided for @boardConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm board'**
  String get boardConfirmation;

  /// Accessible name for the menu of Ark account actions.
  ///
  /// In en, this message translates to:
  /// **'Ark actions'**
  String get arkActions;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Ark is off'**
  String get arkOffTitle;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Turn on Ark to send bitcoin instantly and with lower fees.'**
  String get arkOffBody;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get inventoryActive;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get inventoryExpiring;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get inventoryRenew;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get inventoryKeys;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Boarding limits'**
  String get inventoryBoardingLimits;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get inventoryTiming;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Mailbox public key'**
  String get inventoryMailboxKey;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'VTXO exit delta'**
  String get inventoryExitDelta;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Auto-renew before expiry'**
  String get inventoryAutoRenew;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get inventoryOnline;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get inventoryOffline;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Can’t reach the Ark server'**
  String get inventoryServerError;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get inventoryServerErrorBody;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Can’t reach the Ark server. Showing info from the last connection.'**
  String get inventoryCachedInfo;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'{count} blocks'**
  String inventoryBlocks(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'{count} sec'**
  String inventorySeconds(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Expires in {count} blocks'**
  String inventoryExpiresIn(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Expiring · in {count} blocks'**
  String inventoryExpiringIn(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Next expiry in {count} blocks'**
  String inventoryNextExpiry(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'This VTXO has expired and can’t be renewed.'**
  String get inventoryExpiredNote;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'This VTXO can’t be spent or renewed until its pending operation finishes.'**
  String get inventoryLockedNote;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Auto-renew is configured {count} blocks before expiry. Open the app regularly to keep your VTXOs current.'**
  String inventoryRenewNote(String count);

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'VTXO ID'**
  String get inventoryVtxoId;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Anchor point'**
  String get inventoryAnchor;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get inventoryExpires;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Blocks left'**
  String get inventoryBlocksLeft;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Total excluding expired VTXOs'**
  String get inventoryTotal;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'No VTXOs yet'**
  String get inventoryEmptyTitle;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Bitcoin you receive shows up here.'**
  String get inventoryEmptyBody;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get inventoryTechnicalDetails;

  /// Ark inventory/settings parity with design source
  ///
  /// In en, this message translates to:
  /// **'Open Ark wallet'**
  String get inventoryOpenAccount;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'Server public key'**
  String get inventoryServerPublicKey;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'Minimum board amount'**
  String get inventoryMinimumBoard;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'Maximum VTXO amount'**
  String get inventoryMaximumVtxo;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'Required confirmations'**
  String get inventoryConfirmations;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'VTXO lifetime'**
  String get inventoryLifetime;

  /// Ark information mockup label; units are part of the value
  ///
  /// In en, this message translates to:
  /// **'Round interval'**
  String get inventoryRoundInterval;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get payFrom;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInformation;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Add an amount or message for sender'**
  String get additionalInformationHint;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Amounts and messages cannot be added to this Ark address. Use a Lightning invoice to request an amount.'**
  String get arkAddressInformationUnavailable;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Notes are not supported for this payment.'**
  String get paymentNoteUnavailable;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressActions;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'The final amount and network fees are checked before confirmation.'**
  String get maxBalanceInputHint;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Minimum amount {minimum} + network fees'**
  String boardMinimumWithNetworkFees(String minimum);

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Amount is too low. Minimum is {minimum} + fees'**
  String boardAmountBelowMinimum(String minimum);

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Fee estimate'**
  String get boardFeeEstimate;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Ark balance receives'**
  String get boardArkBalanceReceives;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Ark boarding fee'**
  String get boardArkBoardingFee;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Fee estimate unavailable'**
  String get boardEstimateUnavailable;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Minimum amount unavailable'**
  String get boardMinimumUnavailable;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Boarding started'**
  String get boardStarted;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Your on-chain bitcoin is moving into Ark. It will become spendable after the board completes.'**
  String get boardStartedDescription;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Funding transaction'**
  String get boardFundingTransaction;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Funding ID'**
  String get boardFundingId;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Funding transaction {id}. Show options'**
  String boardFundingOptions(String id);

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Funding ID copied'**
  String get boardFundingIdCopied;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Funding transaction unavailable'**
  String get boardFundingUnavailable;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Copy transaction ID'**
  String get boardCopyFundingId;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get boardCopyLink;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'View in explorer'**
  String get boardViewInExplorer;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get boardLinkCopied;

  /// Ark UI parity with the supplied screen designs
  ///
  /// In en, this message translates to:
  /// **'Boarding status needs verification'**
  String get boardVerificationPending;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Hold to start exit'**
  String get exitHoldToStart;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Keep holding…'**
  String get exitKeepHolding;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Confirm emergency exit'**
  String get exitConfirmAccessible;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'A started exit cannot be canceled from this app. Progress and claim remain explicit actions.'**
  String get exitNoCancellation;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Intended claim destination'**
  String get exitIntendedDestination;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Exit transaction fees are paid from the Ark on-chain reserve. Claim fees are reviewed separately before claiming.'**
  String get exitReserveFees;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Unrolling exit transactions'**
  String get exitUnrolling;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Exit delay'**
  String get exitDelay;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Review a claim when the exit is claimable. No automatic claim is authorized.'**
  String get exitManualClaim;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Your exits'**
  String get exitYourExits;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Review exit'**
  String get exitReviewTitle;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get exitClaimAction;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Exit details'**
  String get exitDetailsTitle;

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'Confirmed at block {height}'**
  String exitConfirmedAtBlock(String height);

  /// Emergency exit presentation over explicitly reviewed native operations
  ///
  /// In en, this message translates to:
  /// **'{count} blocks remaining'**
  String exitBlocksRemaining(String count);

  /// Observed native exit canceled phase; does not authorize a claim
  ///
  /// In en, this message translates to:
  /// **'Exit canceled'**
  String get exitCanceled;

  /// Ark wallet and transfer parity presentation
  ///
  /// In en, this message translates to:
  /// **'Boarded'**
  String get movementBoardedLabel;

  /// Ark wallet and transfer parity presentation
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get movementReceivedLabel;

  /// Ark wallet and transfer parity presentation
  ///
  /// In en, this message translates to:
  /// **'Receive bitcoin or board from your on-chain wallet to start using Ark.'**
  String get activityStartHint;

  /// Ark wallet and transfer parity presentation
  ///
  /// In en, this message translates to:
  /// **'Paste recipient’s address'**
  String get pasteAddress;

  /// Observed native Ark server parameter; unknown without matching configured endpoint
  ///
  /// In en, this message translates to:
  /// **'Outgoing HTLC expiry delta'**
  String get inventoryHtlcSendExpiryDelta;

  /// Observed native Ark server parameter; unknown without matching configured endpoint
  ///
  /// In en, this message translates to:
  /// **'Lightning / Ark HTLC expiry difference'**
  String get inventoryHtlcExpiryDelta;

  /// Observed native Ark server parameter; unknown without matching configured endpoint
  ///
  /// In en, this message translates to:
  /// **'Nonces per round'**
  String get inventoryRoundNonceCount;

  /// Absolute expiry block height, distinct from a remaining quantity of blocks
  ///
  /// In en, this message translates to:
  /// **'Block {height}'**
  String inventoryBlockHeight(String height);

  /// Operation result presentation; this does not assert chain settlement or round completion.
  ///
  /// In en, this message translates to:
  /// **'Operation details'**
  String get operationDetails;

  /// Operation result presentation; this does not assert chain settlement or round completion.
  ///
  /// In en, this message translates to:
  /// **'Request completed. Chain settlement and round completion are separate.'**
  String get operationRequestCompleted;

  /// Heading for an emergency exit quote refused before any confirmation attempt.
  ///
  /// In en, this message translates to:
  /// **'Exit not started'**
  String get exitNotStarted;
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
