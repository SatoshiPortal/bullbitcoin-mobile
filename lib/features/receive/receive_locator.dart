import 'domain/usecases/get_receive_swap_limits_usecase.dart';

import 'package:receive/receive.dart';

import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/receive/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_boltz_receive_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_swap_route_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:swaps/swaps.dart'
    show BoltzSwaps, SwapWatcher, WatchSwapUsecase, GetSwapLimitsAndFeesUsecase;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';

class ReceiveLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<PollReceiveWalletUsecase>(
      () => PollReceiveWalletUsecase(locator<WalletFacade>()),
    );
    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(locator<PayjoinReceiver>()),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetReceivePayjoinPolicyUsecase>(
      () => GetReceivePayjoinPolicyUsecase(locator<SettingsFacade>()),
    );
    locator.registerFactory<WatchReceivePayjoinEnabledUsecase>(
      () => WatchReceivePayjoinEnabledUsecase(locator<SettingsFacade>()),
    );
    locator.registerFactory<CreateReceiveOrderSwapUsecase>(
      () => CreateReceiveOrderSwapUsecase(
        locator<SwapFacade>(),
        locator<AddressView>(),
      ),
    );
    locator.registerFactory<GetReceiveSwapRouteUsecase>(
      () => GetReceiveSwapRouteUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<CreateBoltzReceiveSwapUsecase>(
      () => CreateBoltzReceiveSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<SetReceivePayjoinEnabledUsecase>(
      () => SetReceivePayjoinEnabledUsecase(
        settingsFacade: locator<SettingsFacade>(),
      ),
    );
    locator.registerFactory<WatchReceivePayjoinMinAmountUsecase>(
      () => WatchReceivePayjoinMinAmountUsecase(
        settingsFacade: locator<SettingsFacade>(),
      ),
    );
    locator.registerFactory<WatchReceiveOrderSwapUsecase>(
      () => WatchReceiveOrderSwapUsecase(locator<SwapFacade>()),
    );

    // The remaining legacy wallet reads still map exceptions before the bloc.
    locator.registerFactory<GetReceiveWalletsUsecase>(
      () => GetReceiveWalletsUsecase(locator<GetWalletsUsecase>()),
    );
    locator.registerFactory<PrepareReceiveAddressUsecase>(
      () => PrepareReceiveAddressUsecase(locator<AddressView>()),
    );
    locator.registerFactory<GetReceiveAddressAtIndexUsecase>(
      () => GetReceiveAddressAtIndexUsecase(locator<AddressView>()),
    );

    locator.registerFactory<GetReceiveSwapLimitsUsecase>(
      () => GetReceiveSwapLimitsUsecase(locator<GetSwapLimitsAndFeesUsecase>()),
    );

    locator.registerLazySingleton<Receive>(
      () => Receive.open(
        addresses: locator<AddressView>(),
        labels: locator<Labels>(),
        preferences: locator<Preferences>(),
        readPrice: Pricer.getIndexPrice,
        readPrices: Pricer.getIndexPrices,
      ),
    );

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getReceiveSwapLimitsUsecase: locator<GetReceiveSwapLimitsUsecase>(),
        getReceiveWalletsUsecase: locator<GetReceiveWalletsUsecase>(),
        receive: locator<Receive>(),
        prepareReceiveAddressUsecase: locator<PrepareReceiveAddressUsecase>(),
        createReceiveOrderSwapUsecase: locator<CreateReceiveOrderSwapUsecase>(),
        getReceiveSwapRouteUsecase: locator<GetReceiveSwapRouteUsecase>(),
        createBoltzReceiveSwapUsecase: locator<CreateBoltzReceiveSwapUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchWalletTransactionByAddressUsecase:
            locator<WatchWalletTransactionByAddressUsecase>(),
        watchReceiveOrderSwapUsecase: locator<WatchReceiveOrderSwapUsecase>(),
        watchReceivePayjoinEnabledUsecase:
            locator<WatchReceivePayjoinEnabledUsecase>(),
        watchReceivePayjoinMinAmountUsecase:
            locator<WatchReceivePayjoinMinAmountUsecase>(),
        getReceivePayjoinPolicyUsecase:
            locator<GetReceivePayjoinPolicyUsecase>(),
        setReceivePayjoinEnabledUsecase:
            locator<SetReceivePayjoinEnabledUsecase>(),
        wallet: wallet,
      ),
    );
  }
}
