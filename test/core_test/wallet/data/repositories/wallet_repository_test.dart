import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

void main() {
  const walletId = 'wallet-1';

  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late WalletRepository repository;

  setUpAll(() {
    registerFallbackValue(_metadata());
  });

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    final bdkWalletDatasource = _MockBdkWalletDatasource();
    final lwkWalletDatasource = _MockLwkWalletDatasource();
    when(
      () => bdkWalletDatasource.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => bdkWalletDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWalletDatasource.walletSyncStartedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwkWalletDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    repository = WalletRepository(
      walletMetadataDatasource: walletMetadataDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
      lwkWalletDatasource: lwkWalletDatasource,
      serversPort: _MockElectrumServersPort(),
    );
    when(() => walletMetadataDatasource.store(any())).thenAnswer((_) async {});
  });

  Future<WalletMetadataModel> storedAfterDefaults({
    required WalletMetadataModel existing,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    when(
      () => walletMetadataDatasource.fetch(walletId),
    ).thenAnswer((_) async => existing);

    await repository.applyWalletBehaviorDefaultsIfMissing(
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );

    final captured = verify(
      () => walletMetadataDatasource.store(captureAny()),
    ).captured;
    return captured.single as WalletMetadataModel;
  }

  group('applyWalletBehaviorDefaultsIfMissing', () {
    test('applies defaults when both flags are unset', () async {
      final stored = await storedAfterDefaults(
        existing: _metadata(),
        hideOnHome: true,
        autoSweepEnabled: true,
      );

      expect(stored.hideOnHome, isTrue);
      expect(stored.autoSweepEnabled, isTrue);
    });

    test('never overwrites explicit false flags with true defaults', () async {
      final stored = await storedAfterDefaults(
        existing: _metadata(hideOnHome: false, autoSweepEnabled: false),
        hideOnHome: true,
        autoSweepEnabled: true,
      );

      expect(stored.hideOnHome, isFalse);
      expect(stored.autoSweepEnabled, isFalse);
    });

    test('never overwrites explicit true flags with false defaults', () async {
      final stored = await storedAfterDefaults(
        existing: _metadata(hideOnHome: true, autoSweepEnabled: true),
        hideOnHome: false,
        autoSweepEnabled: false,
      );

      expect(stored.hideOnHome, isTrue);
      expect(stored.autoSweepEnabled, isTrue);
    });

    test('fills only the flag the user has not chosen yet', () async {
      final stored = await storedAfterDefaults(
        existing: _metadata(hideOnHome: false),
        hideOnHome: true,
        autoSweepEnabled: true,
      );

      expect(stored.hideOnHome, isFalse);
      expect(stored.autoSweepEnabled, isTrue);
    });

    test('throws when the wallet does not exist', () async {
      when(
        () => walletMetadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => null);

      await expectLater(
        repository.applyWalletBehaviorDefaultsIfMissing(
          walletId: walletId,
          hideOnHome: true,
          autoSweepEnabled: true,
        ),
        throwsA(isA<WalletError>()),
      );
      verifyNever(() => walletMetadataDatasource.store(any()));
    });
  });
}

WalletMetadataModel _metadata({bool? hideOnHome, bool? autoSweepEnabled}) {
  return WalletMetadataModel(
    id: 'wallet-1',
    masterFingerprint: 'fingerprint',
    xpubFingerprint: 'xpub-fingerprint',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-desc',
    internalPublicDescriptor: 'internal-desc',
    signer: Signer.local,
    isDefault: false,
    hideOnHome: hideOnHome,
    autoSweepEnabled: autoSweepEnabled,
  );
}
