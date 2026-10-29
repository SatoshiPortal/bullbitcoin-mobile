import 'package:primitives/primitives.dart' show BitcoinSyncSource, Ok;
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'dart:async';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show
        InMemoryWalletSourceOperationCoordinator,
        WalletSourceKey,
        WalletTransactionSyncFacade,
        WalletNetworkKey;

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _SyncFacade extends Mock implements WalletTransactionSyncFacade {}

class _Settings extends Mock implements SettingsRepository {}

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
      const WalletNetworkKey('public', 'bitcoin', 'testnet'),
    );
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

    final repository = WalletAddressRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: _MockLwkWalletDatasource(),
      labelsFacade: labels,
      coordinator: coordinator,
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
  for (final generateNew in [false, true]) {
    test(
      'CBF receive $generateNew checks script coverage after releasing its source',
      () async {
        final metadata = _MockWalletMetadataDatasource(),
            bdk = _MockBdkWalletDatasource(),
            labels = _MockLabelsFacade(),
            facade = _SyncFacade();
        final coordinator = InMemoryWalletSourceOperationCoordinator();
        when(() => metadata.fetch(_walletId)).thenAnswer(
          (_) async => _metadata(
            _walletId,
          ).copyWith(bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters),
        );
        when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
        when(
          () => bdk.getNewAddress(wallet: any(named: 'wallet')),
        ).thenAnswer((_) async => (index: 1000, address: 'tb1q-public'));
        when(
          () => bdk.getLastRevealedAddressOrNew(wallet: any(named: 'wallet')),
        ).thenAnswer((_) async => (index: 1000, address: 'tb1q-public'));
        var checked = false;
        when(() => facade.ensureCbfScriptCoverage(any())).thenAnswer((
          invocation,
        ) async {
          final key = invocation.positionalArguments.single as WalletNetworkKey;
          expect(key.walletId, _walletId);
          await coordinator.runExclusive(
            WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
            (_) async {
              checked = true;
            },
          );
          return const Ok(null);
        });
        final repository = WalletAddressRepository(
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: bdk,
          lwkWalletDatasource: _MockLwkWalletDatasource(),
          labelsFacade: labels,
          coordinator: coordinator,
          bitcoinSyncRouting: BitcoinSyncRouting(
            facade: facade,
            settings: _Settings(),
            tor: () => throw StateError('unused'),
          ),
        );
        final address =
            await (generateNew
                    ? repository.generateNewReceiveAddress(walletId: _walletId)
                    : repository.getLastRevealedReceiveAddress(
                        walletId: _walletId,
                      ))
                .timeout(const Duration(seconds: 1));
        expect(address.index, 1000);
        expect(checked, isTrue);
        verify(() => facade.ensureCbfScriptCoverage(any())).called(1);
      },
    );
  }
}
