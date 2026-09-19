import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

class _Inspect extends Mock implements InspectDataBackupUsecase {}

class _Recover extends Mock implements RecoverDataBackupUsecase {}

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
  late _Inspect inspect;
  late _Recover recover;
  late DataBackupRecoveryCubit cubit;
  setUp(() {
    inspect = _Inspect();
    recover = _Recover();
    when(() => inspect.execute()).thenAnswer((_) async => Ok(inspection));
    cubit = DataBackupRecoveryCubit(inspect, recover);
  });
  tearDown(() => cubit.close());
  test(
    'inspection is read-only and recovery reuses its result with explicit confirmation',
    () async {
      await cubit.inspect();
      expect(
        (cubit.state as DataBackupRecoveryPreview).inspection,
        same(inspection),
      );
      verifyZeroInteractions(recover);
      final restored = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {'source-wallet': 'target'},
          failedReferences: [],
        ),
        publicRecordsRestored: true,
        metadataRestored: true,
      );
      when(
        () => recover.execute(
          inspection,
          confirmed: true,
          enableAfterRecovery: false,
        ),
      ).thenAnswer((_) async => Ok(restored));
      await cubit.recover();
      final state = cubit.state as DataBackupRecoveryPreview;
      expect(state.result, same(restored));
      expect(state.result!.complete, isTrue);
      expect(state.failure, isNull);
      verify(() => inspect.execute()).called(1);
    },
  );
  test(
    'partial application retains the report and shows incomplete rather than success',
    () async {
      await cubit.inspect();
      final partial = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {},
          failedReferences: ['source-wallet'],
        ),
        publicRecordsRestored: true,
        metadataRestored: false,
        failure: const WalletBackupIncompleteFailure(),
      );
      when(
        () => recover.execute(
          inspection,
          confirmed: true,
          enableAfterRecovery: false,
        ),
      ).thenAnswer((_) async => Ok(partial));
      await cubit.recover();
      final state = cubit.state as DataBackupRecoveryPreview;
      expect(state.result!.complete, isFalse);
      expect(state.failure, isA<BackupSettingsRecoveryIncompleteFailure>());
      expect(state.result!.wallets.failedReferences, ['source-wallet']);
    },
  );
  test(
    'missing server data can be inspected but cannot trigger apply',
    () async {
      final absent = WalletBackupInspection(
        identity: 'a' * 64,
        head: WalletBackupRemoteHead(generation: 0, etag: null),
        snapshot: null,
      );
      when(() => inspect.execute()).thenAnswer((_) async => Ok(absent));
      await cubit.inspect();
      await cubit.recover();
      verifyZeroInteractions(recover);
    },
  );
  test(
    'repeated taps share the pending inspection and reset discards its late result',
    () async {
      final pending =
          Completer<Result<WalletBackupInspection, BackupSettingsFailure>>();
      when(() => inspect.execute()).thenAnswer((_) => pending.future);
      final running = cubit.inspect();
      await cubit.inspect();
      verify(() => inspect.execute()).called(1);
      cubit.reset();
      pending.complete(Ok(inspection));
      await running;
      expect(cubit.state, isA<DataBackupRecoveryInitial>());
    },
  );
  test(
    'retry never presents an old completed result while another application is pending',
    () async {
      await cubit.inspect();
      final restored = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {'source-wallet': 'target'},
          failedReferences: [],
        ),
        publicRecordsRestored: true,
        metadataRestored: true,
      );
      when(
        () => recover.execute(
          inspection,
          confirmed: true,
          enableAfterRecovery: false,
        ),
      ).thenAnswer((_) async => Ok(restored));
      await cubit.recover();
      final pending =
          Completer<Result<WalletBackupRecovery, BackupSettingsFailure>>();
      when(
        () => recover.execute(
          inspection,
          confirmed: true,
          enableAfterRecovery: false,
        ),
      ).thenAnswer((_) => pending.future);
      final running = cubit.recover();
      expect((cubit.state as DataBackupRecoveryPreview).busy, isTrue);
      expect((cubit.state as DataBackupRecoveryPreview).result, isNull);
      pending.complete(const Err(BackupSettingsNetworkFailure()));
      await running;
      expect((cubit.state as DataBackupRecoveryPreview).result, isNull);
      expect(
        (cubit.state as DataBackupRecoveryPreview).failure,
        isA<BackupSettingsNetworkFailure>(),
      );
    },
  );
}
