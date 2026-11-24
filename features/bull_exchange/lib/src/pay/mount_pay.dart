import 'package:bull_exchange/src/pay/domain/retry_payjoin_proposal_usecase.dart';
import 'package:bull_exchange/src/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/estimate_pay_payin_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_exchange_rate_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bull_exchange/src/pay/domain/broadcast_payjoin_original_usecase.dart';
import 'package:bull_exchange/src/pay/domain/get_visible_payjoin_transaction_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_user_summary_usecase.dart';
import 'package:bull_exchange/src/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:bull_exchange/src/pay/domain/place_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/refresh_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/send_with_payjoin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/sign_pay_payin_usecase.dart';
import 'package:bull_exchange/src/pay/domain/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_exchange/src/pay/ui/pay_router.dart';
import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/payin/exchange_payin_host.dart';
import 'package:go_router/go_router.dart';

ShellRoute mountPay(ExchangePayinHost host) => PayRouter.route(
  ui: host.ui,

  createBloc: () {
    final exchange = host.exchange();
    final preferences = host.preferences();
    final spend = host.spend();
    final wallets = InventoryPayinWallets(host.inventory(), host.native());
    final account = PayinAccount(exchange, preferences);
    final sender = host.payjoinSender();
    final sessions = host.payjoinSessions();

    final prepareBitcoin = PreparePayBitcoinPayinUsecase(spend);
    final prepareLiquid = PreparePayLiquidPayinUsecase(spend);
    final address = GetPayPayinAddressUsecase(wallets);
    final fees = LoadPayNetworkFeesUsecase(
      fees: host.fees(),
      preferences: preferences,
    );

    return PayBloc(
      preparePayBitcoinPayinUsecase: prepareBitcoin,
      preparePayLiquidPayinUsecase: prepareLiquid,
      signPayPayinUsecase: SignPayPayinUsecase(spend),
      broadcastPayPayinUsecase: BroadcastPayPayinUsecase(spend),
      sendWithPayjoinUsecase: SendWithPayjoinUsecase(sender, spend),
      watchPayjoinUsecase: WatchPayjoinUsecase(sessions),
      getAdoptablePayjoinSenderUsecase: GetAdoptablePayjoinSenderUsecase(
        sessions,
      ),
      broadcastPayjoinOriginalUsecase: BroadcastPayjoinOriginalUsecase(sender),
      getVisiblePayjoinTransactionUsecase: GetVisiblePayjoinTransactionUsecase(
        sessions,
      ),
      retryPayjoinProposalUsecase: RetryPayjoinProposalUsecase(sender),
      loadPayWalletUtxosUsecase: LoadPayWalletUtxosUsecase(wallets),
      refreshPayOrderUsecase: RefreshPayOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
      ),
      spend: spend,

      loadPayUserSummaryUsecase: LoadPayUserSummaryUsecase(account),
      getPayOrderUsecase: GetPayOrderUsecase(account),
      placePayOrderUsecase: PlacePayOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
        payjoinPolicy: host.payjoinPolicy(),
        wallets: wallets,
      ),
      getPayPayinAddressUsecase: address,
      loadPayNetworkFeesUsecase: fees,
      estimatePayPayinFeesUsecase: EstimatePayPayinFeesUsecase(
        getPayExchangeRateUsecase: GetPayExchangeRateUsecase(
          getSettingsUsecase: preferences,
          getIndexPrice: Pricer.getIndexPrice,
        ),
        getPayPayinAddressUsecase: address,
        loadPayNetworkFeesUsecase: fees,
        preparePayBitcoinPayinUsecase: prepareBitcoin,
        preparePayLiquidPayinUsecase: prepareLiquid,
      ),
    );
  },
);
