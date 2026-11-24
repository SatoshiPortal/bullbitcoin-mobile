import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'exchange_payout_field.dart';

typedef ExchangePurchaseHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  AmountDisplayPreferencesReader Function() displayPreferences,
  WalletInventory Function() inventory,
  WalletNativeLifecycle Function() native,
  Fees Function() fees,
  PayjoinSessions Function() payjoinSessions,
  PayjoinReceiver Function() payjoinReceiver,
  PayjoinPolicyAccess Function() payjoinPolicy,
  Future<void> Function(String) pollWallet,
  Future<void> Function(List<Order>) labelOrders,
  Future<String?> Function(String) validateBitcoinAddress,
  ExchangePayoutField payoutField,
  String bitcoinAsset,
  void Function(BuildContext) onClose,
  void Function(BuildContext, String) openOrder,
});
