import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/check_wallet_is_liquid_usecase.dart';
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
        walletAddressRepository: locator<LabeledWalletAddressRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletIsLiquidUsecase>(
      () => CheckWalletIsLiquidUsecase(
        getWalletUsecase: locator<GetWalletUsecase>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    // Register the AddressViewBloc with the locator
    locator.registerFactoryParam<AddressViewBloc, String, int?>(
      (walletId, limit) => AddressViewBloc(
        checkWalletIsLiquidUsecase: locator<CheckWalletIsLiquidUsecase>(),
        getAddressListUsecase: locator<GetAddressListUsecase>(),
        walletId: walletId,
        limit: limit,
      ),
    );
  }
}
