import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final inspection = WalletBackupInspection(
    identity: credential.serverPublicKey,
    head: WalletBackupRemoteHead(
      generation: 1,
      etag: 'a' * 64,
      ciphertext: WalletBackupCiphertext(List.filled(64, 1)),
    ),
    snapshot: backupSnapshotFixture(credential),
  );
  late _Backups backups;
  late InspectDataBackupUsecase inspect;
  late RecoverDataBackupUsecase recover;
  setUp(() {
    backups = _Backups();
    inspect = InspectDataBackupUsecase(backups);
    recover = RecoverDataBackupUsecase(backups);
  });
  test(
    'current-wallet inspection returns the same fetched view without applying',
    () async {
      when(() => backups.inspect()).thenAnswer((_) async => Ok(inspection));
      expect(
        (await inspect.execute()
                as Ok<WalletBackupInspection, BackupSettingsFailure>)
            .value,
        same(inspection),
      );
      verify(() => backups.inspect()).called(1);
      verifyNoMoreInteractions(backups);
    },
  );
  test('cancelled recovery does not call any backup operation', () async {
    expect(
      await recover.execute(inspection, confirmed: false),
      isA<Err<WalletBackupRecovery, BackupSettingsFailure>>(),
    );
    verifyZeroInteractions(backups);
  });
  test(
    'manual recovery passes the already fetched inspection without changing enablement',
    () async {
      final result = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {'portable': 'actual'},
          failedReferences: [],
        ),
        publicRecordsRestored: true,
        metadataRestored: true,
      );
      when(
        () => backups.recover(inspection, enableAfterRecovery: false),
      ).thenAnswer((_) async => Ok(result));
      final recovered = await recover.execute(inspection, confirmed: true);
      expect(
        (recovered as Ok<WalletBackupRecovery, BackupSettingsFailure>).value,
        same(result),
      );
      verify(
        () => backups.recover(inspection, enableAfterRecovery: false),
      ).called(1);
      verifyNoMoreInteractions(backups);
    },
  );
  test(
    'partial recovery retains its actual target IDs and remains incomplete',
    () async {
      final partial = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {'portable': 'actual'},
          failedReferences: ['failed'],
        ),
        publicRecordsRestored: true,
        metadataRestored: false,
        failure: const WalletBackupIncompleteFailure(),
      );
      when(
        () => backups.recover(inspection, enableAfterRecovery: false),
      ).thenAnswer((_) async => Ok(partial));
      final result =
          (await recover.execute(inspection, confirmed: true)
                  as Ok<WalletBackupRecovery, BackupSettingsFailure>)
              .value;
      expect(result.complete, isFalse);
      expect(result.wallets.walletReferences, {'portable': 'actual'});
      expect(result.wallets.failedReferences, ['failed']);
    },
  );
  test(
    'agreed enablement is passed only with explicit current-wallet recovery',
    () async {
      when(
        () => backups.recover(inspection, enableAfterRecovery: true),
      ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
      final result = await recover.execute(
        inspection,
        confirmed: true,
        enableAfterRecovery: true,
      );
      expect(result, isA<Err<WalletBackupRecovery, BackupSettingsFailure>>());
      verify(
        () => backups.recover(inspection, enableAfterRecovery: true),
      ).called(1);
    },
  );
}
