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

class _MockMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkDatasource extends Mock implements LwkWalletDatasource {}

class _MockServersPort extends Mock implements ElectrumServersPort {}

void main() {
  const walletId = 'wpkh([73c5da0a/84h/1h/0h])';
  final previous = WalletMetadataModel(
    id: walletId,
    masterFingerprint: '73c5da0a',
    xpubFingerprint: '11223344',
    isEncryptedVaultTested: true,
    isPhysicalBackupTested: true,
    latestEncryptedBackup: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
    latestPhysicalBackup: DateTime.utc(2025, 12, 1).millisecondsSinceEpoch,
    xpub: 'public-test-xpub',
    externalPublicDescriptor: 'public-test-external-descriptor',
    internalPublicDescriptor: 'public-test-internal-descriptor',
    signer: Signer.local,
    isDefault: true,
    lastReceiveAddressIndex: 7,
    label: 'Test wallet',
    syncedAt: DateTime.utc(2026, 1, 2),
    birthday: DateTime.utc(2025, 1, 1),
  );
  late _MockMetadataDatasource metadataDatasource;
  late WalletRepository repository;

  setUpAll(() => registerFallbackValue(previous));

  setUp(() {
    metadataDatasource = _MockMetadataDatasource();
    final bdkDatasource = _MockBdkDatasource();
    final lwkDatasource = _MockLwkDatasource();
    when(
      () => bdkDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(
      () => lwkDatasource.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(
      () => metadataDatasource.fetch(walletId),
    ).thenAnswer((_) async => previous);
    when(() => metadataDatasource.store(any())).thenAnswer((_) async {});
    repository = WalletRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdkDatasource,
      lwkWalletDatasource: lwkDatasource,
      serversPort: _MockServersPort(),
    );
  });

  test(
    'records a new untested backup while preserving other metadata',
    () async {
      final createdAt = DateTime.utc(2026, 2, 3);

      await repository.recordEncryptedBackupCreation(
        walletId: walletId,
        time: createdAt,
      );

      final saved =
          verify(() => metadataDatasource.store(captureAny())).captured.single
              as WalletMetadataModel;
      expect(saved.latestEncryptedBackup, createdAt.millisecondsSinceEpoch);
      expect(saved.isEncryptedVaultTested, isFalse);
      expect(saved.isPhysicalBackupTested, isTrue);
      expect(saved.latestPhysicalBackup, previous.latestPhysicalBackup);
      expect(
        saved.copyWith(
          latestEncryptedBackup: previous.latestEncryptedBackup,
          isEncryptedVaultTested: previous.isEncryptedVaultTested,
        ),
        previous,
      );
    },
  );

  test(
    'verification still marks a previously untested backup as tested',
    () async {
      final untested = previous.copyWith(isEncryptedVaultTested: false);
      when(
        () => metadataDatasource.fetch(walletId),
      ).thenAnswer((_) async => untested);
      final verifiedAt = DateTime.utc(2026, 2, 4);

      await repository.updateEncryptedBackupTime(
        walletId: walletId,
        time: verifiedAt,
      );

      final saved =
          verify(() => metadataDatasource.store(captureAny())).captured.single
              as WalletMetadataModel;
      expect(saved.isEncryptedVaultTested, isTrue);
      expect(saved.latestEncryptedBackup, verifiedAt.millisecondsSinceEpoch);
      expect(saved.isPhysicalBackupTested, untested.isPhysicalBackupTested);
      expect(saved.latestPhysicalBackup, untested.latestPhysicalBackup);
    },
  );

  test('does not create metadata for a missing wallet', () async {
    when(
      () => metadataDatasource.fetch(walletId),
    ).thenAnswer((_) async => null);

    await expectLater(
      repository.recordEncryptedBackupCreation(
        walletId: walletId,
        time: DateTime.utc(2026, 2, 3),
      ),
      throwsA(const WalletError.notFound(walletId)),
    );

    verifyNever(() => metadataDatasource.store(any()));
  });
}
