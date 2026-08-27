import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/btcpay/data/btcpay_connection_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/data/datasources/btcpay_connection_datasource.dart';
import 'package:bb_mobile/features/btcpay/data/samrock_pairing_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

class BtcpayLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<BtcpayFacade>(
      () => BtcpayFacade(connection: _getConnection(locator).execute),
    );
    locator.registerFactory<BtcpayPairingCubit>(() {
      final parser = const SamRockPairingRequestParser();
      final connectionRepository = _connectionRepository(locator);
      return BtcpayPairingCubit(
        completePairing: CompleteBtcpaySamRockPairingUsecase(
          locator<GetSettingsUsecase>(),
          parser,
          locator<PrepareDeterministicWalletsUsecase>(),
          SamRockPairingRepositoryImpl(),
          connectionRepository,
          locator<ApplyWalletBehaviorDefaultsUsecase>(),
          locator<KeychainManifestFacade>(),
        ).execute,
        getConnection: GetBtcpayConnectionUsecase(
          getSettings: locator<GetSettingsUsecase>(),
          connectionRepository: connectionRepository,
        ).execute,
        getWalletBehaviors: GetBtcpayWalletBehaviorsUsecase(
          locator<GetWalletPreferencesUsecase>(),
        ).execute,
        previewPairing: PreviewBtcpaySamRockPairingUsecase(
          parser: parser,
        ).execute,
        updateWalletBehavior:
            ({required walletId, hideOnHome, autoSweepEnabled}) async {
              final result = await locator<UpdateWalletBehaviorUsecase>()
                  .execute(
                    walletId: walletId,
                    hideOnHome: hideOnHome,
                    autoSweepEnabled: autoSweepEnabled,
                  );
              return switch (result) {
                Ok() => true,
                Err() => false,
              };
            },
      );
    });
  }

  static GetBtcpayConnectionUsecase _getConnection(GetIt locator) =>
      GetBtcpayConnectionUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        connectionRepository: _connectionRepository(locator),
      );

  static BtcpayConnectionRepository _connectionRepository(GetIt locator) =>
      BtcpayConnectionRepositoryImpl(
        BtcpayConnectionDatasource(
          storage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
        ),
      );
}
