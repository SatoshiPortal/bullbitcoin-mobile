import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/swap/presentation/swap_provider_settings_cubit.dart';
import 'package:bb_mobile/features/swap/providers/swap_pending_probe.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

typedef BoltzEngineBuilder =
    BoltzEnginePort Function(SwapProviderConfig config);

class SwapProvidersLocator {
  static const defaultActiveProviderId = 'bull';

  static const builtInProviders = [
    SwapProviderConfig(
      id: 'bull',
      kind: SwapProviderKind.bull,
      name: 'Bull Bitcoin',
      isBuiltIn: true,
    ),
    SwapProviderConfig(
      id: 'boltz',
      kind: SwapProviderKind.boltz,
      name: 'Boltz',
      baseUrl: ApiServiceConstants.boltzMainnetUrlPath,
      isBuiltIn: true,
    ),
  ];

  static Future<void> register(
    GetIt locator, {
    required SwapDatabase database,
    required BoltzEngineBuilder buildBoltzEngine,
  }) async {
    locator.registerLazySingleton<SwapDatabase>(() => database);

    final store = SwapProviderStore(database);
    locator.registerLazySingleton<SwapProviderStore>(() => store);

    final factory = SwapProviderFactoryImpl(
      buildBull: (config) => BullSwapProvider(
        _exchangeDatasource(ApiServiceConstants.swapApiStagingUrl),
        _exchangeDatasource(ApiServiceConstants.swapApiMainnetUrl),
        config: config,
      ),
      buildBoltz: (config) =>
          BoltzSwapProvider(buildBoltzEngine(config), config: config),
    );

    final resolver = SwapProviderResolver(store, factory);
    locator.registerLazySingleton<SwapProviderResolver>(() => resolver);

    final probe = SwapPendingProbe(
      locator<OrderSwapRepository>(),
      locator<BoltzSwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ),
    );
    locator.registerLazySingleton<SwitchSwapProvider>(
      () => SwitchSwapProvider(store, probe, resolver),
    );

    locator.registerFactory<SwapProviderSettingsCubit>(
      () => SwapProviderSettingsCubit(
        locator<SwapProviderStore>(),
        locator<SwitchSwapProvider>(),
      ),
    );

    await store.ensureSeeded(builtInProviders, defaultActiveProviderId);
  }

  static ExchangePublicApiDatasource _exchangeDatasource(String baseUrl) =>
      ExchangePublicApiDatasource(
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
      );
}
