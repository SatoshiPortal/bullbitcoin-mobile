import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:spend/spend.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:transactions/routes.dart';
import 'package:transactions/transactions.dart';

/// Binds the app-owned wallet cards, wallet-home route and assets. Remove this
/// binding once those are available from workspace features; `bull_exchange`
/// cannot import the app that mounts it.
ExchangePayinHost exchangePayinHost(GetIt locator) => (
  exchange: () => locator<Exchange>(),
  preferences: () => locator<Preferences>(),
  inventory: () => locator<SecretsInventory>(),
  native: () => locator<WalletNativeRuntime>(),
  spend: () => locator<Spend>(),
  fees: () => locator<Fees>(),
  payjoinPolicy: () => locator<PayjoinPolicyAccess>(),
  payjoinSender: () => locator<PayjoinSender>(),
  payjoinSessions: () => locator<PayjoinSessions>(),
  labels: () => locator<Labels>(),
  labelOrders: (orders) =>
      locator<Transactions>().labelCompletedExchangeOrders(orders),
  ui: (
    walletCards: (_, onTap) => WalletCards(
      padding: EdgeInsets.zero,
      onTap: onTap == null
          ? null
          : (wallet) => onTap(
              ExchangePayinWallet(
                key: WalletKey(id: wallet.id, network: wallet.network.shared),
                balanceSat: wallet.balanceSat,
                label: wallet.label,
                isDefault: wallet.isDefault,
              ),
            ),
      localSignersOnly: true,
    ),
    addressViewer: (_, address, {style, color, textAlign}) => AddressViewer(
      address,
      style: style,
      color: color,
      textAlign: textAlign,
    ),
    openWalletHome: (context) => context.goNamed(WalletRoute.walletHome.name),
    openOrder: (context, id, {required returnToExchange}) =>
        TransactionsNavigation.openDetails(
          context,
          TransactionDetailsTarget.order(id),
          returnToExchange: returnToExchange,
        ),
    openPayjoinTransaction: (context, txId) =>
        TransactionsNavigation.openDetails(
          context,
          TransactionDetailsTarget.payjoinByTxId(txId),
          returnToExchange: true,
        ),
    brandAsset: Assets.logos.bbLogoSmall.path,
    successAsset: Assets.animations.successTick.path,
  ),
);
