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
    locator.registerFactory<GetReceiveAddressUseCase>(
      () => GetReceiveAddressUseCase(
        walletManager: locator<WalletManagerService>(),
      ),
    );
    locator.registerFactory<CreateReceiveSwapUseCase>(
      () => CreateReceiveSwapUseCase(
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
        getWalletsUseCase: locator<GetWalletsUseCase>(),
        getReceiveAddressUseCase: locator<GetReceiveAddressUseCase>(),
        createReceiveSwapUseCase: locator<CreateReceiveSwapUseCase>(),
      ),
    );
  }
}
