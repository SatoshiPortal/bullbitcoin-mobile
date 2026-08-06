import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:get_it/get_it.dart';

class ReceiveLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CreateReceiveOrderSwapUsecase>(
      () => CreateReceiveOrderSwapUsecase(
        locator<SwapFacade>(),
        locator<GetReceiveAddressUsecase>(),
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

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        getAddressAtIndexUsecase: locator<GetAddressAtIndexUsecase>(),
        createReceiveOrderSwapUsecase: locator<CreateReceiveOrderSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchWalletTransactionByAddressUsecase:
            locator<WatchWalletTransactionByAddressUsecase>(),
        watchReceiveOrderSwapUsecase: locator<WatchReceiveOrderSwapUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        watchPayjoinEnabledChangesUsecase:
            locator<WatchPayjoinEnabledChangesUsecase>(),
        watchReceivePayjoinMinAmountUsecase:
            locator<WatchReceivePayjoinMinAmountUsecase>(),
        setReceivePayjoinEnabledUsecase:
            locator<SetReceivePayjoinEnabledUsecase>(),
        wallet: wallet,
      ),
    );
  }
}
