import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/core/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/locator.dart';

class ReceiveLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        walletManager: locator<WalletManagerService>(),
      ),
    );
    locator.registerFactory<CreateReceiveSwapUsecase>(
      () => CreateReceiveSwapUsecase(
        walletManager: locator<WalletManagerService>(),
        swapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<SwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getCurrencyUsecase: locator<GetCurrencyUsecase>(),
        getBitcoinUnitUseCase: locator<GetBitcoinUnitUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        createReceiveSwapUsecase: locator<CreateReceiveSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        wallet: wallet,
      ),
    );
  }
}
