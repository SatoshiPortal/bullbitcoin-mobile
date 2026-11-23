import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

import 'dart:io';

import 'package:sync/sync.dart'
    show
        SyncConsolidationRequiredFailure,
        SyncFailure,
        SyncInsufficientFundsFailure,
        SyncNoSpendableInputsFailure,
        SyncProtectedInputsFailure,
        SyncStorageFailure,
        UnsignedSpend,
        WalletKey,
        WalletRevision;
import 'package:fees/fees.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart' show BullSdk, BullSdkApi;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';

import 'support/wallet_model.dart';

import 'package:bb_mobile/features/send/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/no_spendable_utxo_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _Spender extends Mock implements WalletSpender {}

class _Sdk extends Mock implements BullSdkApi {}

class _Pset extends Mock implements lwk.PartiallySignedElementsTransaction {}

class _Transaction extends Mock implements lwk.LiquidTransaction {}

class _MockValues extends Mock implements SyncWalletValuesDatasource {}

class _MockFrozenDatasource extends Mock implements SyncFreezesDatasource {}

void main() {
  const walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
  const first = (txId: 'first', vout: 0);
  const second = (txId: 'second', vout: 1);
  const fee = RelativeFee(25);
  late _Spender spender;
  late sync.Wallet wallet;
  late int walletOpens;
  final sdk = _Sdk();
  late _MockValues values;
  late _MockFrozenDatasource frozen;
  late LiquidWalletRepository repository;
  late Result<UnsignedSpend, SyncFailure> built;
  late FakeSecureStoragePlatform store;

  setUpAll(() {
    BullSdk.initMock(api: sdk);
    registerFallbackValue(
      WalletKey(id: walletId, network: LiquidNetwork.testnet),
    );
    registerFallbackValue(
      sync.LiquidSpendRequest(
        address: 'recipient',
        amountSat: 1,
        fee: sync.SpendFeeRate(25),
      ),
    );
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: walletId,
        network: Network.liquidTestnet,
        combinedCtDescriptor: 'descriptor',
      ),
    );
    registerFallbackValue(fee);
  });

  tearDownAll(BullSdk.dispose);

  setUp(() async {
    final metadata = _MockMetadataDatasource();
    spender = _Spender();
    walletOpens = 0;
    reset(sdk);
    values = _MockValues();
    frozen = _MockFrozenDatasource();
    store = FakeSecureStoragePlatform()..install();
    final scratch = Directory.systemTemp.createTempSync('ben-liquid-test-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    wallet = await testWallet(
      key: WalletKey(id: walletId, network: LiquidNetwork.testnet),
      spender: spender,
    );
    repository = LiquidWalletRepository(
      walletMetadataDatasource: metadata,
      secrets: Secrets(scratchDirectory: () async => scratch.path),
      wallet: (_) async {
        walletOpens++;
        return Ok(wallet);
      },
      walletValuesDatasource: values,
      freezesDatasource: frozen,
      // The address check needs lwk's native library; these tests cover
      // selection, so they accept every address.
      validateAddress: (_, _) async => const Ok(null),
    );
    when(() => metadata.fetch(walletId)).thenAnswer(
      (_) async => const WalletMetadataModel(
        networkCode: 'liquidTestnet',
        id: walletId,
        masterFingerprint: '73c5da0a',
        xpubFingerprint: 'deadbeef',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: '',
        externalPublicDescriptor: 'descriptor',
        internalPublicDescriptor: '',
        signer: Signer.local,
        isDefault: false,
      ),
    );
    when(() => frozen.getFrozenOutpoints()).thenAnswer((_) async => {});
    built = Ok(
      UnsignedSpend(
        revision: WalletRevision(
          key: WalletKey(id: walletId, network: LiquidNetwork.testnet),
          generation: 1,
          revision: 1,
        ),
        encoded: 'pset',
        inputs: const [],
      ),
    );
    when(() => spender.build(any(), any(), any()))
        .thenAnswer((_) async => built);
  });

  Future<Result<String, WalletFailure>> build({Set<Outpoint>? selected}) =>
      repository.buildPset(
        walletId: walletId,
        address: 'recipient',
        amountSat: 10000,
        feeRate: fee,
        selectedInputs: selected,
      );

  Set<Outpoint>? builtInputs() =>
      (verify(() => spender.build(any(), any(), captureAny())).captured.single
              as sync.LiquidSpendRequest)
          .selected;

  for (final drain in <bool?>[null, false]) {
    test(
      'refuses a missing amount when drain is $drain before opening a wallet',
      () async {
        final result = await repository.buildPset(
          walletId: walletId,
          address: 'recipient',
          feeRate: fee,
          drain: drain,
        );
        expect(
          (result as Err<String, WalletFailure>).failure,
          isA<WalletTransactionBuildFailure>(),
        );
        expect(walletOpens, 0);
        verifyZeroInteractions(spender);
      },
    );
  }

  test('passes exactly the selected outpoints to the builder', () async {
    expect(await build(selected: {second}), isA<Ok<String, WalletFailure>>());
    expect(builtInputs(), {second});
  });

  test('leaves the selection and the freezes to sync', () async {
    await build();
    expect(builtInputs(), isNull);
    verifyZeroInteractions(frozen);
  });

  test('rejects an empty selection before sync', () async {
    expect(
      (await build(selected: {}) as Err<String, WalletFailure>).failure,
      isA<WalletSelectedInputsUnavailableFailure>(),
    );
    verifyZeroInteractions(spender);
  });

  test('does not sign a PSET that spends a newly frozen coin', () async {
    when(() => frozen.getFrozenOutpoints())
        .thenAnswer((_) async => {(txId: first.txId, vout: first.vout)});
    final pset = _Pset();
    final transaction = _Transaction();
    when(
      () => sdk.lwkApiTransactionPartiallySignedElementsTransactionFromString(
        psetString: 'cHNldP8=',
      ),
    ).thenReturn(pset);
    when(pset.extractTx).thenReturn(transaction);
    when(transaction.txid).thenReturn('ab' * 32);
    when(transaction.version).thenReturn(2);
    when(transaction.lockTime).thenReturn(0);
    when(transaction.vsize).thenReturn(BigInt.one);
    when(transaction.weight).thenReturn(BigInt.one);
    when(transaction.fee).thenReturn(BigInt.zero);
    when(transaction.getInputs).thenReturn(const [
      lwk.TxInput(
        txid: 'first',
        vout: 0,
        scriptSig: '',
        sequence: 0,
        witness: [],
        isPegin: false,
      ),
    ]);
    when(transaction.getOutputs).thenReturn([]);
    await expectLater(
      repository.signPset(pset: 'cHNldP8=', walletId: walletId),
      throwsA(isA<NoSpendableUtxoException>()),
    );
    expect(store.reads, 0);
  });

  for (final (failure, selected, matcher) in <(SyncFailure, bool, Matcher)>[
    (
      const SyncInsufficientFundsFailure(),
      false,
      isA<WalletInsufficientFundsFailure>(),
    ),
    (
      const SyncConsolidationRequiredFailure(),
      false,
      isA<WalletConsolidationRequiredFailure>(),
    ),
    (
      SyncProtectedInputsFailure(frozen: {first}),
      true,
      isA<WalletSelectedInputsUnavailableFailure>(),
    ),
    (
      const SyncNoSpendableInputsFailure(),
      false,
      isA<WalletNoSpendableInputsFailure>(),
    ),
    (const SyncStorageFailure(), false, isA<WalletTransactionBuildFailure>()),
  ]) {
    test('maps ${failure.logCode} from sync\'s builder', () async {
      built = Err(failure);
      final result = await build(selected: selected ? {first} : null);
      expect((result as Err<String, WalletFailure>).failure, matcher);
      expect(store.reads, 0);
    });
  }
}
