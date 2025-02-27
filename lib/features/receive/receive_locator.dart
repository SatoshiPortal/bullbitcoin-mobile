import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';

class ReceiveLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<GetReceiveAddressUseCase>(
      () => GetReceiveAddressUseCase(
        walletRepositoryManager: locator<WalletRepositoryManager>(),
      ),
    );
    locator.registerFactory<CreateReceiveSwapUseCase>(
      () => CreateReceiveSwapUseCase(
        walletRepositoryManager: locator<WalletRepositoryManager>(),
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
