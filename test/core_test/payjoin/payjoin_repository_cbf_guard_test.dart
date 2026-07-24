import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/unconfirmed_bitcoin_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalPayjoinDatasource extends Mock
    implements LocalPayjoinDatasource {}

class _MockPdkPayjoinDatasource extends Mock implements PdkPayjoinDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockBdkBitcoinBlockchainDatasource extends Mock
    implements BdkBitcoinBlockchainDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _MockUnconfirmedBitcoinTransactionRepository extends Mock
    implements UnconfirmedBitcoinTransactionRepository {}

WalletMetadataModel _metadata(BitcoinSyncBackend backend) =>
    WalletMetadataModel(
      id: 'wallet-1',
      masterFingerprint: 'fingerprint',
      xpubFingerprint: 'xpubFingerprint',
      isEncryptedVaultTested: true,
      isPhysicalBackupTested: true,
      xpub: 'xpub',
      externalPublicDescriptor: 'external-descriptor',
      internalPublicDescriptor: 'internal-descriptor',
      signer: Signer.local,
      isDefault: true,
      bitcoinSyncBackend: backend,
    );

void main() {
  late _MockLocalPayjoinDatasource localPayjoinDatasource;
  late _MockPdkPayjoinDatasource pdkPayjoinDatasource;
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockSeedDatasource seedDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockBdkBitcoinBlockchainDatasource blockchainDatasource;
  late _MockElectrumServersPort serversPort;
  late _MockUnconfirmedBitcoinTransactionRepository unconfirmedBitcoinTx;
  late PayjoinRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(ElectrumServerNetwork.bitcoinMainnet);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const ElectrumConnection(
        url: 'fallback',
        retry: 1,
        timeout: 1,
        stopGap: 1,
        validateDomain: false,
        isCustom: false,
      ),
    );
    registerFallbackValue(
      PayjoinModel.receiver(
        id: 'fallback',
        address: 'bcrt1qaddress',
        isTestnet: true,
        receiver: 'receiver',
        walletId: 'wallet-1',
        pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
        maxFeeRateSatPerVb: BigInt.zero,
        createdAt: 0,
        expireAfterSec: 3600,
      ),
    );
  });

  setUp(() {
    localPayjoinDatasource = _MockLocalPayjoinDatasource();
    pdkPayjoinDatasource = _MockPdkPayjoinDatasource();
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    seedDatasource = _MockSeedDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    blockchainDatasource = _MockBdkBitcoinBlockchainDatasource();
    serversPort = _MockElectrumServersPort();
    unconfirmedBitcoinTx = _MockUnconfirmedBitcoinTransactionRepository();

    // Constructor wiring: subscribes to these streams and resumes any
    // ongoing payjoins — none of that is under test here.
    when(
      () => pdkPayjoinDatasource.requestsForReceivers,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => pdkPayjoinDatasource.proposalsForSenders,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => pdkPayjoinDatasource.expiredPayjoins,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => localPayjoinDatasource.fetchAll(onlyUnfinished: true),
    ).thenAnswer((_) async => <PayjoinModel>[]);

    repository = PayjoinRepositoryImpl(
      localPayjoinDatasource: localPayjoinDatasource,
      pdkPayjoinDatasource: pdkPayjoinDatasource,
      walletMetadataDatasource: walletMetadataDatasource,
      seedDatasource: seedDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
      blockchainDatasource: blockchainDatasource,
      serversPort: serversPort,
      unconfirmedBitcoinTransactionRepository: unconfirmedBitcoinTx,
    );
  });

  group('createPayjoinReceiver — CBF guard', () {
    test(
      'rejects with PayjoinDisabledForCbfException when the wallet is synced '
      'via Compact Block Filters, without ever calling the PDK datasource',
      () async {
        when(() => walletMetadataDatasource.fetch('wallet-1')).thenAnswer(
          (_) async => _metadata(BitcoinSyncBackend.compactBlockFilters),
        );

        await expectLater(
          repository.createPayjoinReceiver(
            walletId: 'wallet-1',
            address: 'bcrt1qaddress',
            isTestnet: true,
            maxFeeRateSatPerVb: BigInt.from(10000),
            expireAfterSec: 3600,
          ),
          throwsA(isA<PayjoinDisabledForCbfException>()),
        );

        verifyNever(
          () => pdkPayjoinDatasource.createReceiver(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            isTestnet: any(named: 'isTestnet'),
            maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
            expireAfterSec: any(named: 'expireAfterSec'),
          ),
        );
      },
    );

    test('proceeds normally when the wallet is synced via Electrum', () async {
      when(
        () => walletMetadataDatasource.fetch('wallet-1'),
      ).thenAnswer((_) async => _metadata(BitcoinSyncBackend.electrum));
      final model =
          PayjoinModel.receiver(
                id: 'pj-1',
                address: 'bcrt1qaddress',
                isTestnet: true,
                receiver: 'receiver',
                walletId: 'wallet-1',
                pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
                maxFeeRateSatPerVb: BigInt.from(10000),
                createdAt: 0,
                expireAfterSec: 3600,
              )
              as PayjoinReceiverModel;
      when(
        () => pdkPayjoinDatasource.createReceiver(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          isTestnet: any(named: 'isTestnet'),
          maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
        ),
      ).thenAnswer((_) async => model);
      when(
        () => localPayjoinDatasource.storeReceiver(model),
      ).thenAnswer((_) async {});

      final result = await repository.createPayjoinReceiver(
        walletId: 'wallet-1',
        address: 'bcrt1qaddress',
        isTestnet: true,
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: 3600,
      );

      expect(result.id, 'pj-1');
      verify(() => localPayjoinDatasource.storeReceiver(model)).called(1);
    });
  });

  group('createPayjoinSender — CBF guard', () {
    test(
      'rejects with PayjoinDisabledForCbfException when the wallet is synced '
      'via Compact Block Filters, without ever calling the PDK datasource',
      () async {
        when(() => walletMetadataDatasource.fetch('wallet-1')).thenAnswer(
          (_) async => _metadata(BitcoinSyncBackend.compactBlockFilters),
        );

        await expectLater(
          repository.createPayjoinSender(
            walletId: 'wallet-1',
            isTestnet: true,
            bip21: 'bitcoin:bcrt1qaddress?pj=https://example.com',
            originalPsbt: 'psbt-base64',
            amountSat: 1000,
            networkFeesSatPerVb: 1,
          ),
          throwsA(isA<PayjoinDisabledForCbfException>()),
        );

        verifyNever(
          () => pdkPayjoinDatasource.createSender(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            originalPsbt: any(named: 'originalPsbt'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
            amountSat: any(named: 'amountSat'),
            expireAfterSec: any(named: 'expireAfterSec'),
          ),
        );
      },
    );
  });

  group('tryBroadcastOriginalTransaction — ongoing Payjoins keep working', () {
    test(
      'a receiver-side fallback broadcast is never blocked by the CBF guard, '
      'even when the wallet has since switched to Compact Block Filters',
      () async {
        // The CBF guard only ever runs inside createPayjoinReceiver /
        // createPayjoinSender — tryBroadcastOriginalTransaction must never
        // consult wallet metadata at all, so an already-running Payjoin
        // (created back when the wallet was on Electrum) keeps working even
        // after the user switches the wallet to CBF.
        final payjoin = Payjoin.receiver(
          id: 'pj-1',
          isTestnet: true,
          walletId: 'wallet-1',
          pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          originalTxBytes: Uint8List.fromList([1, 2, 3]),
        );

        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
            isTransient: any(named: 'isTransient'),
          ),
        ).thenAnswer((invocation) async {
          final operation =
              invocation.namedArguments[#operation]
                  as Future<void> Function(ElectrumConnection);
          await operation(
            const ElectrumConnection(
              url: 'server-a',
              retry: 1,
              timeout: 1,
              stopGap: 1,
              validateDomain: false,
              isCustom: false,
            ),
          );
        });
        when(
          () => blockchainDatasource.broadcastTransaction(
            any(),
            connection: any(named: 'connection'),
          ),
        ).thenAnswer((_) async => 'txid-1');
        final storedModel =
            PayjoinModel.receiver(
                  id: 'pj-1',
                  address: 'bcrt1qaddress',
                  isTestnet: true,
                  receiver: 'receiver',
                  walletId: 'wallet-1',
                  pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
                  maxFeeRateSatPerVb: BigInt.from(10000),
                  createdAt: 0,
                  expireAfterSec: 3600,
                )
                as PayjoinReceiverModel;
        when(
          () => localPayjoinDatasource.fetchReceiver('pj-1'),
        ).thenAnswer((_) async => storedModel);
        when(
          () => localPayjoinDatasource.update(any()),
        ).thenAnswer((_) async {});

        final result = await repository.tryBroadcastOriginalTransaction(
          payjoin,
        );

        expect(result, isNotNull);
        // The guard is never consulted from this path.
        verifyNever(() => walletMetadataDatasource.fetch(any()));
      },
    );
  });
}
