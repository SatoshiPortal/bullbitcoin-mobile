import 'dart:async';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_utxo_repository_impl.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart'
    show InMemoryWalletSourceOperationCoordinator, WalletSourceKey;

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockFrozenWalletUtxoDatasource extends Mock
    implements FrozenWalletUtxoDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _otherWalletId = 'wpkh([deadbeef/84h/1h/0h])';

WalletMetadataModel _metadata(String id) => WalletMetadataModel(
  id: id,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: Signer.local,
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
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final frozen = _MockFrozenWalletUtxoDatasource();
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

    final repository = WalletUtxoRepositoryImpl(
      walletMetadataDatasource: metadata,
      labelsFacade: labels,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: _MockLwkWalletDatasource(),
      frozenWalletUtxoDatasource: frozen,
      coordinator: coordinator,
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
}
