import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapWalletBackupFailure', () {
    // Spec 21.2. Each row is a condition the user has to be able to tell
    // apart; two rows must never land on the same state.
    final taxonomy = <String, (List<WalletBackupFailure>, Type)>{
      'temporarily unavailable': (
        [
          const WalletBackupRemoteUnavailableFailure(),
          const WalletBackupRateLimitedFailure(Duration(seconds: 30)),
        ],
        BackupSettingsUnavailableFailure,
      ),
      'newer version blocked': (
        [const WalletBackupUnsupportedEnvelopeVersionFailure(99)],
        BackupSettingsUpdateRequiredFailure,
      ),
      'wrong seed': (
        [const WalletBackupParentFingerprintMismatchFailure()],
        BackupSettingsSeedMismatchFailure,
      ),
      'malformed document': (
        [
          const WalletBackupInvalidEnvelopeFailure(),
          const WalletBackupEncryptionFailure(),
          const WalletBackupManifestFailure(),
          const WalletBackupDefinitionsFailure(),
        ],
        BackupSettingsInvalidFileFailure,
      ),
      'authentication failed': (
        [
          const WalletBackupSigningFailure(),
          const WalletBackupInvalidRemoteFailure(),
          const WalletBackupRemoteRejectedFailure(),
        ],
        BackupSettingsUnverifiedFailure,
      ),
      'head conflict': (
        [const WalletBackupHeadConflictFailure()],
        BackupSettingsHeadConflictFailure,
      ),
      'too large': (
        [const WalletBackupTooLargeFailure()],
        BackupSettingsFileTooLargeFailure,
      ),
      'local storage failure': (
        [const WalletBackupStorageFailure()],
        BackupSettingsStorageFailure,
      ),
      'recovery needs attention': (
        [const WalletBackupRecoveryBlockedFailure()],
        BackupSettingsRecoveryNeedsAttentionFailure,
      ),
      'disabled': (
        [const WalletBackupDisabledFailure()],
        BackupSettingsDisabledFailure,
      ),
      'invalid server': (
        [const WalletBackupInvalidServerOriginFailure()],
        BackupSettingsInvalidServerFailure,
      ),
      'unexpected': (
        [
          const WalletBackupKeyDerivationFailure(),
          const WalletBackupWalletUnavailableFailure(),
          const WalletBackupConfirmationRequiredFailure(),
          const WalletBackupDeleteRequiresDisabledFailure(),
          const WalletBackupUnexpectedFailure(),
        ],
        BackupSettingsUnexpectedFailure,
      ),
    };

    taxonomy.forEach((condition, entry) {
      final (failures, expected) = entry;
      test('$condition reaches the user as $expected', () {
        for (final failure in failures) {
          expect(
            mapWalletBackupFailure(failure).runtimeType,
            expected,
            reason: '${failure.runtimeType} must read as $condition',
          );
        }
      });
    });

    test('every condition produces a state no other condition produces', () {
      final states = <Type, String>{};
      taxonomy.forEach((condition, entry) {
        final state = mapWalletBackupFailure(entry.$1.first).runtimeType;
        expect(
          states,
          isNot(contains(state)),
          reason: '$condition collapses into ${states[state]}',
        );
        states[state] = condition;
      });
      expect(states, hasLength(taxonomy.length));
    });

    test('availability is never reported as invalid data', () {
      expect(
        mapWalletBackupFailure(
          const WalletBackupRateLimitedFailure(Duration(minutes: 1)),
        ),
        isNot(isA<BackupSettingsInvalidFileFailure>()),
      );
    });

    test('a readable backup from another seed is not called invalid', () {
      expect(
        mapWalletBackupFailure(
          const WalletBackupParentFingerprintMismatchFailure(),
        ),
        isNot(isA<BackupSettingsInvalidFileFailure>()),
      );
    });

    test('the unexpected state keeps the developer detail', () {
      final failure = mapWalletBackupFailure(
        const WalletBackupUnexpectedFailure(),
      );
      expect(
        (failure as BackupSettingsUnexpectedFailure).logMessage,
        'WalletBackupUnexpectedFailure',
      );
    });
  });

  group('mapWalletBackupRecoveryStatus', () {
    test('a finished recovery has nothing to report', () {
      for (final status in const [
        WalletBackupRecoveryStatus.restored,
        WalletBackupRecoveryStatus.noBackup,
      ]) {
        expect(mapWalletBackupRecoveryStatus(status), isNull);
      }
    });

    test('a partial recovery is not reported as success', () {
      expect(
        mapWalletBackupRecoveryStatus(
          WalletBackupRecoveryStatus.partiallyRestored,
        ),
        isA<BackupSettingsRecoveryNeedsAttentionFailure>(),
      );
    });

    test('each unfinished status keeps its own meaning', () {
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.unavailable),
        isA<BackupSettingsUnavailableFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.timedOut),
        isA<BackupSettingsUnavailableFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.newerVersion),
        isA<BackupSettingsUpdateRequiredFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.conflict),
        isA<BackupSettingsHeadConflictFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.invalid),
        isA<BackupSettingsInvalidFileFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(WalletBackupRecoveryStatus.localFailure),
        isA<BackupSettingsStorageFailure>(),
      );
      expect(
        mapWalletBackupRecoveryStatus(
          WalletBackupRecoveryStatus.comparisonStale,
        ),
        isA<BackupSettingsRecoveryNeedsAttentionFailure>(),
      );
    });
  });
}
