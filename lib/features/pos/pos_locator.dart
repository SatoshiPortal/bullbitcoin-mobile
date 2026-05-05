import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/pos/adapters/merchant_key_provider/seed_derived_merchant_key_provider.dart';
import 'package:bb_mobile/features/pos/adapters/nostr_relay_pool/sdk_relay_pool_adapter.dart';
import 'package:bb_mobile/features/pos/adapters/pos_settlement_descriptor/liquid_wallet_settlement_descriptor_provider.dart';
import 'package:bb_mobile/features/pos/adapters/pos_storage/drift_pos_storage_adapter.dart';
import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_settlement_descriptor_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/application/pos_cashier_config.dart';
import 'package:bb_mobile/features/pos/application/services/pos_recovery_claim_builder.dart';
import 'package:bb_mobile/features/pos/application/usecases/init_pos_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/pair_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/publish_pos_profile_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/revoke_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/run_swap_recovery_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/watch_sales_usecase.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_recovery_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_sales_cubit.dart';
import 'package:get_it/get_it.dart';

class PosLocator {
  static void setup(GetIt locator) {
    _registerAdapters(locator);
    _registerUsecases(locator);
    _registerPresentation(locator);
  }

  static void _registerAdapters(GetIt locator) {
    locator.registerLazySingleton<MerchantKeyProviderPort>(
      () => SeedDerivedMerchantKeyProvider(
        seedDatasource: locator<SeedDatasource>(),
      ),
    );
    locator.registerLazySingleton<NostrRelayPoolPort>(
      () => const SdkRelayPoolAdapter(),
    );
    locator.registerLazySingleton<PosSettlementDescriptorPort>(
      () => const LiquidWalletSettlementDescriptorProvider(),
    );
    locator.registerLazySingleton<PosStoragePort>(
      () => DriftPosStorageAdapter(
        database: locator<SqliteDatabase>(),
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
    locator.registerLazySingleton<PosCashierConfig>(
      () => const PosCashierConfig(),
    );
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<InitPosUsecase>(
      () => InitPosUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        storage: locator<PosStoragePort>(),
      ),
    );
    locator.registerFactory<PublishPosProfileUsecase>(
      () => PublishPosProfileUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        relayPool: locator<NostrRelayPoolPort>(),
        cashierConfig: locator<PosCashierConfig>(),
      ),
    );
    locator.registerFactory<PairTerminalUsecase>(
      () => PairTerminalUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        relayPool: locator<NostrRelayPoolPort>(),
        storage: locator<PosStoragePort>(),
        descriptorProvider: locator<PosSettlementDescriptorPort>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
      ),
    );
    locator.registerFactory<WatchSalesUsecase>(
      () => WatchSalesUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        relayPool: locator<NostrRelayPoolPort>(),
        storage: locator<PosStoragePort>(),
      ),
    );
    locator.registerFactory<RevokeTerminalUsecase>(
      () => RevokeTerminalUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        relayPool: locator<NostrRelayPoolPort>(),
        storage: locator<PosStoragePort>(),
      ),
    );
    locator.registerFactory<RunSwapRecoveryUsecase>(
      () => RunSwapRecoveryUsecase(
        keyProvider: locator<MerchantKeyProviderPort>(),
        relayPool: locator<NostrRelayPoolPort>(),
        storage: locator<PosStoragePort>(),
        claimBuilderFactory: (network) =>
            PosRecoveryClaimBuilder(network: network).call,
      ),
    );
  }

  static void _registerPresentation(GetIt locator) {
    locator.registerFactory<PosCubit>(
      () => PosCubit(
        storage: locator<PosStoragePort>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        initPosUsecase: locator<InitPosUsecase>(),
        publishPosProfileUsecase: locator<PublishPosProfileUsecase>(),
        pairTerminalUsecase: locator<PairTerminalUsecase>(),
        revokeTerminalUsecase: locator<RevokeTerminalUsecase>(),
      ),
    );
    locator.registerFactory<PosSalesCubit>(
      () => PosSalesCubit(watchSalesUsecase: locator<WatchSalesUsecase>()),
    );
    locator.registerFactory<PosRecoveryCubit>(
      () => PosRecoveryCubit(
        runSwapRecoveryUsecase: locator<RunSwapRecoveryUsecase>(),
      ),
    );
  }
}
