import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockLwkDatasource extends Mock implements LwkWalletDatasource {}

class _MockFrozenDatasource extends Mock
    implements FrozenWalletUtxoDatasource {}

void main() {
  const walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
  const first = (txId: 'first', vout: 0);
  const second = (txId: 'second', vout: 1);
  const fee = RelativeFee(25);
  late _MockLwkDatasource lwk;
  late _MockFrozenDatasource frozen;
  late LiquidWalletRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: walletId,
        isTestnet: true,
        combinedCtDescriptor: 'descriptor',
      ),
    );
    registerFallbackValue(fee);
  });

  setUp(() {
    final metadata = _MockMetadataDatasource();
    lwk = _MockLwkDatasource();
    frozen = _MockFrozenDatasource();
    repository = LiquidWalletRepository(
      walletMetadataDatasource: metadata,
      seedDatasource: _MockSeedDatasource(),
      lwkWalletDatasource: lwk,
      frozenWalletUtxoDatasource: frozen,
    );
    when(() => metadata.fetch(walletId)).thenAnswer(
      (_) async => const WalletMetadataModel(
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
    when(() => frozen.getAllFrozen()).thenAnswer((_) async => []);
    when(() => lwk.getUtxos(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => [
        for (final coin in [first, second])
          WalletUtxoModel.liquid(
            txId: coin.txId,
            vout: coin.vout,
            amountSat: BigInt.from(50000),
            scriptPubkey: '',
            standardAddress: 'tex1address',
            confidentialAddress: 'tlq1address',
          ),
      ],
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
    ).thenAnswer((_) async => 'pset');
  });

  Future<String> build({Set<Outpoint>? selected}) => repository.buildPset(
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
    await build(selected: {second});
    expect(builtInputs(), {second});
  });

  test('preserves automatic selection when no coins are frozen', () async {
    await build();
    expect(builtInputs(), isNull);
  });

  test('excludes frozen coins from automatic sends', () async {
    when(() => frozen.getAllFrozen()).thenAnswer(
      (_) async => [(walletId: walletId, txId: first.txId, vout: first.vout)],
    );
    await build();
    expect(builtInputs(), {second});
  });

  for (final selection in <Set<Outpoint>>[
    {},
    {first, (txId: 'missing', vout: 0)},
  ]) {
    test('rejects an unavailable selection $selection', () async {
      await expectLater(
        build(selected: selection),
        throwsA(isA<SelectedInputsUnavailableException>()),
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
  }

  test('rejects a selected coin frozen after it was selected', () async {
    when(() => frozen.getAllFrozen()).thenAnswer(
      (_) async => [(walletId: walletId, txId: first.txId, vout: first.vout)],
    );
    await expectLater(
      build(selected: {first, second}),
      throwsA(isA<SelectedInputsUnavailableException>()),
    );
  });

  test('does not sign a PSET that spends a newly frozen coin', () async {
    when(() => frozen.getAllFrozen()).thenAnswer(
      (_) async => [(walletId: walletId, txId: first.txId, vout: first.vout)],
    );
    when(() => lwk.getPsetInputs('pset')).thenReturn({first});
    await expectLater(
      repository.signPset(pset: 'pset', walletId: walletId),
      throwsA(isA<NoSpendableUtxoException>()),
    );
  });

  test('rejects automatic sends when all coins are frozen', () async {
    when(() => frozen.getAllFrozen()).thenAnswer(
      (_) async => [
        for (final coin in [first, second])
          (walletId: walletId, txId: coin.txId, vout: coin.vout),
      ],
    );
    await expectLater(build(), throwsA(isA<NoSpendableUtxoException>()));
  });
}
