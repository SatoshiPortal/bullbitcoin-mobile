import 'dart:async';

import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/address_view/data/labeled_wallet_address_repository_impl.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show InMemoryWalletSourceOperationCoordinator, WalletSourceKey;

class _MockWalletCatalogPort extends Mock implements WalletCatalogPort {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

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
    final labels = _MockLabelsFacade();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    var addressReads = 0;
    final release = Completer<void>();

    when(
      () => metadata.fetch(_walletId),
    ).thenAnswer((_) async => _metadata(_walletId));
    when(
      () => metadata.fetch(_otherWalletId),
    ).thenAnswer((_) async => _metadata(_otherWalletId));
    when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
    when(
      () => bdk.getAddressByIndex(
        any(),
        wallet: any(named: 'wallet'),
        isChange: any(named: 'isChange'),
      ),
    ).thenAnswer((_) async {
      addressReads++;
      return 'tb1q-address';
    });

    final repository = LabeledWalletAddressRepositoryImpl(
      labels: labels,
      wallet: WalletAddressRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: _MockLwkWalletDatasource(),
        coordinator: coordinator,
      ),
    );
    final held = coordinator.runExclusive(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => release.future,
    );

    final waiting = repository.getAddressAtIndex(
      walletId: _walletId,
      index: 0,
      isChange: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(addressReads, 0);

    await repository.getAddressAtIndex(
      walletId: _otherWalletId,
      index: 0,
      isChange: false,
    );
    expect(addressReads, 1);

    release.complete();
    await waiting;
    await held;
  });
}
