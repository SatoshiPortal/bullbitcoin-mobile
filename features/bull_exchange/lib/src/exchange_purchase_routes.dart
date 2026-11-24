import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'dca/domain/usecases/get_dca_default_wallets_usecase.dart';
import 'dca/domain/usecases/set_dca_usecase.dart';
import 'dca/domain/usecases/start_dca_usecase.dart';
import 'dca/presentation/dca_bloc.dart';
import 'dca/ui/dca_router.dart';
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

GoRoute mountDca(ExchangePurchaseHost host) => DcaRouter.route(
  payoutField: host.payoutField,
  createBloc: () {
    final exchange = host.exchange();
    final preferences = host.preferences();
    return DcaBloc(
      startDcaUsecase: StartDcaUsecase(
        settingsRepository: preferences,
        exchange: exchange,
      ),
      getDcaDefaultWalletsUsecase: GetDcaDefaultWalletsUsecase(
        exchange: exchange,
      ),
      setDcaUsecase: SetDcaUsecase(
        settingsRepository: preferences,
        exchange: exchange,
      ),
    );
  },
);
