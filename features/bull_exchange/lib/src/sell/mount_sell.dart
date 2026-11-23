import 'package:bull_exchange/src/payin/exchange_payin_host.dart';
import 'package:bull_exchange/src/sell/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/broadcast_sell_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/broadcast_payjoin_original_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_visible_payjoin_transaction_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/label_completed_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_wallet_utxos_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/prepare_sell_liquid_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/read_sell_payin_txid_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/sign_sell_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_exchange/src/sell/presentation/sell_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_exchange/src/sell/domain/usecases/store_sell_transaction_label_usecase.dart';
import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/sell/ui/sell_router.dart';
import 'package:go_router/go_router.dart';

ShellRoute mountSell(ExchangePayinHost host) => SellRouter.route(
  ui: host.ui,
  availability: () =>
      GetSellConfidentialSepaAvailabilityUsecase(host.exchange()),
  createBloc: () {
    final exchange = host.exchange();
    final preferences = host.preferences();
    final spend = host.spend();
    final wallets = InventoryPayinWallets(host.inventory(), host.native());
    final account = PayinAccount(exchange, preferences);
    final sender = host.payjoinSender();
    final sessions = host.payjoinSessions();

    final prepareBitcoin = PrepareSellBitcoinPayinUsecase(spend);
    final prepareLiquid = PrepareSellLiquidPayinUsecase(spend);

    return SellBloc(
      prepareSellBitcoinPayinUsecase: prepareBitcoin,
      prepareSellLiquidPayinUsecase: prepareLiquid,
      signSellPayinUsecase: SignSellPayinUsecase(spend),
      broadcastSellPayinUsecase: BroadcastSellPayinUsecase(spend),
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
      loadSellWalletUtxosUsecase: LoadSellWalletUtxosUsecase(wallets),
      refreshSellOrderUsecase: RefreshSellOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
      ),
      spend: spend,

      loadSellContextUsecase: LoadSellContextUsecase(
        account: account,
        getSettingsUsecase: preferences,
        fees: host.fees(),
        wallets: wallets,
        getIndexPrice: Pricer.getIndexPrice,
      ),
      createSellOrderUsecase: CreateSellOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
        payjoinPolicy: host.payjoinPolicy(),
        wallets: wallets,
      ),
      readSellPayinTxidUsecase: const ReadSellPayinTxidUsecase(),
      storeSellTransactionLabel: StoreSellTransactionLabelUsecase(
        host.labels(),
      ),
      labelCompletedSellOrderUsecase: LabelCompletedSellOrderUsecase(
        host.labelOrders,
      ),
    );
  },
);
