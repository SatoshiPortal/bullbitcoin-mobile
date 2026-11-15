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
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockLwkDatasource extends Mock implements LwkWalletDatasource {}

class _MockValues extends Mock implements SyncWalletValuesDatasource {}

class _MockFrozenDatasource extends Mock implements SyncFreezesDatasource {}

void main() {
  const walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
  const first = (txId: 'first', vout: 0);
  const second = (txId: 'second', vout: 1);
  const fee = RelativeFee(25);
  late _MockLwkDatasource lwk;
  late _MockValues values;
  late _MockFrozenDatasource frozen;
  late LiquidWalletRepository repository;
  late Result<UnsignedSpend, SyncFailure> built;
  late FakeSecureStoragePlatform store;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: walletId,
        network: Network.liquidTestnet,
        combinedCtDescriptor: 'descriptor',
      ),
    );
    registerFallbackValue(fee);
  });

  setUp(() {
    final metadata = _MockMetadataDatasource();
    lwk = _MockLwkDatasource();
    values = _MockValues();
    frozen = _MockFrozenDatasource();
    store = FakeSecureStoragePlatform()..install();
    final scratch = Directory.systemTemp.createTempSync('ben-liquid-test-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    repository = LiquidWalletRepository(
      walletMetadataDatasource: metadata,
      secrets: Secrets(scratchDirectory: () async => scratch.path),
      lwkWalletDatasource: lwk,
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
    when(
      () => lwk.buildPset(
        wallet: any(named: 'wallet'),
        address: any(named: 'address'),
        feeRate: any(named: 'feeRate'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    ).thenAnswer((_) async => built);
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
      verify(
            () => lwk.buildPset(
              wallet: any(named: 'wallet'),
              address: 'recipient',
              feeRate: fee,
              amountSat: 10000,
              drain: false,
              selectedInputs: captureAny(named: 'selectedInputs'),
            ),
          ).captured.single
          as Set<Outpoint>?;

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
    verifyNever(
      () => lwk.buildPset(
        wallet: any(named: 'wallet'),
        address: any(named: 'address'),
        feeRate: any(named: 'feeRate'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
        selectedInputs: any(named: 'selectedInputs'),
      ),
    );
  });

  test('does not sign a PSET that spends a newly frozen coin', () async {
    when(() => frozen.getFrozenOutpoints())
        .thenAnswer((_) async => {(txId: first.txId, vout: first.vout)});
    when(() => lwk.getPsetInputs('pset')).thenReturn({first});
    await expectLater(
      repository.signPset(pset: 'pset', walletId: walletId),
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
