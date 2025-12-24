import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';

class AddressViewDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<GetAddressListUsecase>(
      () => GetAddressListUsecase(walletAddressRepository: sl()),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<AddressViewBloc, String, int?>(
      (walletId, limit) => AddressViewBloc(
        getAddressListUseCase: sl(),
        walletId: walletId,
        limit: limit,
      ),
    );
  }
}
