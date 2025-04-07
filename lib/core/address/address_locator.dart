import 'package:bb_mobile/core/address/data/repositories/address_repository_impl.dart';
import 'package:bb_mobile/core/address/domain/repositories/address_repository.dart';
import 'package:bb_mobile/core/address/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/core/address/usecases/get_used_receive_addresses_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/locator.dart';

class AddressLocator {
  static void registerRepositories() {
    locator.registerLazySingleton<AddressRepository>(
      () => AddressRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetReceiveAddressUsecase>(
      () => GetReceiveAddressUsecase(
        addressRepository: locator<AddressRepository>(),
      ),
    );

    locator.registerFactory<GetUsedReceiveAddressesUsecase>(
      () => GetUsedReceiveAddressesUsecase(
        addressRepository: locator<AddressRepository>(),
      ),
    );
  }
}
