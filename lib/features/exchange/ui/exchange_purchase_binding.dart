import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/services.dart' show TextInputType;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:sync/write.dart' show WalletNativeRuntime;

/// Binds the remaining app-only presentation, navigation and receipt effects.
ExchangePurchaseHost exchangePurchaseHost(GetIt locator) => (
  exchange: () => locator<Exchange>(),
  preferences: () => locator<Preferences>(),
  displayPreferences: () => locator<AmountDisplayPreferencesReader>(),
  inventory: () => locator<SecretsInventory>(),
  native: () => locator<WalletNativeRuntime>(),
  fees: () => locator<Fees>(),
  payjoinSessions: () => locator<PayjoinSessions>(),
  payjoinReceiver: () => locator<PayjoinReceiver>(),
  payjoinPolicy: () => locator<PayjoinPolicyAccess>(),
  pollWallet: (id) =>
      locator<WalletFacade>().pollWallet(id, isActive: () => true),
  labelOrders: (orders) =>
      locator<TransactionsFacade>().labelCompletedExchangeOrders(orders),
  validateBitcoinAddress: (raw) async =>
      (await const WalletPaymentDestinationFacade().validate(
        raw,
        acceptedTypes: const {PaymentDestinationType.bitcoin},
      ))?.address,
  payoutField:
      ({
        required type,
        required value,
        required label,
        required hint,
        required enabled,
        required onChanged,
        required onValidated,
      }) => PaymentDestinationField(
        value: value,
        label: label,
        hint: hint,
        enabled: enabled,
        acceptedTypes: {
          switch (type) {
            WalletAddressType.bitcoin => PaymentDestinationType.bitcoin,
            WalletAddressType.liquid => PaymentDestinationType.liquid,
            WalletAddressType.lightning =>
              PaymentDestinationType.lightningAddress,
          },
        },
        allowLnurl: type != WalletAddressType.lightning,
        keyboardType: type == WalletAddressType.lightning
            ? TextInputType.emailAddress
            : TextInputType.text,
        onChanged: onChanged,
        onValidated: (destination) => onValidated(destination?.address),
      ),
  bitcoinAsset: Assets.icons.btc.path,
  onClose: (context) => context.goNamed(WalletRoute.walletHome.name),
  openOrder: (context, id) => context.pushNamed(
    TransactionsRoute.orderTransactionDetails.name,
    pathParameters: {'orderId': id},
  ),
);
