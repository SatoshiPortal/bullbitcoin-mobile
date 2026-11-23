import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullOnchainSendLabels;

extension OnchainSendLabelsL10n on AppLocalizations {
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
