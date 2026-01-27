import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';

class ElectrumSettingsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {}

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<ElectrumSettingsBloc>(
      () => ElectrumSettingsBloc(
        loadElectrumServerDataUsecase: sl(),
        addCustomServerUsecase: sl(),
        setCustomServersPriorityUsecase: sl(),
        deleteCustomServerUsecase: sl(),
        setAdvancedElectrumOptionsUsecase: sl(),
      ),
    );
  }
}
