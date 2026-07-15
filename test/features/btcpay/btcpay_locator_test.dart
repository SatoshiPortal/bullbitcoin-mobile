import 'dart:io';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/btcpay/btcpay_locator.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_service_port.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockKeyValueStorageDatasource extends Mock
    implements KeyValueStorageDatasource<String> {}

class _MockDeterministicWalletsFacade extends Mock
    implements DeterministicWalletsFacade {}

class _MockApplyWalletBehaviorDefaultsUsecase extends Mock
    implements ApplyWalletBehaviorDefaultsUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockUpdateWalletBehaviorUsecase extends Mock
    implements UpdateWalletBehaviorUsecase {}

class _MockKeychainManifestFacade extends Mock
    implements KeychainManifestFacade {}

void main() {
  late GetIt locator;

  setUp(() {
    locator = GetIt.asNewInstance();
    locator.registerSingleton<GetSettingsUsecase>(_MockGetSettingsUsecase());
    locator.registerSingleton<KeyValueStorageDatasource<String>>(
      _MockKeyValueStorageDatasource(),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    locator.registerSingleton<DeterministicWalletsFacade>(
      _MockDeterministicWalletsFacade(),
    );
    locator.registerSingleton<Bip85RegistryFacade>(const Bip85RegistryFacade());
    locator.registerSingleton<ApplyWalletBehaviorDefaultsUsecase>(
      _MockApplyWalletBehaviorDefaultsUsecase(),
    );
    locator.registerSingleton<GetWalletsUsecase>(_MockGetWalletsUsecase());
    locator.registerSingleton<UpdateWalletBehaviorUsecase>(
      _MockUpdateWalletBehaviorUsecase(),
    );
    locator.registerSingleton<KeychainManifestFacade>(
      _MockKeychainManifestFacade(),
    );
  });

  tearDown(() => locator.reset());

  test('resolves the complete mobile pairing graph', () {
    BtcpayLocator.setup(locator);

    expect(locator<BtcpayConnectionRepository>(), isNotNull);
    expect(locator<SamRockPairingServicePort>(), isNotNull);
    expect(locator<SamRockPairingRequestParser>(), isNotNull);
    expect(locator<GetBtcpayConnectionUsecase>(), isNotNull);
    expect(locator<PreviewBtcpaySamRockPairingUsecase>(), isNotNull);
    expect(locator<CompleteBtcpaySamRockPairingUsecase>(), isNotNull);
    expect(locator<BtcpayPairingCubit>(), isNotNull);
  });

  test('rejects accidental duplicate feature registration', () {
    BtcpayLocator.setup(locator);

    expect(() => BtcpayLocator.setup(locator), throwsA(isA<ArgumentError>()));
  });

  test('composition root registers BTCPay after every prerequisite', () {
    final source = File('lib/locator.dart').readAsStringSync();
    final registry = source.indexOf('Bip85RegistryLocator.setup(locator)');
    final deterministic = source.indexOf(
      'DeterministicWalletsLocator.setup(locator)',
    );
    final wallets = source.indexOf('WalletLocator.setup(locator)');
    final keychain = source.indexOf('KeychainManifestLocator.setup(locator)');
    final btcpay = source.indexOf('BtcpayLocator.setup(locator)');

    expect(registry, greaterThanOrEqualTo(0));
    expect(wallets, greaterThanOrEqualTo(0));
    expect(keychain, greaterThan(deterministic));
    expect(deterministic, greaterThan(registry));
    expect(btcpay, greaterThan(keychain));
    expect(btcpay, greaterThan(deterministic));
    expect(btcpay, greaterThan(wallets));
  });
}
