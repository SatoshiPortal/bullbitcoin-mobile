import 'package:send/generated/l10n/send_localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullOnchainSendLabels;

extension OnchainSendLabelsL10n on SendLocalizations {
  BullOnchainSendLabels get onchainSendLabels => (
    from: coreScreensFromLabel,
    to: coreScreensToLabel,
    selfTransfer: sendSelfTransfer,
    payjoin: sendPayjoinLabel,
    note: receiveNote,
    amount: coreScreensAmountLabel,
    networkFee: coreScreensNetworkFeesLabel,
    feePriority: coreScreensFeePriorityLabel,
  );
}
