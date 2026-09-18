import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Fake implements ElectrumServersPort {}

class _Metadata extends Fake implements WalletMetadataDatasource {
  WalletMetadataModel value;
  _Metadata(this.value);

  @override
  Future<WalletMetadataModel?> fetch(String walletId) async => value;
  @override
  Future<void> store(WalletMetadataModel metadata) async {
    value = metadata;
  }
}

void main() {
  for (final previouslyTested in [false, true]) {
    test(
      'creation ${previouslyTested ? 'preserves the successful test date' : 'records availability without claiming a test'}',
      () async {
        final old = DateTime.utc(2025, 9, 1);
        final created = DateTime.utc(2026, 9, 18);
        final metadata = _Metadata(
          WalletMetadataModel(
            id: 'default',
            network: Network.bitcoinMainnet,
            signers: [],
            isEncryptedVaultTested: previouslyTested,
            isPhysicalBackupTested: false,
            latestEncryptedBackup: previouslyTested
                ? old.millisecondsSinceEpoch
                : null,
            publicDescriptor: 'wpkh(xpub/<0;1>/*)',
            isDefault: true,
          ),
        );
        final bdk = _Bdk();
        final lwk = _Lwk();
        when(
          () => bdk.walletSyncFinishedStream,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => lwk.walletSyncFinishedStream,
        ).thenAnswer((_) => const Stream.empty());
        final repository = WalletRepository(
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: bdk,
          lwkWalletDatasource: lwk,
          serversPort: _Servers(),
        );
        await repository.recordEncryptedBackupCreated(
          time: created,
          walletId: 'default',
        );
        expect(metadata.value.isEncryptedVaultTested, previouslyTested);
        expect(
          metadata.value.latestEncryptedBackup,
          (previouslyTested ? old : created).millisecondsSinceEpoch,
        );
      },
    );
  }
}
