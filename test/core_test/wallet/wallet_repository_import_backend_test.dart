import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockCbfWalletDatasource extends Mock implements CbfWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _MockCbfSyncActivityPort extends Mock implements CbfSyncActivityPort {}

final _zeroBalance = BalanceModel(
  immatureSat: BigInt.zero,
  trustedPendingSat: BigInt.zero,
  untrustedPendingSat: BigInt.zero,
  confirmedSat: BigInt.zero,
  spendableSat: BigInt.zero,
  totalSat: BigInt.zero,
);

// A real, publicly-known-format xpub (no secret material) used only to
// exercise pure-Dart descriptor field derivation — never persisted or
// logged.
const _fixtureFingerprint = 'efbd6844';
const _fixtureXpub =
    'xpub6Bx9HW5yLRBRQLdMFEJ2auFxz2oWyzmFAaD2YvPX61Qnf39b8GB7HpkKGhxx1'
    'mqkLioykGdZdHKRjygX8K63Qqv1MCM4Ej1qXnGsf4do3sp';

WalletMetadataModel _buildMetadata() {
  return WalletMetadataModel(
    id: '[abcdef12/84h/0h/0h]',
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    bitcoinSyncBackend: BitcoinSyncBackend.electrum,
  );
}

WatchOnlyDescriptorEntity _buildDescriptorEntity({
  required satoshifier.Network network,
}) {
  final descriptor = satoshifier.Descriptor(
    operand: satoshifier.ScriptOperand.wpkh,
    fingerprint: _fixtureFingerprint,
    pubkey: _fixtureXpub,
    network: network,
    derivation: satoshifier.Derivation.bip84,
    account: 0,
  );
  return WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: satoshifier.WatchOnlyDescriptor(
          descriptor: descriptor,
        ),
      )
      as WatchOnlyDescriptorEntity;
}

void main() {
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockLwkWalletDatasource lwkWalletDatasource;
  late _MockCbfWalletDatasource cbfWalletDatasource;
  late _MockElectrumServersPort serversPort;
  late _MockCbfSyncActivityPort cbfSyncActivityPort;
  late WalletRepository repository;

  setUpAll(() {
    registerFallbackValue(_buildMetadata());
    registerFallbackValue(WalletModel.fromMetadata(_buildMetadata()));
  });

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    lwkWalletDatasource = _MockLwkWalletDatasource();
    cbfWalletDatasource = _MockCbfWalletDatasource();
    serversPort = _MockElectrumServersPort();
    cbfSyncActivityPort = _MockCbfSyncActivityPort();

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
      cbfWalletDatasource: cbfWalletDatasource,
      serversPort: serversPort,
      cbfSyncActivityPort: cbfSyncActivityPort,
    );

    when(
      () => bdkWalletDatasource.getBalance(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => _zeroBalance);
    when(
      () => lwkWalletDatasource.getBalance(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => _zeroBalance);
    when(() => walletMetadataDatasource.store(any())).thenAnswer((_) async {});
    when(() => walletMetadataDatasource.fetchAll()).thenAnswer((_) async => []);
  });

  group('WalletRepository.importDescriptor — backend persistence', () {
    test('a requested compactBlockFilters backend is persisted for a '
        'Bitcoin descriptor', () async {
      final entity = _buildDescriptorEntity(
        network: satoshifier.Network.bitcoinMainnet,
      );

      await repository.importDescriptor(
        watchOnlyDescriptor: entity,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.bitcoinSyncBackend, BitcoinSyncBackend.compactBlockFilters);
    });

    test('a requested compactBlockFilters backend is never persisted for a '
        'Liquid descriptor — Liquid always stays electrum', () async {
      final entity = _buildDescriptorEntity(
        network: satoshifier.Network.liquidMainnet,
      );

      await repository.importDescriptor(
        watchOnlyDescriptor: entity,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.bitcoinSyncBackend, BitcoinSyncBackend.electrum);
    });

    test('defaults to electrum when the backend param is omitted', () async {
      final entity = _buildDescriptorEntity(
        network: satoshifier.Network.bitcoinMainnet,
      );

      await repository.importDescriptor(watchOnlyDescriptor: entity);

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.bitcoinSyncBackend, BitcoinSyncBackend.electrum);
    });
  });

  group('WalletRepository.importDescriptor — birthday checkpoint atomicity', () {
    final fakeCheckpoint = WalletBirthdayCheckpoint(
      requestedBirthday: DateTime.utc(2026),
      blockTimestamp: DateTime.utc(2026),
      blockHeight: 900000,
      blockHash: 'a' * 64,
    );

    test(
      'a resolved birthday checkpoint is persisted atomically with the '
      'same store() call for a Bitcoin descriptor',
      () async {
        final entity = _buildDescriptorEntity(
          network: satoshifier.Network.bitcoinMainnet,
        );

        await repository.importDescriptor(
          watchOnlyDescriptor: entity,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthdayCheckpoint: fakeCheckpoint,
        );

        final captured = verify(
          () => walletMetadataDatasource.store(captureAny()),
        ).captured;
        final stored = captured.single as WalletMetadataModel;
        expect(stored.birthdayCheckpoint, fakeCheckpoint);
      },
    );

    test(
      'a birthday checkpoint is never persisted for a Liquid descriptor — '
      'Liquid has no CBF equivalent',
      () async {
        final entity = _buildDescriptorEntity(
          network: satoshifier.Network.liquidMainnet,
        );

        await repository.importDescriptor(
          watchOnlyDescriptor: entity,
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthdayCheckpoint: fakeCheckpoint,
        );

        final captured = verify(
          () => walletMetadataDatasource.store(captureAny()),
        ).captured;
        final stored = captured.single as WalletMetadataModel;
        expect(stored.birthdayCheckpoint, isNull);
      },
    );

    test('omitting the checkpoint leaves it unset', () async {
      final entity = _buildDescriptorEntity(
        network: satoshifier.Network.bitcoinMainnet,
      );

      await repository.importDescriptor(
        watchOnlyDescriptor: entity,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.birthdayCheckpoint, isNull);
    });
  });

  group('WalletRepository.importWatchOnlyXpub — birthday checkpoint '
      'atomicity', () {
    final fakeCheckpoint = WalletBirthdayCheckpoint(
      requestedBirthday: DateTime.utc(2026),
      blockTimestamp: DateTime.utc(2026),
      blockHeight: 900000,
      blockHash: 'a' * 64,
    );

    test(
      'a resolved birthday checkpoint is persisted atomically with the '
      'same store() call',
      () async {
        await repository.importWatchOnlyXpub(
          xpub: _fixtureXpub,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          label: 'My xpub wallet',
          bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthdayCheckpoint: fakeCheckpoint,
        );

        final captured = verify(
          () => walletMetadataDatasource.store(captureAny()),
        ).captured;
        final stored = captured.single as WalletMetadataModel;
        expect(stored.birthdayCheckpoint, fakeCheckpoint);
      },
    );

    test('omitting the checkpoint leaves it unset', () async {
      await repository.importWatchOnlyXpub(
        xpub: _fixtureXpub,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        label: 'My xpub wallet',
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.birthdayCheckpoint, isNull);
    });
  });
}
