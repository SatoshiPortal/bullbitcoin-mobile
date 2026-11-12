import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBlockchain extends Mock implements BitcoinBlockchainRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Synthetic transaction spending 201f…0201:0 (prevout bytes 01…20, so the
  // display txid is the byte-reversed hex). No key material.
  const spentTxId =
      '201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201';
  const rawTx =
      '02000000010102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'
      '200000000000fdffffff01a0860100000000001600142222222222222222222222222222'
      '22222222222200000000';
  const psbt =
      'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  setUpAll(() => registerFallbackValue(<int>[]));

  late SqliteDatabase db;
  late FrozenWalletUtxoDatasource frozenStore;
  late _MockBlockchain blockchain;
  late _MockSettings settings;

  BroadcastBitcoinTransactionUsecase usecase({
    WalletUtxoRepository? walletUtxoRepository,
  }) => BroadcastBitcoinTransactionUsecase(
    bitcoinBlockchainRepository: blockchain,
    settingsRepository: settings,
    walletUtxoRepository:
        walletUtxoRepository ??
        WalletUtxoRepositoryImpl(
          walletMetadataDatasource: _MockWalletMetadataDatasource(),
          labelsFacade: _MockLabelsFacade(),
          bdkWalletDatasource: _MockBdkWalletDatasource(),
          lwkWalletDatasource: _MockLwkWalletDatasource(),
          frozenWalletUtxoDatasource: frozenStore,
        ),
  );

  Future<void> freeze(String txId, int vout) => frozenStore.freezeOutpoints(
    walletId: 'wallet',
    outpoints: [(txId: txId, vout: vout)],
  );

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    frozenStore = FrozenWalletUtxoDatasource(db: db);
    blockchain = _MockBlockchain();
    settings = _MockSettings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => blockchain.broadcastPsbt(any(), isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => 'txid');
    when(
      () => blockchain.broadcastTransaction(
        any(),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => 'txid');
  });

  tearDown(() => db.close());

  void verifyNothingBroadcast() {
    verifyNever(
      () => blockchain.broadcastPsbt(any(), isTestnet: any(named: 'isTestnet')),
    );
    verifyNever(
      () => blockchain.broadcastTransaction(
        any(),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  }

  group('BroadcastBitcoinTransactionUsecase frozen inputs', () {
    test('refuses a PSBT that spends a frozen coin', () async {
      await freeze(spentTxId, 0);

      await expectLater(
        usecase().execute(psbt, isPsbt: true),
        throwsA(isA<BroadcastTransactionException>()),
      );
      verifyNothingBroadcast();
    });

    test('refuses a raw transaction that spends a frozen coin', () async {
      await freeze(spentTxId, 0);

      await expectLater(
        usecase().execute(rawTx, isPsbt: false),
        throwsA(isA<BroadcastTransactionException>()),
      );
      verifyNothingBroadcast();
    });

    test(
      'broadcasts when only another output of the same tx is frozen',
      () async {
        await freeze(spentTxId, 1);

        expect(await usecase().execute(psbt, isPsbt: true), 'txid');
        expect(await usecase().execute(rawTx, isPsbt: false), 'txid');
      },
    );

    test('broadcasts when nothing is frozen', () async {
      expect(await usecase().execute(psbt, isPsbt: true), 'txid');
      verify(() => blockchain.broadcastPsbt(psbt, isTestnet: true)).called(1);
    });

    test('refuses when the frozen store cannot be read', () async {
      final failing = _MockWalletUtxoRepository();
      when(
        failing.getAllFrozenOutpoints,
      ).thenThrow(StateError('store unavailable'));

      await expectLater(
        usecase(walletUtxoRepository: failing).execute(psbt, isPsbt: true),
        throwsA(isA<BroadcastTransactionException>()),
      );
      verifyNothingBroadcast();
    });

    test('refuses a transaction it cannot parse', () async {
      await expectLater(
        usecase().execute('not-a-transaction', isPsbt: false),
        throwsA(isA<BroadcastTransactionException>()),
      );
      verifyNothingBroadcast();
    });

    test('the airgap flow does not broadcast a signed frozen spend', () async {
      await freeze(spentTxId, 0);
      final cubit = BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase: usecase(),
        verifySignedTxUsecase: VerifyBroadcastSignedTxUsecase(
          SendFacade(VerifySignedTxUsecase()),
        ),
        unsignedPsbt: psbt,
      );
      addTearDown(cubit.close);

      await cubit.tryParseTransaction(psbt);
      expect(cubit.state.transaction, isNotNull);
      await cubit.broadcastTransaction();

      verifyNothingBroadcast();
      expect(cubit.state.isBroadcasted, isFalse);
    });
  });
}
