import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_remote_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/canonical_backup_snapshot.dart';
import '../support/fake_bullvault_backup.dart';

void main() {
  // The head's ciphertext is irrelevant here: the import step is faked.
  final head = WalletBackupRemoteHead.absent(generation: 0, etag: null);

  test('describes the backup the server holds without applying it', () async {
    final usecase = GetRemoteWalletBackupContentsUsecase(
      fetchRemote: () async => Ok(head),
      fetchImport: (_) async => Ok(canonicalFullSnapshot()),
      inspectVault: fakeVaultInspector,
    );

    final contents = (await usecase.execute() as Ok).value!;

    expect(contents.vaults.map((vault) => vault.walletRef), [
      'vault-generation-0',
      'vault-generation-1',
    ]);
    expect(contents.vaults.first.descriptor, 'tr(fake)');
    expect(contents.wallets, isNotEmpty);
    expect(
      contents.wallets.every((wallet) => !wallet.keysOnDevice),
      isTrue,
      reason: 'a remote read knows nothing about local keys',
    );
  });

  test('reports an empty server as null, not as a failure', () async {
    final usecase = GetRemoteWalletBackupContentsUsecase(
      fetchRemote: () async => Ok(head),
      fetchImport: (_) async => const Ok(null),
      inspectVault: fakeVaultInspector,
    );

    expect((await usecase.execute() as Ok).value, isNull);
  });

  test('passes server and decode failures through', () async {
    final usecase = GetRemoteWalletBackupContentsUsecase(
      fetchRemote: () async =>
          const Err(WalletBackupRemoteUnavailableFailure()),
      fetchImport: (_) async => throw StateError('not reached'),
      inspectVault: fakeVaultInspector,
    );

    expect(
      await usecase.execute(),
      isA<Err<Object?, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRemoteUnavailableFailure>(),
      ),
    );
  });
}
