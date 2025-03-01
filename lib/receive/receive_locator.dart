import 'package:bb_mobile/_core/core_locator.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';

class ReceiveLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<GetReceiveAddressUseCase>(
      () => GetReceiveAddressUseCase(
        walletManager: locator<WalletManager>(),
      ),
    );
    locator.registerFactory<CreateReceiveSwapUseCase>(
      () => CreateReceiveSwapUseCase(
        walletManager: locator<WalletManager>(),
        swapRepository: locator<SwapRepository>(
          instanceName: CoreLocator.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<SwapRepository>(
          instanceName: CoreLocator.boltzSwapRepositoryTestnetInstanceName,
        ),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<ReceiveBloc>(
      () => ReceiveBloc(
        getReceiveAddressUseCase: locator<GetReceiveAddressUseCase>(),
        createReceiveSwapUseCase: locator<CreateReceiveSwapUseCase>(),
      ),
    );
  }
}
