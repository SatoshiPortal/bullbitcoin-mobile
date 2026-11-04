import 'dart:typed_data';
import 'dart:async';

import 'package:wallet/wallet.dart';

import 'package:bb_mobile/features/coins/data/labeled_wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show InMemoryWalletSourceOperationCoordinator, WalletSourceKey;

class _MockWalletCatalogPort extends Mock implements WalletCatalogPort {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockWalletFreezeStorePort extends Mock
    implements WalletFreezeStorePort {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _otherWalletId = 'wpkh([deadbeef/84h/1h/0h])';

WalletMetadata _metadata(String id) => WalletMetadata(
  id: id,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: SignerEntity.local,
  isDefault: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
  });

  test('same source key waits while a different key progresses', () async {
    final metadata = _MockWalletCatalogPort();
    final bdk = _MockBdkWalletDatasource();
    final frozen = _MockWalletFreezeStorePort();
    final labels = _MockLabelsFacade();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    var utxoReads = 0;
    final release = Completer<void>();

    when(
      () => metadata.fetch(_walletId),
    ).thenAnswer((_) async => _metadata(_walletId));
    when(
      () => metadata.fetch(_otherWalletId),
    ).thenAnswer((_) async => _metadata(_otherWalletId));
    when(() => bdk.getUtxos(wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) async {
      utxoReads++;
      return [];
    });
    when(() => frozen.getAllFrozen()).thenAnswer((_) async => []);
    when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);

    final repository = LabeledWalletUtxoRepositoryImpl(
      labelsFacade: labels,
      wallet: WalletUtxoRepositoryImpl(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: _MockLwkWalletDatasource(),
        frozenWalletUtxoDatasource: frozen,
        coordinator: coordinator,
      ),
    );
    final held = coordinator.runExclusive(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => release.future,
    );

    final waiting = repository.getWalletUtxos(walletId: _walletId);
    await Future<void>.delayed(Duration.zero);
    expect(utxoReads, 0);

    await repository.getWalletUtxos(walletId: _otherWalletId);
    expect(utxoReads, 1);

    release.complete();
    await waiting;
    await held;
  });
  for (final isLiquid in [false, true]) {
    test(
      'preserves ${isLiquid ? 'Liquid' : 'Bitcoin'} coin and label projection',
      () async {
        final walletId = isLiquid ? 'elwpkh([73c5da0a/84h/1h/0h])' : _walletId;
        final metadata = _MockWalletCatalogPort();
        final bdk = _MockBdkWalletDatasource();
        final lwk = _MockLwkWalletDatasource();
        final frozen = _MockWalletFreezeStorePort();
        final labels = _MockLabelsFacade();
        when(
          () => metadata.fetch(walletId),
        ).thenAnswer((_) async => _metadata(walletId));
        final model = isLiquid
            ? WalletUtxoModel.liquid(
                txId: 'tx',
                vout: 7,
                amountSat: BigInt.from(1234),
                scriptPubkey: 'script',
                standardAddress: 'standard',
                confidentialAddress: 'confidential',
                confirmations: 3,
              )
            : WalletUtxoModel.bitcoin(
                txId: 'tx',
                vout: 7,
                amountSat: BigInt.from(1234),
                scriptPubkey: Uint8List.fromList([0, 20]),
                address: 'standard',
                isExternalKeyChain: false,
                confirmations: 3,
              );
        when(
          () => bdk.getUtxos(wallet: any(named: 'wallet')),
        ).thenAnswer((_) async => [model]);
        when(
          () => lwk.getUtxos(wallet: any(named: 'wallet')),
        ).thenAnswer((_) async => [model]);
        // Attribution to another origin must not weaken global freeze matching.
        when(() => frozen.getAllFrozen()).thenAnswer(
          (_) async => [
            (walletId: 'other-origin', txId: 'tx', vout: 7),
            (walletId: walletId, txId: 'not-owned', vout: 1),
          ],
        );
        final references = <String>[];
        when(() => labels.fetchByReference(any())).thenAnswer((
          invocation,
        ) async {
          final reference = invocation.positionalArguments.single as String;
          references.add(reference);
          return [
            Label(
              id: 1,
              type: LabelType.output,
              label: reference,
              reference: reference,
            ),
          ];
        });
        final repository = LabeledWalletUtxoRepositoryImpl(
          labelsFacade: labels,
          wallet: WalletUtxoRepositoryImpl(
            walletMetadataDatasource: metadata,
            bdkWalletDatasource: bdk,
            lwkWalletDatasource: lwk,
            frozenWalletUtxoDatasource: frozen,
            coordinator: InMemoryWalletSourceOperationCoordinator(),
          ),
        );
        final coins = await repository.getWalletUtxos(walletId: walletId);
        expect(coins, hasLength(1));
        final coin = coins.single;
        expect(coin.walletId, walletId);
        expect(coin.outpoint, (txId: 'tx', vout: 7));
        expect(coin.amountSat, BigInt.from(1234));
        expect(coin.confirmations, 3);
        expect(coin.isFrozen, isTrue);
        expect(coin.labels.single.reference, 'tx:7');
        expect(coin.txLabels.single.reference, 'tx');
        expect(
          coin.addressLabels.map((label) => label.reference),
          isLiquid ? ['standard', 'confidential'] : ['standard'],
        );
        expect(
          references,
          isLiquid
              ? ['tx:7', 'tx', 'standard', 'confidential']
              : ['tx:7', 'tx', 'standard'],
        );
        expect(coin.address, isLiquid ? 'confidential' : 'standard');
        expect(
          coin.addressKeyChain,
          isLiquid
              ? WalletAddressKeyChain.external
              : WalletAddressKeyChain.internal,
        );
      },
    );
  }
}
