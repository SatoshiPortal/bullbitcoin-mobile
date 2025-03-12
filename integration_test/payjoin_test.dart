import 'dart:async';

import 'package:bb_mobile/_core/data/datasources/bip32_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/descriptor_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/electrum_server_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/payjoin/impl/pdk_payjoin_data_source_impl.dart';
import 'package:bb_mobile/_core/data/datasources/payjoin/payjoin_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/seed_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/wallet_metadata_data_source.dart';
import 'package:bb_mobile/_core/data/repositories/electrum_server_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/payjoin_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/_core/data/services/mnemonic_seed_factory_impl.dart';
import 'package:bb_mobile/_core/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/_core/data/services/wallet_manager_service_impl.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/receive_with_payjoin_use_case.dart';
import 'package:bb_mobile/_core/domain/usecases/send_with_payjoin_use_case.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/settings/domain/usecases/set_testnet_mode_usecase.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  late PayjoinDataSource pdkDataSource;
  late PayjoinRepository payjoinRepository;
  late ElectrumServerDataSource electrumServerDataSource;
  late ElectrumServerRepository electrumServerRepository;
  late SettingsRepository settingsRepository;
  late WalletManagerService walletManagerService;
  late PayjoinWatcherService payjoinWatcherService;
  late SetEnvironmentUseCase setEnvironmentUseCase;
  late RecoverWalletUseCase recoverWalletUseCase;
  late ReceiveWithPayjoinUseCase receiveWithPayjoinUseCase;
  late SendWithPayjoinUseCase sendWithPayjoinUseCase;
  late Wallet receiverWallet;
  late Wallet senderWallet;

  // TODO: move these to github secrets so the testnet coins for our integration
  //  tests are not at risk of being used by others.
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
    pdkDataSource = PdkPayjoinDataSourceImpl(storage: pdkStorage, dio: dio);
    payjoinRepository = PayjoinRepositoryImpl(payjoinDataSource: pdkDataSource);

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
    payjoinWatcherService = PayjoinWatcherServiceImpl(
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
      payjoinRepository: payjoinRepository,
    );
    sendWithPayjoinUseCase = SendWithPayjoinUseCase(
      payjoinRepository: payjoinRepository,
    );

    receiverWallet = await recoverWalletUseCase.execute(
      mnemonicWords: receiverMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );
    senderWallet = await recoverWalletUseCase.execute(
      mnemonicWords: senderMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );

    // Sync the wallets before starting the tests
    await walletManagerService.syncAll();

    debugPrint('Setup completed');
  });

  test('Wallets have funds to payjoin', () async {
    final senderBalance = await walletManagerService.getBalance(
      walletId: senderWallet.id,
    );
    final receiverBalance = await walletManagerService.getBalance(
      walletId: receiverWallet.id,
    );
    debugPrint('Sender balance: $senderBalance');
    debugPrint('Receiver balance: $receiverBalance');

    if (senderBalance.totalSat == BigInt.zero) {
      final address = await walletManagerService.getNewAddress(
        walletId: senderWallet.id,
      );
      debugPrint(
          'Send some funds to ${address.address} before running the integration test again');
    }
    if (receiverBalance.totalSat == BigInt.zero) {
      final address = await walletManagerService.getNewAddress(
        walletId: receiverWallet.id,
      );
      debugPrint(
          'Send some funds to ${address.address} before running the integration test again');
    }

    expect(senderBalance.totalSat.toInt(), greaterThan(0));
    expect(receiverBalance.totalSat.toInt(), greaterThan(0));
  });

  group('Payjoin Integration Tests', () {
    group('with one receive and one send', () {
      late StreamSubscription<Payjoin> payjoinSubscription;
      late Completer<bool> payjoinReceiverCompletedEvent;
      late Completer<bool> payjoinSenderCompletedEvent;

      setUp(() async {
        payjoinReceiverCompletedEvent = Completer();
        payjoinSenderCompletedEvent = Completer();

        payjoinSubscription = payjoinWatcherService.payjoins.listen((payjoin) {
          debugPrint('Payjoin event: $payjoin');
          switch (payjoin) {
            case PayjoinReceiver _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinReceiverCompletedEvent.complete(true);
              }
            case PayjoinSender _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinSenderCompletedEvent.complete(true);
              }
          }
        });
      });

      test('should work', () async {
        // Generate receiver address
        final address = await walletManagerService.getNewAddress(
          walletId: receiverWallet.id,
        );
        debugPrint('Receive address generated: ${address.address}');

        // Start a receiver session
        final payjoin = await receiveWithPayjoinUseCase.execute(
          walletId: receiverWallet.id,
          address: address.address,
          isTestnet: true,
        );
        debugPrint('Payjoin receiver created: $payjoin');

        expect(payjoin.status, PayjoinStatus.started);
        // Check that the payjoin uri is correct
        final pjUri = Uri.parse(payjoin.pjUri);
        expect(pjUri.scheme, 'bitcoin');
        expect(pjUri.path, address.address);
        expect(pjUri.queryParameters.containsKey('pj'), true);
        expect(pjUri.queryParameters['pjos'], '0');

        // Build the psbt with the sender wallet
        const networkFeesSatPerVb = 1000.0;
        final originalPsbt = await walletManagerService.buildPsbt(
          walletId: senderWallet.id,
          address: address.address,
          amountSat: BigInt.from(1000),
          feeRateSatPerVb: networkFeesSatPerVb,
        );

        final payjoinSender = await sendWithPayjoinUseCase.execute(
          walletId: senderWallet.id,
          bip21: pjUri.toString(),
          originalPsbt: originalPsbt,
          networkFeesSatPerVb: networkFeesSatPerVb,
        );
        debugPrint('Payjoin sender created: $payjoinSender');
        expect(payjoinSender.status, PayjoinStatus.requested);

        // Once the request is sent by the sender, it is automatically fetched
        //  by the receiver the next time it polls the payjoin directory.
        //  The receiver will process the request automatically and sends a
        //  payjoin proposal back to the payjoin directory which should complete
        //  the payjoin session for the receiver's side.
        final didReceiverComplete = await Future.any(
          [
            payjoinReceiverCompletedEvent.future,
            // TODO: make a constant for the payjoin polling interval and take a multiple of it for the timeout here
            Future.delayed(const Duration(seconds: 15), () => false),
          ],
        );
        expect(didReceiverComplete, true);

        // Once the proposal is sent by the receiver, it is automatically fetched
        //  by the sender the next time it polls the payjoin directory.
        // The sender will process the proposal automatically and broadcast the
        //  final transaction to the network which should complete the payjoin
        //  session for the sender's side.
        final didSenderComplete = await Future.any(
          [
            payjoinSenderCompletedEvent.future,
            // TODO: make a constant for the payjoin polling interval and take a multiple of it for the timeout here
            Future.delayed(const Duration(seconds: 15), () => false),
          ],
        );
        expect(didSenderComplete, true);
      });

      test('should successfully resume after a restart', () {});

      test('should fail if the receiver does not have enough funds', () {});

      test('should fail if the sender does not have enough funds', () {});

      test(
        'should broadcast the original transaction if the payjoin is expired',
        () {},
      );

      test(
        'should broadcast the original transaction if the payjoin fails',
        () {},
      );
      tearDown(() {
        payjoinSubscription.cancel();
      });
    });

    group('with multiple ongoing payjoins', () {});
  });
}
