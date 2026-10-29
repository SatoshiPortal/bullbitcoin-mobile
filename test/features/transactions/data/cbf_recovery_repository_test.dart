import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/transactions/data/cbf_recovery_repository_impl.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/cancel_unrelayed_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/retry_unrelayed_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Wallets extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Facade extends Mock implements WalletTransactionSyncFacade {}

const _wallet = WalletMetadataModel(
  id: 'wpkh([deadbeef/84h/0h/0h])',
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'public',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public/0/*)',
  internalPublicDescriptor: 'wpkh(public/1/*)',
  signer: Signer.none,
  isDefault: false,
  bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
);
const _registration = WalletSourceRegistration(
  key: WalletNetworkKey('wpkh([deadbeef/84h/0h/0h])', 'bitcoin', 'mainnet'),
  sourceKind: 'bdk_electrum',
  configurationFingerprint: 'public',
);

void main() {
  late _Wallets wallets;
  late BitcoinSyncRouting routing;
  late _Settings settings;
  var torCalls = 0;
  late _Facade facade;
  late CbfRecoveryRepositoryImpl repository;
  setUp(() {
    registerFallbackValue(_registration);
    wallets = _Wallets();
    settings = _Settings();
    facade = _Facade();
    torCalls = 0;
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        useTorProxy: true,
      ),
    );
    routing = BitcoinSyncRouting(
      facade: facade,
      settings: settings,
      tor: () {
        torCalls++;
        throw Exception('unavailable');
      },
      documentsDirectory: () async => '/tmp/public-test',
    );
    repository = CbfRecoveryRepositoryImpl(wallets, routing);
    when(() => wallets.fetch(_wallet.id)).thenAnswer((_) async => _wallet);
  });

  test(
    'Retry verifies Tor and maps native non-acknowledgement to a feature failure',
    () async {
      when(
        () => facade.retryCbfTransaction(any(), 'spend'),
      ).thenAnswer((_) async => const Err(CbfBroadcastNotRelayedFailure()));
      final result = await RetryUnrelayedTransactionUsecase(
        repository,
      ).execute(_wallet.id, 'spend');
      expect((result as Err).failure, isA<TransactionCbfRecoveryFailure>());
      expect(torCalls, 1);
      when(
        () => facade.retryCbfTransaction(any(), 'spend'),
      ).thenAnswer((_) async => const Ok('spend'));
      expect(
        await RetryUnrelayedTransactionUsecase(
          repository,
        ).execute(_wallet.id, 'spend'),
        isA<Ok>(),
      );
    },
  );

  test(
    'Cancel is local and maps stale or relayed transactions to unavailable',
    () async {
      when(() => facade.cancelCbfTransaction(any(), 'spend')).thenAnswer(
        (_) async => const Err(CbfTransactionNotRecoverableFailure()),
      );
      final result = await CancelUnrelayedTransactionUsecase(
        repository,
      ).execute(_wallet.id, 'spend');
      expect((result as Err).failure, isA<TransactionCbfUnavailableFailure>());
      expect(torCalls, 0);
      verifyNever(() => facade.retryCbfTransaction(any(), 'spend'));
    },
  );

  test(
    'Electrum policy and missing wallets cannot reach CBF recovery',
    () async {
      when(() => wallets.fetch(_wallet.id)).thenAnswer(
        (_) async =>
            _wallet.copyWith(bitcoinSyncSource: BitcoinSyncSource.electrum),
      );
      expect(
        (await repository.cancel(_wallet.id, 'spend') as Err).failure,
        isA<TransactionCbfUnavailableFailure>(),
      );
      expect(
        (await repository.retry(_wallet.id, 'spend') as Err).failure,
        isA<TransactionCbfUnavailableFailure>(),
      );
      when(() => wallets.fetch(_wallet.id)).thenAnswer((_) async => null);
      expect(
        (await repository.cancel(_wallet.id, 'spend') as Err).failure,
        isA<TransactionCbfUnavailableFailure>(),
      );
      verifyZeroInteractions(settings);
      verifyZeroInteractions(facade);
    },
  );

  test('infrastructure diagnostics never cross the failure boundary', () async {
    when(
      () => wallets.fetch(_wallet.id),
    ).thenThrow(Exception('private diagnostic'));
    final result = await repository.retry(_wallet.id, 'spend');
    expect((result as Err).failure, isA<TransactionCbfRecoveryFailure>());
    expect((result as Err).failure.logMessage, isNull);
  });
}
