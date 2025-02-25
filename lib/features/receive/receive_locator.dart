import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
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
    // Bloc
    locator.registerFactory<ReceiveBloc>(() => ReceiveBloc());
  }
}
