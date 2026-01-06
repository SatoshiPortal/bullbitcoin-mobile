import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:get_it/get_it.dart';

class AddressViewLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetAddressListUsecase>(
      () => GetAddressListUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    // Register the AddressViewBloc with the locator
    locator.registerFactoryParam<AddressViewBloc, String, int?>(
      (walletId, limit) => AddressViewBloc(
        getAddressListUseCase: locator<GetAddressListUsecase>(),
        walletId: walletId,
        limit: limit,
      ),
    );
  }
}
