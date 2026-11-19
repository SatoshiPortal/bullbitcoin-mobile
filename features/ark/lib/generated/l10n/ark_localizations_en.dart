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
  String get destination => 'Payment address or BOLT11 invoice';

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

  @override
  String get signedClaimRecovery => 'Recover signed claim';

  @override
  String get reannounceSignedClaim => 'Resubmit this signed claim';

  @override
  String get sameSignedClaim =>
      'Resubmit the same signed transaction with its saved destination and fee. Its network status is checked before sending.';

  @override
  String get claimDestination => 'On-chain return address';

  @override
  String get claimConfirmed => 'The saved claim transaction is confirmed.';

  @override
  String get claimConflict =>
      'A conflicting transaction was observed. This saved claim cannot be resubmitted.';

  @override
  String get actualVtxos => 'Included VTXOs';

  @override
  String get skippedVtxos => 'Skipped VTXOs';

  @override
  String get netInSats => 'Net amount (sats)';

  @override
  String get feeInSats => 'Fee (sats)';

  @override
  String get reminderMigrationPending =>
      'Some older Ark reminders remain unresolved. New VTXO reminders can still be scheduled. Open Ark regularly.';

  @override
  String get exitStatusUnknown => 'Unknown exit state';

  @override
  String get exitStatusNone => 'No exit observed';

  @override
  String get exitStatusPending => 'Exit pending';

  @override
  String get exitStatusClaimable => 'Exit claimable';

  @override
  String get exitStatusSubmitted => 'Claim submitted';

  @override
  String get exitStatusClaimed => 'Exit claimed';

  @override
  String get exitStatusFailed => 'Exit needs attention';

  @override
  String get spendableInSats => 'Spendable (sats)';

  @override
  String get pendingInSats => 'Pending (sats)';

  @override
  String get reserveInSats => 'On-chain fee reserve (sats)';

  @override
  String get operationPrepared => 'Prepared';

  @override
  String get operationAdmitted => 'Admitted';

  @override
  String get operationPending => 'Pending';

  @override
  String get operationCompleted => 'Completed';

  @override
  String get operationFailed => 'Failed';

  @override
  String get operationUnknown => 'Outcome unknown';

  @override
  String get operationConflicted => 'Conflicting transaction observed';

  @override
  String get observedActivity => 'Observed activity';

  @override
  String get activityObservationsUnavailable =>
      'Activity observations unavailable';

  @override
  String get movementBoard => 'Board funding';

  @override
  String get movementPayment => 'Payment';

  @override
  String get movementRenewal => 'Renewal';

  @override
  String get movementExit => 'Exit';

  @override
  String get movementLightningReceipt => 'Lightning receipt';

  @override
  String get observedTimeUtc => 'Observed time (UTC)';

  @override
  String get transactionId => 'Transaction ID';

  @override
  String get share => 'Share';

  @override
  String boardDestination(String account) {
    return 'Board destination: $account';
  }

  @override
  String get boardFastPolicy => 'FAST fee policy only. No fee speed selection.';

  @override
  String get boardFeeReview =>
      'The actual miner fee and source debit are determined in the future funding review.';

  @override
  String get boardAmountInvalid =>
      'Enter a positive whole amount in sats within the Bitcoin supply limit.';

  @override
  String exitProgressAccount(String account) {
    return 'Exit progression account: $account';
  }

  @override
  String get exitProgressFeeRate => 'Fee rate (sat/vB)';

  @override
  String get exitProgressReserveNotice =>
      'Progress may expose the account-wide confirmed exit reserve. A future review must show the actual fee and reserve at risk.';

  @override
  String get exitProgressRateInvalid =>
      'Enter a positive whole rate in sat/vB within the supported exact-integer input range.';

  @override
  String get exitProgressEstimatedFee => 'Estimated fee (sats)';

  @override
  String get exitProgressReserveExposure => 'Confirmed reserve at risk (sats)';

  @override
  String get exitProgressReviewWarning =>
      'This one foreground attempt is account-wide and may expose the entire quoted confirmed internal reserve. The fee is an estimate and the returned quote rate is not a strict financial cap. This is not standing consent for later attempts or new deposits.';

  @override
  String get exitProgressReviewIncomplete =>
      'This exit progression review is incomplete or mismatched. Confirmation is unavailable.';

  @override
  String get boardSourceWallet => 'Source wallet';

  @override
  String get boardMinerFeeInSats => 'Miner fee (sats)';

  @override
  String get boardArkFeeInSats => 'Ark board fee (sats)';

  @override
  String get boardSourceDebitInSats => 'Source debit (sats)';

  @override
  String get boardValidUntil => 'Review valid until (UTC)';

  @override
  String get exitMaximumClaimFee => 'Maximum claim fee (sats)';

  @override
  String get abandonedBoardState => 'Abandoned board (never signed)';

  @override
  String walletBalance(String amount) {
    return '$amount sats';
  }

  @override
  String get receiveAddress => 'Receive Address';

  @override
  String get boardToArk => 'Board to Ark';

  @override
  String get arkInfo => 'Ark info';

  @override
  String fiatAmount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get boardIntro => 'Move bitcoin from your on-chain wallet into Ark.';

  @override
  String get availableOnchain => 'Available on-chain';

  @override
  String get amountToMove => 'Amount to move';

  @override
  String get maxAmount => 'Max';

  @override
  String get maxUnavailable =>
      'Max is unavailable without a current fast-fee estimate.';

  @override
  String get boardAction => 'Board';

  @override
  String get satsUnit => 'sats';

  @override
  String get continueAction => 'Continue';

  @override
  String get recipientAddress => 'Recipient\'s address';

  @override
  String get paymentAddressHint => 'Paste a payment address or invoice';

  @override
  String get paymentScanHint => 'Scan a QR code to pay instantly over Ark.';

  @override
  String get openCamera => 'Open the Camera';

  @override
  String get cameraUnavailable =>
      'Camera is unavailable. Enter the recipient\'s address.';

  @override
  String get confirmSend => 'Confirm Send';

  @override
  String get paymentSent => 'Payment sent';

  @override
  String get done => 'Done';

  @override
  String get walletLabel => 'Wallet:';

  @override
  String get balanceLabel => 'Balance:';

  @override
  String get maxPaymentUnavailable =>
      'Max requires a current payment fee quote.';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get amountLabel => 'Amount';

  @override
  String get networkFees => 'Network fees';

  @override
  String get totalLabel => 'Total';

  @override
  String get vtxoDetails => 'VTXO details';

  @override
  String get vtxoCreated => 'Created';

  @override
  String get vtxoAnchor => 'Anchor';

  @override
  String get vtxoAll => 'All';

  @override
  String get vtxoExpired => 'Expired';

  @override
  String get vtxoBlocksRemaining => 'Blocks remaining';

  @override
  String get vtxoTotal => 'Total value';

  @override
  String get vtxoEmptyTitle => 'No VTXOs';

  @override
  String get vtxoEmptyBody =>
      'Your VTXOs will appear here once you receive funds.';

  @override
  String get vtxoNoMatches => 'No VTXOs match this filter.';

  @override
  String get vtxoCount => 'VTXOs';

  @override
  String get emergencyOnlyTitle => 'For emergency use only';

  @override
  String get emergencyOnlyBody =>
      'Use an emergency exit only if the Ark server is down or not responding.';

  @override
  String get emergencySendInstead =>
      'When Ark is working, just send to an on-chain address from your Ark balance.';

  @override
  String get startEmergencyExit => 'Start emergency exit';

  @override
  String get newEmergencyExit => 'New emergency exit';

  @override
  String get noEmergencyExits => 'No emergency exits';

  @override
  String get noEmergencyExitsBody =>
      'You haven’t started an emergency exit. Exits you start will show up here.';

  @override
  String get exitChooseBody =>
      'Choose whether to exit all eligible VTXOs or only specific ones.';

  @override
  String get exitAllEligible => 'All eligible VTXOs';

  @override
  String get exitSelected => 'Selected VTXOs';

  @override
  String get exitAvailableValue => 'Available value';

  @override
  String get exitFeesAfterReview =>
      'Actual fees and reserve exposure are available in the native review.';

  @override
  String get exitProgressTitle => 'Progress emergency exits';

  @override
  String get exitProgressBody =>
      'Choose a fee rate to request a foreground review of exit progression.';

  @override
  String get feeReserveTitle => 'On-chain fee reserve';

  @override
  String get feeReserveHelp =>
      'Fund this address with on-chain bitcoin before starting an emergency exit when the fee reserve is insufficient.';

  @override
  String feeReserveAmount(String amount) {
    return '$amount sats';
  }

  @override
  String get hiddenAmount => '••••';

  @override
  String get operationRenewalStarted => 'Renewal started';

  @override
  String get emergencyExitStarted => 'Emergency exit started';

  @override
  String get operationEstimatedNet => 'Estimated net amount';

  @override
  String get arkWalletSubtitle => 'Off-chain bitcoin';

  @override
  String get nextRound => 'Next round';

  @override
  String get boardDetails => 'Transaction details';

  @override
  String get boardConfirmation => 'Confirm board';

  @override
  String get arkActions => 'Ark actions';

  @override
  String get arkOffTitle => 'Ark is off';

  @override
  String get arkOffBody =>
      'Turn on Ark to send bitcoin instantly and with lower fees.';

  @override
  String get inventoryActive => 'Active';

  @override
  String get inventoryExpiring => 'Expiring';

  @override
  String get inventoryRenew => 'Renew';

  @override
  String get inventoryKeys => 'Keys';

  @override
  String get inventoryBoardingLimits => 'Boarding limits';

  @override
  String get inventoryTiming => 'Timing';

  @override
  String get inventoryMailboxKey => 'Mailbox public key';

  @override
  String get inventoryExitDelta => 'VTXO exit delta';

  @override
  String get inventoryAutoRenew => 'Auto-renew before expiry';

  @override
  String get inventoryOnline => 'Online';

  @override
  String get inventoryOffline => 'Offline';

  @override
  String get inventoryServerError => 'Can’t reach the Ark server';

  @override
  String get inventoryServerErrorBody => 'Check your connection and try again.';

  @override
  String get inventoryCachedInfo =>
      'Can’t reach the Ark server. Showing info from the last connection.';

  @override
  String inventoryBlocks(String count) {
    return '$count blocks';
  }

  @override
  String inventorySeconds(String count) {
    return '$count sec';
  }

  @override
  String inventoryExpiresIn(String count) {
    return 'Expires in $count blocks';
  }

  @override
  String inventoryExpiringIn(String count) {
    return 'Expiring · in $count blocks';
  }

  @override
  String inventoryNextExpiry(String count) {
    return 'Next expiry in $count blocks';
  }

  @override
  String get inventoryExpiredNote =>
      'This VTXO has expired and can’t be renewed.';

  @override
  String get inventoryLockedNote =>
      'This VTXO can’t be spent or renewed until its pending operation finishes.';

  @override
  String inventoryRenewNote(String count) {
    return 'Auto-renew is configured $count blocks before expiry. Open the app regularly to keep your VTXOs current.';
  }

  @override
  String get inventoryVtxoId => 'VTXO ID';

  @override
  String get inventoryAnchor => 'Anchor point';

  @override
  String get inventoryExpires => 'Expires';

  @override
  String get inventoryBlocksLeft => 'Blocks left';

  @override
  String get inventoryTotal => 'Total excluding expired VTXOs';

  @override
  String get inventoryEmptyTitle => 'No VTXOs yet';

  @override
  String get inventoryEmptyBody => 'Bitcoin you receive shows up here.';

  @override
  String get inventoryTechnicalDetails => 'Technical details';

  @override
  String get inventoryOpenAccount => 'Open Ark wallet';

  @override
  String get inventoryServerPublicKey => 'Server public key';

  @override
  String get inventoryMinimumBoard => 'Minimum board amount';

  @override
  String get inventoryMaximumVtxo => 'Maximum VTXO amount';

  @override
  String get inventoryConfirmations => 'Required confirmations';

  @override
  String get inventoryLifetime => 'VTXO lifetime';

  @override
  String get inventoryRoundInterval => 'Round interval';

  @override
  String get payFrom => 'Pay from';

  @override
  String get additionalInformation => 'Additional Information';

  @override
  String get additionalInformationHint => 'Add an amount or message for sender';

  @override
  String get arkAddressInformationUnavailable =>
      'Amounts and messages cannot be added to this Ark address. Use a Lightning invoice to request an amount.';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get paymentNoteUnavailable =>
      'Notes are not supported for this payment.';

  @override
  String get addressActions => 'Address';

  @override
  String get maxBalanceInputHint =>
      'The final amount and network fees are checked before confirmation.';

  @override
  String boardMinimumWithNetworkFees(String minimum) {
    return 'Minimum amount $minimum + network fees';
  }

  @override
  String boardAmountBelowMinimum(String minimum) {
    return 'Amount is too low. Minimum is $minimum + fees';
  }

  @override
  String get boardFeeEstimate => 'Fee estimate';

  @override
  String get boardArkBalanceReceives => 'Ark balance receives';

  @override
  String get boardArkBoardingFee => 'Ark boarding fee';

  @override
  String get boardEstimateUnavailable => 'Fee estimate unavailable';

  @override
  String get boardMinimumUnavailable => 'Minimum amount unavailable';

  @override
  String get boardStarted => 'Boarding started';

  @override
  String get boardStartedDescription =>
      'Your on-chain bitcoin is moving into Ark. It will become spendable after the board completes.';

  @override
  String get boardFundingTransaction => 'Funding transaction';

  @override
  String get boardFundingId => 'Funding ID';

  @override
  String boardFundingOptions(String id) {
    return 'Funding transaction $id. Show options';
  }

  @override
  String get boardFundingIdCopied => 'Funding ID copied';

  @override
  String get boardFundingUnavailable => 'Funding transaction unavailable';

  @override
  String get boardCopyFundingId => 'Copy transaction ID';

  @override
  String get boardCopyLink => 'Copy link';

  @override
  String get boardViewInExplorer => 'View in explorer';

  @override
  String get boardLinkCopied => 'Link copied';

  @override
  String get boardVerificationPending => 'Boarding status needs verification';

  @override
  String get exitHoldToStart => 'Hold to start exit';

  @override
  String get exitKeepHolding => 'Keep holding…';

  @override
  String get exitConfirmAccessible => 'Confirm emergency exit';

  @override
  String get exitNoCancellation =>
      'A started exit cannot be canceled from this app. Progress and claim remain explicit actions.';

  @override
  String get exitIntendedDestination => 'Intended claim destination';

  @override
  String get exitReserveFees =>
      'Exit transaction fees are paid from the Ark on-chain reserve. Claim fees are reviewed separately before claiming.';

  @override
  String get exitUnrolling => 'Unrolling exit transactions';

  @override
  String get exitDelay => 'Exit delay';

  @override
  String get exitManualClaim =>
      'Review a claim when the exit is claimable. No automatic claim is authorized.';

  @override
  String get exitYourExits => 'Your exits';

  @override
  String get exitReviewTitle => 'Review exit';

  @override
  String get exitClaimAction => 'Claim';

  @override
  String get exitDetailsTitle => 'Exit details';

  @override
  String exitConfirmedAtBlock(String height) {
    return 'Confirmed at block $height';
  }

  @override
  String exitBlocksRemaining(String count) {
    return '$count blocks remaining';
  }

  @override
  String get exitCanceled => 'Exit canceled';

  @override
  String get movementBoardedLabel => 'Boarded';

  @override
  String get movementReceivedLabel => 'Received';

  @override
  String get activityStartHint =>
      'Receive bitcoin or board from your on-chain wallet to start using Ark.';

  @override
  String get pasteAddress => 'Paste recipient’s address';

  @override
  String get inventoryHtlcSendExpiryDelta => 'Outgoing HTLC expiry delta';

  @override
  String get inventoryHtlcExpiryDelta =>
      'Lightning / Ark HTLC expiry difference';

  @override
  String get inventoryRoundNonceCount => 'Nonces per round';

  @override
  String inventoryBlockHeight(String height) {
    return 'Block $height';
  }

  @override
  String get operationDetails => 'Operation details';

  @override
  String get operationRequestCompleted =>
      'Request completed. Chain settlement and round completion are separate.';

  @override
  String get exitNotStarted => 'Exit not started';
}
