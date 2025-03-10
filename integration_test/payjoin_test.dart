import 'dart:io';
import 'package:bb_mobile/_core/data/datasources/bip32_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/descriptor_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/electrum_server_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_stores/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_stores/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/seed_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/wallet_metadata_data_source.dart';
import 'package:bb_mobile/_core/data/repositories/electrum_server_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/payjoin_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/_core/data/services/mnemonic_seed_factory_impl.dart';
import 'package:bb_mobile/_core/data/services/payjoin_service_impl.dart';
import 'package:bb_mobile/_core/data/services/wallet_manager_service_impl.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/receive_with_payjoin_use_case.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/settings/domain/usecases/set_testnet_mode_usecase.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:test/test.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';

void main() {
  late Box<String> pdkPayjoinsBox;
  late KeyValueStorageDataSource<String> pdkStorage;
  late Box<String> electrumServersBox;
  late KeyValueStorageDataSource<String> electrumServerStorage;
  late Box<String> settingsBox;
  late KeyValueStorageDataSource<String> settingsStorage;
  late Box<String> walletMetadataBox;
  late KeyValueStorageDataSource<String> walletMetadataStorage;
  late WalletMetadataDataSource walletMetadataDataSource;
  late WalletMetadataRepository walletMetadataRepository;
  late KeyValueStorageDataSource<String> seedStorage;
  late SeedDataSource seedDataSource;
  late SeedRepository seedRepository;
  late Dio dio;
  late PdkDataSource pdkDataSource;
  late PayjoinRepository payjoinRepository;
  late ElectrumServerDataSource electrumServerDataSource;
  late ElectrumServerRepository electrumServerRepository;
  late SettingsRepository settingsRepository;
  late WalletManagerService walletManagerService;
  late PayjoinService payjoinService;
  late SetEnvironmentUseCase setEnvironmentUseCase;
  late RecoverWalletUseCase recoverWalletUseCase;
  late ReceiveWithPayjoinUseCase receiveWithPayjoinUseCase;
  late Wallet receiverWallet;
  late Wallet senderWallet;

  const receiverMnemonic =
      'model float claim feature convince exchange truck cream assume fancy swamp offer';
  const senderMnemonic =
      'duty tattoo frown crazy pelican aisle area wrist robot stove taxi material';

  setUpAll(() async {
    await Future.wait([
      Hive.initFlutter(),
      core.init(),
    ]);

    pdkPayjoinsBox =
        await Hive.openBox<String>(HiveBoxNameConstants.pdkPayjoins);
    pdkStorage = HiveStorageDataSourceImpl<String>(pdkPayjoinsBox);
    electrumServersBox =
        await Hive.openBox<String>(HiveBoxNameConstants.electrumServers);
    electrumServerStorage =
        HiveStorageDataSourceImpl<String>(electrumServersBox);
    dio = Dio();
    pdkDataSource = PdkDataSourceImpl(storage: pdkStorage, dio: dio);
    payjoinRepository = PayjoinRepositoryImpl(pdk: pdkDataSource);

    electrumServerDataSource = ElectrumServerDataSourceImpl(
      electrumServerStorage: electrumServerStorage,
    );
    electrumServerRepository = ElectrumServerRepositoryImpl(
      electrumServerDataSource: electrumServerDataSource,
    );
    settingsBox = await Hive.openBox<String>(HiveBoxNameConstants.settings);
    settingsStorage = HiveStorageDataSourceImpl<String>(settingsBox);
    settingsRepository = SettingsRepositoryImpl(
      storage: settingsStorage,
    );
    walletMetadataBox =
        await Hive.openBox<String>(HiveBoxNameConstants.walletMetadata);
    walletMetadataStorage =
        HiveStorageDataSourceImpl<String>(walletMetadataBox);
    walletMetadataDataSource = WalletMetadataDataSourceImpl(
      bip32: const Bip32DataSourceImpl(),
      descriptor: const DescriptorDataSourceImpl(),
      walletMetadataStorage: walletMetadataStorage,
    );
    walletMetadataRepository = WalletMetadataRepositoryImpl(
      source: walletMetadataDataSource,
    );
    seedStorage = SecureStorageDataSourceImpl(
      const FlutterSecureStorage(),
    );
    seedDataSource = SeedDataSourceImpl(
      secureStorage: seedStorage,
    );
    seedRepository = SeedRepositoryImpl(
      source: seedDataSource,
    );
    walletManagerService = WalletManagerServiceImpl(
      walletMetadataRepository: walletMetadataRepository,
      seedRepository: seedRepository,
      electrumServerRepository: electrumServerRepository,
    );
    payjoinService = PayjoinServiceImpl(
      payjoinRepository: payjoinRepository,
      electrumServerRepository: electrumServerRepository,
      settingsRepository: settingsRepository,
      walletManagerService: walletManagerService,
    );

    setEnvironmentUseCase = SetEnvironmentUseCase(
      settingsRepository: settingsRepository,
    );
    // Make sure we are running in testnet environment
    await setEnvironmentUseCase.execute(Environment.testnet);

    recoverWalletUseCase = RecoverWalletUseCase(
      settingsRepository: settingsRepository,
      mnemonicSeedFactory: const MnemonicSeedFactoryImpl(),
      walletManager: walletManagerService,
    );
    receiveWithPayjoinUseCase = ReceiveWithPayjoinUseCase(
      payjoinService: payjoinService,
    );

    receiverWallet = await recoverWalletUseCase.execute(
      mnemonicWords: receiverMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );
    senderWallet = await recoverWalletUseCase.execute(
      mnemonicWords: senderMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );

    debugPrint('Setup completed');
  });

  group('WalletRepositoryManager Integration Tests', () {
    group('Payjoin receiver', () {
      test('creation', () async {
        final address = await walletManagerService.getNewAddress(
          walletId: receiverWallet.id,
        );
        debugPrint('Receive address generated: ${address.address}');
        final payjoin = await receiveWithPayjoinUseCase.execute(
          walletId: receiverWallet.id,
          address: address.address,
          isTestnet: true,
        );

        debugPrint('Payjoin receiver created: $payjoin');

        final pjUri = Uri.parse(payjoin.pjUri);

        expect(pjUri.scheme, 'bitcoin');
        expect(pjUri.path, address.address);
        expect(pjUri.queryParameters.containsKey('pj'), true);
        expect(pjUri.queryParameters['pjos'], '0');
      });

      test('request', () {});
    });
  });
}
