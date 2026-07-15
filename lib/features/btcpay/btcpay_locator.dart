import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/btcpay/data/btcpay_connection_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/btcpay_connection_datasource.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/samrock_pairing_datasource.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_service_port.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

class BtcpayLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BtcpayConnectionRepository>(
      () => BtcpayConnectionRepositoryImpl(
        BtcpayConnectionDatasource(
          storage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
        ),
      ),
    );
    locator.registerLazySingleton<SamRockPairingServicePort>(
      () => SamRockPairingDatasource(),
    );
    locator.registerFactory<SamRockPairingRequestParser>(
      () => const SamRockPairingRequestParser(),
    );
    locator.registerFactory<GetBtcpayConnectionUsecase>(
      () => GetBtcpayConnectionUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        connectionRepository: locator<BtcpayConnectionRepository>(),
      ),
    );
    locator.registerFactory<GetBtcpayWalletBehaviorsUsecase>(
      () => GetBtcpayWalletBehaviorsUsecase(
        getWallets: locator<GetWalletsUsecase>(),
      ),
    );
    locator.registerFactory<PreviewBtcpaySamRockPairingUsecase>(
      () => PreviewBtcpaySamRockPairingUsecase(
        parser: locator<SamRockPairingRequestParser>(),
      ),
    );
    locator.registerFactory<CompleteBtcpaySamRockPairingUsecase>(
      () => CompleteBtcpaySamRockPairingUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        parser: locator<SamRockPairingRequestParser>(),
        deterministicWallets: locator<DeterministicWalletsFacade>(),
        pairingService: locator<SamRockPairingServicePort>(),
        connectionRepository: locator<BtcpayConnectionRepository>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
        applyWalletBehaviorDefaults:
            locator<ApplyWalletBehaviorDefaultsUsecase>(),
        keychainManifest: locator<KeychainManifestFacade>(),
      ),
    );
    locator.registerFactory<BtcpayPairingCubit>(
      () => BtcpayPairingCubit(
        completePairing: locator<CompleteBtcpaySamRockPairingUsecase>(),
        getConnection: locator<GetBtcpayConnectionUsecase>(),
        getWalletBehaviors: locator<GetBtcpayWalletBehaviorsUsecase>(),
        previewPairing: locator<PreviewBtcpaySamRockPairingUsecase>(),
        updateWalletBehavior: locator<UpdateWalletBehaviorUsecase>(),
      ),
    );
  }
}
