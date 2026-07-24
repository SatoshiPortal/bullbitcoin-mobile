import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockLwkWalletDatasource lwkWalletDatasource;
  late _MockCbfWalletDatasource cbfWalletDatasource;
  late _MockElectrumServersPort serversPort;
  late _MockCbfSyncActivityPort cbfSyncActivityPort;
  late WalletRepository repository;

  final seed = Seed.bytes(bytes: Uint8List(32), masterFingerprint: 'aabbccdd');

  setUpAll(() {
    final fallbackMetadata = WalletMetadataModel(
      id: '[aabbccdd/84h/0h/0h]',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '12345678',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      xpub: 'xpub-fake',
      externalPublicDescriptor: 'wpkh([aabbccdd/84h/0h/0h]xpub-fake/0/*)',
      internalPublicDescriptor: 'wpkh([aabbccdd/84h/0h/0h]xpub-fake/1/*)',
      signer: Signer.local,
      isDefault: false,
    );
    registerFallbackValue(fallbackMetadata);
    registerFallbackValue(WalletModel.fromMetadata(fallbackMetadata));
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
    when(() => walletMetadataDatasource.store(any())).thenAnswer((_) async {});
  });

  test('defaults to electrum when bitcoinSyncBackend is omitted', () async {
    await repository.createWallet(
      seed: seed,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    );

    final captured = verify(
      () => walletMetadataDatasource.store(captureAny()),
    ).captured;
    final stored = captured.single as WalletMetadataModel;
    expect(stored.bitcoinSyncBackend, BitcoinSyncBackend.electrum);
  });

  test(
    'persists the requested compactBlockFilters backend before storing',
    () async {
      await repository.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        bitcoinSyncBackend: BitcoinSyncBackend.compactBlockFilters,
      );

      final captured = verify(
        () => walletMetadataDatasource.store(captureAny()),
      ).captured;
      final stored = captured.single as WalletMetadataModel;
      expect(stored.bitcoinSyncBackend, BitcoinSyncBackend.compactBlockFilters);
    },
  );
}
