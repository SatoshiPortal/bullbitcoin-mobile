import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label_wallet_address_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_new_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/locator.dart';

class ReceiveLocator {
  static void setup() {
    locator.registerFactory<CreateReceiveSwapUsecase>(
      () => CreateReceiveSwapUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        seedRepository: locator<SeedRepository>(),
        getNewAddressUsecase: locator<GetNewReceiveAddressUsecase>(),
        labelRepository: locator<LabelRepository>(),
      ),
    );

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getNewReceiveAddressUsecase: locator<GetNewReceiveAddressUsecase>(),
        createReceiveSwapUsecase: locator<CreateReceiveSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchWalletTransactionByAddressUsecase:
            locator<WatchWalletTransactionByAddressUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        labelWalletAddressUsecase: locator<LabelWalletAddressUsecase>(),
        getSwapLimitsUsecase: locator<GetSwapLimitsUsecase>(),
        wallet: wallet,
      ),
    );
  }
}
