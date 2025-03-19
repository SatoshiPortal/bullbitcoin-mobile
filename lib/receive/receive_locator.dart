import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';

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
    locator.registerFactory<ReceiveBloc>(
      () => ReceiveBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        createReceiveSwapUsecase: locator<CreateReceiveSwapUsecase>(),
      ),
    );
  }
}
