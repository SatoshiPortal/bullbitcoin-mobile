import 'domain/entities/swap_wallet.dart';

import 'package:flutter/widgets.dart';
import 'package:bull_ui/bull_ui.dart' show BullOnchainSendLabels;

import '../generated/l10n/swap_localizations.dart';

SwapLocalizations swapCopy(String localeName) {
  final tag = localeName.replaceAll('_', '-').toLowerCase();
  final supported = SwapLocalizations.supportedLocales;
  for (final locale in supported) {
    if (locale.toLanguageTag().toLowerCase() == tag) {
      return lookupSwapLocalizations(locale);
    }
  }
  final language = Locale(tag.split('-').first);
  return lookupSwapLocalizations(
    supported.contains(language) ? language : const Locale('en'),
  );
}

extension SwapCopyContext on BuildContext {
  SwapLocalizations get swapCopyForLocale =>
      swapCopy(Localizations.localeOf(this).toLanguageTag());
}

extension OnchainSendLabelsL10n on SwapLocalizations {
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

extension SwapWalletLabel on SwapWallet {
  String swapWalletLabel(BuildContext context) {
    if (!isDefault) {
      return label ??
          (id.endsWith(':regtest')
              ? id.substring(0, id.length - ':regtest'.length)
              : id);
    }
    final copy = context.swapCopyForLocale;
    return isLiquid
        ? copy.globalDefaultLiquidWalletLabel
        : copy.globalDefaultBitcoinWalletLabel;
  }
}
